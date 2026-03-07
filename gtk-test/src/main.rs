use std::cell::RefCell;
use std::rc::Rc;
use std::time::{Duration, Instant};

use gtk4::gdk;
use gtk4::glib;
use gtk4::prelude::*;
use gtk4::{
    Align, Application, ApplicationWindow, Box as GtkBox, Button, CssProvider, DrawingArea,
    DropDown, Entry, EventControllerKey, EventControllerMotion, EventControllerScroll,
    GestureClick, Label, Orientation, Overlay, Popover, Separator,
};

use volvoxgrid_engine::clipboard;
use volvoxgrid_engine::demo;
use volvoxgrid_engine::drag;
use volvoxgrid_engine::grid::VolvoxGrid;
use volvoxgrid_engine::input;

#[cfg(feature = "gpu")]
use volvoxgrid_engine::gpu_render::GpuRenderer;
use volvoxgrid_engine::outline;
use volvoxgrid_engine::print;
use volvoxgrid_engine::proto::volvoxgrid::v1 as pb;
use volvoxgrid_engine::render::Renderer;
use volvoxgrid_engine::save;
use volvoxgrid_engine::search;
use volvoxgrid_engine::sort;
use volvoxgrid_engine::style::CellStyleOverride;

const APP_ID: &str = "io.github.ivere27.volvoxgrid.GtkTest";
const GTK_TEST_SCROLL_DELTA_SCALE: f32 = 1.0;
const INLINE_EDITOR_CSS_CLASS: &str = "volvox-inline-editor";
const INLINE_EDITOR_CSS: &str = r#"
entry.volvox-inline-editor,
entry.volvox-inline-editor text {
  background-color: #ffffff;
  color: #000000;
  caret-color: #000000;
  min-height: 0;
  min-width: 0;
  margin: 0;
  box-shadow: none;
}

entry.volvox-inline-editor {
  border: 1px solid #2d6cdf;
  border-radius: 0;
  box-shadow: none;
  padding: 0;
  margin: 0;
  min-height: 0;
  min-width: 0;
}

entry.volvox-inline-editor text {
  padding: 0 4px;
  border-radius: 0;
}
"#;

fn main() {
    let app = Application::builder().application_id(APP_ID).build();
    app.connect_activate(build_ui);
    app.run();
}

/// Demo mode: 0=stress, 1=sales, 2=hierarchy
const DEMO_STRESS: i32 = 0;
const DEMO_SALES: i32 = 1;
const DEMO_HIERARCHY: i32 = 2;
const SELECTION_MODE_LABELS: [&str; 5] = ["Free", "ByRow", "ByCol", "Listbox", "MultiRange"];

fn selection_mode_index(mode: i32) -> u32 {
    match mode {
        x if x == pb::SelectionMode::SelectionByRow as i32 => 1,
        x if x == pb::SelectionMode::SelectionByColumn as i32 => 2,
        x if x == pb::SelectionMode::SelectionListbox as i32 => 3,
        x if x == pb::SelectionMode::SelectionMultiRange as i32 => 4,
        _ => 0,
    }
}

fn selection_mode_value(index: u32) -> i32 {
    match index {
        1 => pb::SelectionMode::SelectionByRow as i32,
        2 => pb::SelectionMode::SelectionByColumn as i32,
        3 => pb::SelectionMode::SelectionListbox as i32,
        4 => pb::SelectionMode::SelectionMultiRange as i32,
        _ => pb::SelectionMode::SelectionFree as i32,
    }
}

/// Shared state wrapped for GTK closures.
struct State {
    grid: VolvoxGrid,
    renderer: Renderer,
    #[cfg(feature = "gpu")]
    gpu_renderer: Option<GpuRenderer>,
    frame_surface: Option<cairo::ImageSurface>,
    draw_queued: bool,
    mouse_pressed: bool,
    multirange_drag_active: bool,
    multirange_base_ranges: Vec<(i32, i32, i32, i32)>,
    multirange_anchor_row: i32,
    multirange_anchor_col: i32,
    multirange_drag_row: i32,
    multirange_drag_col: i32,
    saved_data: Option<Vec<u8>>,
    clipboard_text: String,
    event_count: u64,
    last_event: String,
    selection_mode_idx: u32,
    span_on: bool,
    outline_on: bool,
    frozen: bool,
    col_hidden: bool,
    last_click_at: Option<Instant>,
    last_click_row: i32,
    last_click_col: i32,
    overlay_edit_row: i32,
    overlay_edit_col: i32,
    suppress_entry_changed: bool,
    demo_mode: i32,
    debug_overlay: bool,
}

/// Ensure layout is valid, rebuilding if necessary.
fn ensure_layout(grid: &mut VolvoxGrid) {
    grid.ensure_layout();
}

fn clear_multirange_drag(state: &mut State) {
    state.multirange_drag_active = false;
    state.multirange_base_ranges.clear();
    state.multirange_anchor_row = -1;
    state.multirange_anchor_col = -1;
    state.multirange_drag_row = -1;
    state.multirange_drag_col = -1;
}

fn set_system_clipboard_text(text: &str) {
    if let Some(display) = gdk::Display::default() {
        display.clipboard().set_text(text);
    }
}

fn queue_draw_if_needed(state: &mut State, area: &DrawingArea) {
    if !state.draw_queued {
        state.draw_queued = true;
        area.queue_draw();
    }
}

fn ensure_visible_rows_materialized(grid: &mut VolvoxGrid, _demo_mode: i32) {
    // Rebuild layout if invalidated (e.g. after sort or column resize).
    // Stress demo is now eager (load_demo("stress") semantics), so no per-frame
    // row materialization is required here.
    grid.ensure_layout();
}

fn install_inline_editor_css() {
    let provider = CssProvider::new();
    provider.load_from_data(INLINE_EDITOR_CSS);
    if let Some(display) = gdk::Display::default() {
        gtk4::style_context_add_provider_for_display(
            &display,
            &provider,
            gtk4::STYLE_PROVIDER_PRIORITY_APPLICATION,
        );
    }
}

/// Create a grid for the given demo mode.
fn create_demo_grid(mode: i32, width: i32, height: i32) -> VolvoxGrid {
    let mut grid = match mode {
        DEMO_SALES => {
            let mut grid = VolvoxGrid::new(1, width, height, 2, 10, 1, 1);
            demo::setup_sales_demo(&mut grid);
            grid
        }
        DEMO_HIERARCHY => {
            let mut grid = VolvoxGrid::new(1, width, height, 2, 5, 1, 0);
            demo::setup_hierarchy_demo(&mut grid);
            grid
        }
        _ => create_grid(width, height),
    };
    grid.fling_enabled = false;
    grid
}

fn is_multirange_selectable_hit(hit: &input::HitTestResult) -> bool {
    hit.row >= 0
        && hit.col >= 0
        && matches!(
            hit.area,
            input::HitArea::Cell | input::HitArea::DropdownButton | input::HitArea::CheckBox
        )
}

fn snapshot_multirange_base_ranges(
    grid: &VolvoxGrid,
    anchor_row: i32,
    anchor_col: i32,
) -> Vec<(i32, i32, i32, i32)> {
    grid.selection
        .all_ranges(grid.rows, grid.cols)
        .into_iter()
        .filter(|&(row1, col1, row2, col2)| {
            !(row1 == anchor_row && col1 == anchor_col && row2 == anchor_row && col2 == anchor_col)
        })
        .collect()
}

fn apply_multirange_drag_selection(
    grid: &mut VolvoxGrid,
    base_ranges: &[(i32, i32, i32, i32)],
    anchor_row: i32,
    anchor_col: i32,
    target_row: i32,
    target_col: i32,
) {
    let next_range = (
        anchor_row.min(target_row),
        anchor_col.min(target_col),
        anchor_row.max(target_row),
        anchor_col.max(target_col),
    );
    let mut ranges = base_ranges.to_vec();
    if !ranges.contains(&next_range) {
        ranges.push(next_range);
    }
    grid.selection
        .select_ranges(target_row, target_col, &ranges, grid.rows, grid.cols);
    grid.mark_dirty();
}

/// Move cursor to (row, col) and scroll to show it — avoids borrow conflicts.
fn move_cursor_and_show(grid: &mut VolvoxGrid, row: i32, col: i32) {
    let rows = grid.rows;
    let cols = grid.cols;
    let fr = grid.fixed_rows;
    let fc = grid.fixed_cols;
    grid.selection.set_cursor(row, col, rows, cols, fr, fc);
    grid.selection.row_end = row;
    grid.selection.col_end = col;
    let vw = grid.viewport_width;
    let vh = grid.viewport_height;
    let ph = grid.pinned_top_height() + grid.pinned_bottom_height();
    let pw = grid.pinned_left_width() + grid.pinned_right_width();
    grid.scroll
        .show_cell(row, col, &grid.layout, vw, vh, fr, fc, ph, pw);
    grid.mark_dirty();
}

fn active_dropdown_hit_index(grid: &VolvoxGrid, px: f32, py: f32) -> Option<i32> {
    grid.dropdown_hit_index(px, py)
}

fn cell_screen_rect(grid: &VolvoxGrid, row: i32, col: i32) -> Option<(i32, i32, i32, i32)> {
    grid.cell_screen_rect(row, col)
}

fn sync_native_entry_overlay(state: &mut State, entry: &Entry, area: &DrawingArea) {
    let grid = &mut state.grid;
    if grid.edit.is_active() {
        let row = grid.edit.edit_row;
        let col = grid.edit.edit_col;
        let list = grid.active_dropdown_list(row, col);
        // Combo cells use the dropdown path; text cells use native Entry.
        if list.is_empty() || list.trim() == "..." {
            if let Some((x, y, w, h)) = cell_screen_rect(grid, row, col) {
                // Clip to the visible viewport and inset 1px so the editor
                // sits inside cell borders like an in-place editor.
                let vx0 = 0;
                let vy0 = 0;
                let vx1 = grid.viewport_width.max(0);
                let vy1 = grid.viewport_height.max(0);
                let cx0 = x.max(vx0);
                let cy0 = y.max(vy0);
                let cx1 = (x + w).min(vx1);
                let cy1 = (y + h).min(vy1);
                let cw = cx1 - cx0;
                let ch = cy1 - cy0;
                if cw <= 2 || ch <= 2 {
                    if gtk4::prelude::WidgetExt::is_visible(entry) {
                        entry.set_visible(false);
                    }
                    return;
                }
                let inset = 0;
                let ex = cx0 + inset;
                let ey = cy0 + inset;
                let ew = (cw - inset * 2).max(1);
                let eh = (ch - inset * 2).max(1);

                entry.set_margin_start(ex.max(0));
                entry.set_margin_top(ey.max(0));
                entry.set_width_request(ew);
                entry.set_height_request(eh);
                entry.set_size_request(ew, eh);

                let changed_cell = !gtk4::prelude::WidgetExt::is_visible(entry)
                    || state.overlay_edit_row != row
                    || state.overlay_edit_col != col;
                if changed_cell {
                    state.suppress_entry_changed = true;
                    entry.set_text(&grid.edit.edit_text);
                    entry.select_region(0, -1);
                    state.suppress_entry_changed = false;
                    entry.grab_focus();
                }
                entry.set_visible(true);
                state.overlay_edit_row = row;
                state.overlay_edit_col = col;
                return;
            }
        }
    }

    if gtk4::prelude::WidgetExt::is_visible(entry) {
        entry.set_visible(false);
    }
    state.overlay_edit_row = -1;
    state.overlay_edit_col = -1;
    if !state.grid.edit.is_active() {
        area.grab_focus();
    }
}

fn truncate_to_char_count(input: &str, max_chars: i32) -> String {
    if max_chars <= 0 {
        return input.to_string();
    }
    input.chars().take(max_chars as usize).collect()
}

fn human_bytes(bytes: i64) -> String {
    if bytes < 0 {
        return format!("{} B", bytes);
    }
    let units = ["B", "KiB", "MiB", "GiB", "TiB"];
    let mut value = bytes as f64;
    let mut unit_idx = 0usize;
    while value >= 1024.0 && unit_idx + 1 < units.len() {
        value /= 1024.0;
        unit_idx += 1;
    }
    if unit_idx == 0 {
        format!("{bytes} {}", units[unit_idx])
    } else {
        format!("{value:.1} {}", units[unit_idx])
    }
}

fn commit_active_edit(grid: &mut VolvoxGrid) {
    grid.commit_edit();
}

fn cancel_active_edit(grid: &mut VolvoxGrid) {
    grid.cancel_edit();
}

fn edit_char_count(text: &str) -> i32 {
    text.chars().count() as i32
}

fn edit_byte_index_at_char(text: &str, char_idx: i32) -> usize {
    let target = char_idx.max(0) as usize;
    if target == 0 {
        return 0;
    }
    match text.char_indices().nth(target) {
        Some((idx, _)) => idx,
        None => text.len(),
    }
}

fn collapse_edit_caret(grid: &mut VolvoxGrid, caret_pos: i32) {
    let total = edit_char_count(&grid.edit.edit_text);
    grid.edit.sel_start = caret_pos.clamp(0, total);
    grid.edit.sel_length = 0;
}

fn replace_edit_selection(grid: &mut VolvoxGrid, inserted: &str) {
    let current = grid.edit.edit_text.clone();
    let total = edit_char_count(&current);
    let start = grid.edit.sel_start.clamp(0, total);
    let end = (grid.edit.sel_start + grid.edit.sel_length).clamp(0, total);
    let (from, to) = if end >= start {
        (start, end)
    } else {
        (end, start)
    };
    let b0 = edit_byte_index_at_char(&current, from);
    let b1 = edit_byte_index_at_char(&current, to);

    let mut next = String::new();
    next.push_str(&current[..b0]);
    next.push_str(inserted);
    next.push_str(&current[b1..]);
    next = truncate_to_char_count(&next, grid.edit_max_length);

    let caret = (from + inserted.chars().count() as i32).clamp(0, edit_char_count(&next));
    grid.edit.edit_text = next;
    grid.edit.sel_start = caret;
    grid.edit.sel_length = 0;
}

fn emit_change_edit(grid: &mut VolvoxGrid) {
    grid.events
        .push(volvoxgrid_engine::event::GridEventData::CellEditChange {
            text: grid.edit.edit_text.clone(),
        });
    grid.mark_dirty();
}

fn maybe_handle_edit_key(grid: &mut VolvoxGrid, keyval: gdk::Key, vk: i32, modifier: i32) -> bool {
    if !grid.edit.is_active() {
        return false;
    }

    let ctrl = modifier & 2 != 0;
    let shift = modifier & 1 != 0;

    match vk {
        27 => {
            // Escape: cancel active edit.
            cancel_active_edit(grid);
            return true;
        }
        13 => {
            // Enter: commit active edit.
            commit_active_edit(grid);
            return true;
        }
        9 => {
            // Tab: commit edit and continue normal navigation.
            commit_active_edit(grid);
            input::handle_key_down(grid, vk, modifier);
            return true;
        }
        36 => {
            // Home
            if shift {
                let caret = (grid.edit.sel_start + grid.edit.sel_length)
                    .clamp(0, edit_char_count(&grid.edit.edit_text));
                grid.edit.sel_start = 0;
                grid.edit.sel_length = (caret - grid.edit.sel_start).max(0);
            } else {
                collapse_edit_caret(grid, 0);
            }
            grid.mark_dirty();
            return true;
        }
        35 => {
            // End
            let end = edit_char_count(&grid.edit.edit_text);
            if shift {
                grid.edit.sel_length = (end - grid.edit.sel_start).max(0);
            } else {
                collapse_edit_caret(grid, end);
            }
            grid.mark_dirty();
            return true;
        }
        37 => {
            // Left
            if shift {
                let base = (grid.edit.sel_start + grid.edit.sel_length)
                    .clamp(0, edit_char_count(&grid.edit.edit_text));
                let next = (base - 1).max(0);
                grid.edit.sel_start = next;
                grid.edit.sel_length = (base - next).max(0);
            } else if grid.edit.sel_length > 0 {
                collapse_edit_caret(grid, grid.edit.sel_start);
            } else {
                collapse_edit_caret(grid, grid.edit.sel_start - 1);
            }
            grid.mark_dirty();
            return true;
        }
        39 => {
            // Right
            let text_len = edit_char_count(&grid.edit.edit_text);
            if shift {
                let base = (grid.edit.sel_start + grid.edit.sel_length).clamp(0, text_len);
                let next = (base + 1).min(text_len);
                grid.edit.sel_start = base;
                grid.edit.sel_length = (next - base).max(0);
            } else if grid.edit.sel_length > 0 {
                collapse_edit_caret(grid, grid.edit.sel_start + grid.edit.sel_length);
            } else {
                collapse_edit_caret(grid, (grid.edit.sel_start + 1).min(text_len));
            }
            grid.mark_dirty();
            return true;
        }
        8 if !ctrl => {
            // Backspace
            if grid.edit.sel_length > 0 {
                replace_edit_selection(grid, "");
                emit_change_edit(grid);
            } else {
                let caret = grid.edit.sel_start;
                if caret > 0 {
                    grid.edit.sel_start = caret - 1;
                    grid.edit.sel_length = 1;
                    replace_edit_selection(grid, "");
                    emit_change_edit(grid);
                }
            }
            return true;
        }
        46 if !ctrl => {
            // Delete
            if grid.edit.sel_length > 0 {
                replace_edit_selection(grid, "");
                emit_change_edit(grid);
            } else {
                let total = edit_char_count(&grid.edit.edit_text);
                if grid.edit.sel_start < total {
                    grid.edit.sel_length = 1;
                    replace_edit_selection(grid, "");
                    emit_change_edit(grid);
                }
            }
            return true;
        }
        38 | 40 if grid.edit.dropdown_count() > 0 => {
            // Up/Down: navigate dropdown list while editing.
            let count = grid.edit.dropdown_count();
            if count > 0 {
                let mut idx = grid.edit.dropdown_index;
                if idx < 0 {
                    idx = if vk == 40 { 0 } else { count - 1 };
                } else if vk == 40 {
                    idx = (idx + 1).min(count - 1);
                } else {
                    idx = (idx - 1).max(0);
                }
                grid.edit.set_dropdown_index(idx);
                let end = edit_char_count(&grid.edit.edit_text);
                collapse_edit_caret(grid, end);
                emit_change_edit(grid);
            }
            return true;
        }
        65 if ctrl => {
            // Ctrl+A: select all editor text.
            grid.edit.sel_start = 0;
            grid.edit.sel_length = edit_char_count(&grid.edit.edit_text);
            grid.mark_dirty();
            return true;
        }
        _ => {}
    }

    if !ctrl {
        if let Some(ch) = keyval.to_unicode() {
            if !ch.is_control() {
                replace_edit_selection(grid, &ch.to_string());
                emit_change_edit(grid);
            }
        }
    }

    true
}

/// Drain all pending events from the grid, update status counters.
fn drain_events(state: &mut State) -> String {
    let events = state.grid.events.drain();
    for ev in &events {
        state.event_count += 1;
        state.last_event = format_event_name(&ev.data);
    }
    format!(
        "Cell: R{} C{} | Sel: R{} C{} | Events: {} | Last: {}",
        state.grid.selection.row,
        state.grid.selection.col,
        state.grid.selection.row_end,
        state.grid.selection.col_end,
        state.event_count,
        state.last_event,
    )
}

fn format_event_name(ev: &volvoxgrid_engine::event::GridEventData) -> String {
    use volvoxgrid_engine::event::GridEventData::*;
    match ev {
        CellFocusChanging { .. } => "CellFocusChanging".into(),
        CellFocusChanged {
            new_row, new_col, ..
        } => format!("CellFocusChanged(R{}C{})", new_row, new_col),
        SelectionChanging { .. } => "SelectionChanging".into(),
        SelectionChanged { .. } => "SelectionChanged".into(),
        EnterCell { row, col } => format!("EnterCell(R{}C{})", row, col),
        LeaveCell { row, col } => format!("LeaveCell(R{}C{})", row, col),
        BeforeEdit { row, col } => format!("BeforeEdit(R{}C{})", row, col),
        StartEdit { row, col } => format!("StartEdit(R{}C{})", row, col),
        AfterEdit { row, col, .. } => format!("AfterEdit(R{}C{})", row, col),
        CellEditValidate { .. } => "CellEditValidate".into(),
        CellEditChange { .. } => "CellEditChange".into(),
        CellButtonClick { row, col } => format!("CellBtnClick(R{}C{})", row, col),
        KeyDownEdit { key_code, .. } => format!("KeyDownEdit({})", key_code),
        KeyPressEdit { .. } => "KeyPressEdit".into(),
        KeyUpEdit { .. } => "KeyUpEdit".into(),
        CellEditConfigureStyle { .. } => "CellEditConfigureStyle".into(),
        CellEditConfigureWindow { .. } => "CellEditConfigureWindow".into(),
        DropdownClosed => "DropdownClosed".into(),
        DropdownOpened => "DropdownOpened".into(),
        CellChanged { row, col, .. } => format!("CellChanged(R{}C{})", row, col),
        RowStatusChange { row, status } => format!("RowStatus(R{},{})", row, status),
        BeforeSort { col } => format!("BeforeSort(C{})", col),
        AfterSort { col } => format!("AfterSort(C{})", col),
        Compare { .. } => "Compare".into(),
        BeforeNodeToggle { row, .. } => format!("BeforeNodeToggle(R{})", row),
        AfterNodeToggle { row, .. } => format!("AfterNodeToggle(R{})", row),
        BeforeScroll {
            old_top_row,
            old_left_col,
            new_top_row,
            new_left_col,
        } => format!(
            "BeforeScroll(R{}C{} -> R{}C{})",
            old_top_row, old_left_col, new_top_row, new_left_col
        ),
        AfterScroll {
            old_top_row,
            old_left_col,
            new_top_row,
            new_left_col,
        } => format!(
            "AfterScroll(R{}C{} -> R{}C{})",
            old_top_row, old_left_col, new_top_row, new_left_col
        ),
        ScrollTooltip { .. } => "ScrollTooltip".into(),
        BeforeUserResize { .. } => "BeforeUserResize".into(),
        AfterUserResize { .. } => "AfterUserResize".into(),
        AfterUserFreeze { .. } => "AfterUserFreeze".into(),
        BeforeMoveColumn { .. } => "BeforeMoveColumn".into(),
        AfterMoveColumn { .. } => "AfterMoveColumn".into(),
        BeforeMoveRow { .. } => "BeforeMoveRow".into(),
        AfterMoveRow { .. } => "AfterMoveRow".into(),
        BeforeMouseDown { .. } => "BeforeMouseDown".into(),
        MouseDown { .. } => "MouseDown".into(),
        MouseUp { .. } => "MouseUp".into(),
        MouseMove { .. } => "MouseMove".into(),
        Click => "Click".into(),
        DblClick => "DblClick".into(),
        KeyDown { key_code, .. } => format!("KeyDown({})", key_code),
        KeyPress { .. } => "KeyPress".into(),
        KeyUp { .. } => "KeyUp".into(),
        CustomRenderCell { row, col, .. } => format!("CustomRenderCell(R{}C{})", row, col),
        DragStart { .. } => "DragStart".into(),
        DragOver { .. } => "DragOver".into(),
        DragDrop { .. } => "DragDrop".into(),
        DragComplete { .. } => "DragComplete".into(),
        TypeAheadStarted { .. } => "TypeAheadStarted".into(),
        TypeAheadEnded => "TypeAheadEnded".into(),
        DataRefreshing => "DataRefreshing".into(),
        DataRefreshed => "DataRefreshed".into(),
        FilterData { .. } => "FilterData".into(),
        Error { code, message } => format!("Error({}: {})", code, message),
        BeforePageBreak { .. } => "BeforePageBreak".into(),
        StartPage { .. } => "StartPage".into(),
        GetHeaderRow { .. } => "GetHeaderRow".into(),
        Copy => "Copy".into(),
        Cut => "Cut".into(),
        Paste => "Paste".into(),
    }
}

/// Create and populate the stress demo grid (1M rows, 12 columns).
fn create_grid(width: i32, height: i32) -> VolvoxGrid {
    let mut grid = VolvoxGrid::new(1, width, height, 2, 12, 1, 1);
    demo::setup_stress_demo(&mut grid);
    grid
}

fn build_ui(app: &Application) {
    install_inline_editor_css();

    let width = 1100i32;
    let height = 700i32;

    let mut grid = create_demo_grid(DEMO_SALES, width, height);
    let initial_selection_mode_idx = selection_mode_index(grid.selection.mode);

    // Build layout
    ensure_layout(&mut grid);

    #[cfg(feature = "gpu")]
    let gpu_renderer = match pollster::block_on(GpuRenderer::new(None)) {
        Ok(gr) => {
            eprintln!("GPU renderer initialized successfully");
            Some(gr)
        }
        Err(e) => {
            eprintln!("GPU renderer init failed, falling back to CPU: {}", e);
            None
        }
    };

    let state = Rc::new(RefCell::new(State {
        grid,
        renderer: Renderer::new(),
        #[cfg(feature = "gpu")]
        gpu_renderer,
        frame_surface: None,
        draw_queued: false,
        mouse_pressed: false,
        multirange_drag_active: false,
        multirange_base_ranges: Vec::new(),
        multirange_anchor_row: -1,
        multirange_anchor_col: -1,
        multirange_drag_row: -1,
        multirange_drag_col: -1,
        saved_data: None,
        clipboard_text: String::new(),
        event_count: 0,
        last_event: "(none)".to_string(),
        selection_mode_idx: initial_selection_mode_idx,
        span_on: false,
        outline_on: false,
        frozen: false,
        col_hidden: false,
        last_click_at: None,
        last_click_row: -1,
        last_click_col: -1,
        overlay_edit_row: -1,
        overlay_edit_col: -1,
        suppress_entry_changed: false,
        demo_mode: DEMO_SALES,
        debug_overlay: false,
    }));

    // ── Status Bar ──────────────────────────────────────────────────────
    let status_label = Label::new(Some("Cell: R1 C1 | Sel: R1 C1 | Events: 0 | Last: (none)"));
    status_label.set_xalign(0.0);
    status_label.set_margin_start(8);
    status_label.set_margin_end(8);
    status_label.set_margin_top(4);
    status_label.set_margin_bottom(4);

    // ── Drawing Area ────────────────────────────────────────────────────
    let drawing_area = DrawingArea::new();
    drawing_area.set_hexpand(true);
    drawing_area.set_vexpand(true);
    drawing_area.set_focusable(true);
    drawing_area.set_can_focus(true);

    // Host-side text editor overlay (IME/unicode/caret handled by GTK).
    let grid_overlay = Overlay::new();
    grid_overlay.set_hexpand(true);
    grid_overlay.set_vexpand(true);
    grid_overlay.set_child(Some(&drawing_area));

    let edit_entry = Entry::new();
    edit_entry.set_visible(false);
    edit_entry.set_halign(Align::Start);
    edit_entry.set_valign(Align::Start);
    edit_entry.set_has_frame(false);
    edit_entry.add_css_class(INLINE_EDITOR_CSS_CLASS);
    gtk4::prelude::EntryExt::set_alignment(&edit_entry, 0.0);
    edit_entry.set_width_chars(1);
    edit_entry.set_can_focus(true);
    grid_overlay.add_overlay(&edit_entry);

    // Context menu popover (right-click)
    let context_popover = Popover::new();
    context_popover.set_parent(&drawing_area);
    context_popover.set_autohide(true);
    context_popover.set_has_arrow(false);

    // Draw callback
    {
        let state = Rc::clone(&state);
        drawing_area.set_draw_func(move |_area, cr, w, h| {
            let mut st = state.borrow_mut();
            st.draw_queued = false;
            let w = w as i32;
            let h = h as i32;
            if w <= 0 || h <= 0 {
                return;
            }
            // Keep engine viewport in lockstep with the draw surface size.
            // Input hit-testing uses grid.viewport_* while rendering uses draw
            // callback dimensions; mismatch here causes scrollbar thumb drift
            // between visible and interactive positions.
            if st.grid.viewport_width != w || st.grid.viewport_height != h {
                st.grid.resize_viewport(w, h);
            }

            let dm = st.demo_mode;
            ensure_visible_rows_materialized(&mut st.grid, dm);

            let recreate_surface = st
                .frame_surface
                .as_ref()
                .map_or(true, |s| s.width() != w || s.height() != h);
            if recreate_surface {
                st.frame_surface = cairo::ImageSurface::create(cairo::Format::ARgb32, w, h).ok();
            }
            if st.frame_surface.is_none() {
                return;
            }

            // In rare cases cairo keeps another reference to the same surface.
            // Recreate once to recover an exclusive mutable data borrow.
            let mut have_data = false;
            {
                let State {
                    grid,
                    renderer,
                    #[cfg(feature = "gpu")]
                    gpu_renderer,
                    frame_surface,
                    ..
                } = &mut *st;

                // Decide whether to use GPU path.
                #[cfg(feature = "gpu")]
                let use_gpu = gpu_renderer.is_some() && grid.renderer_mode >= 2;
                #[cfg(not(feature = "gpu"))]
                let use_gpu = false;

                for _ in 0..2 {
                    if let Some(surface) = frame_surface.as_mut() {
                        let stride = surface.stride();
                        let data_result = surface.data();
                        if let Ok(mut data) = data_result {
                            let frame_start = Instant::now();

                            #[cfg(feature = "gpu")]
                            if use_gpu {
                                if let Some(gr) = gpu_renderer.as_mut() {
                                    grid.debug_renderer_actual = 2; // GPU=2
                                    gr.render_to_buffer(grid, &mut data, w, h, stride);
                                    // GPU renders Bgra8Unorm which matches Cairo ARgb32 — no swap needed.
                                }
                            }

                            if !use_gpu {
                                grid.debug_renderer_actual = 1; // CPU=1
                                renderer.render(grid, &mut data, w, h, stride);
                                // Engine renders RGBA; cairo ARgb32 expects BGRA byte order on LE.
                                rgba_to_bgra(&mut data);
                            }

                            let elapsed = frame_start.elapsed().as_secs_f32() * 1000.0;
                            grid.debug_frame_time_ms = elapsed;
                            grid.debug_fps =
                                grid.debug_fps * 0.9 + (1000.0 / elapsed.max(0.1)) * 0.1;
                            grid.clear_dirty();
                            have_data = true;
                        }
                    }
                    if have_data {
                        break;
                    }
                    *frame_surface = cairo::ImageSurface::create(cairo::Format::ARgb32, w, h).ok();
                }
            }

            if !have_data {
                return;
            }

            let Some(surface) = st.frame_surface.as_ref() else {
                return;
            };
            if cr.set_source_surface(surface, 0.0, 0.0).is_err() {
                return;
            }
            if cr.paint().is_err() {
                return;
            }
        });
    }

    // Periodically sync the native editor geometry/visibility with grid edit state.
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let entry = edit_entry.clone();
        let mut last_tick = Instant::now();
        glib::timeout_add_local(Duration::from_millis(16), move || {
            let now = Instant::now();
            let dt = now.duration_since(last_tick).as_secs_f32();
            last_tick = now;

            let mut st = state.borrow_mut();
            let fling_enabled = st.grid.fling_enabled;
            let fling_friction = st.grid.fling_friction;
            if fling_enabled && st.grid.scroll.tick_fling(dt, fling_friction) {
                st.grid.mark_dirty();
            }
            if input::tick_scrollbar_repeat(&mut st.grid, dt) {
                // repeat scrolled — dirty flag already set
            }
            sync_native_entry_overlay(&mut st, &entry, &area);
            if st.grid.dirty {
                queue_draw_if_needed(&mut st, &area);
            }
            glib::ControlFlow::Continue
        });
    }

    // Native editor change -> grid edit text update.
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        edit_entry.connect_changed(move |entry| {
            let Ok(mut st) = state.try_borrow_mut() else {
                // Re-entrant signal while state is mutably borrowed by timer sync.
                // Ignore this tick; sync will run again on the next frame.
                return;
            };
            if st.suppress_entry_changed || !st.grid.edit.is_active() {
                return;
            }
            if st.grid.edit.edit_row != st.overlay_edit_row
                || st.grid.edit.edit_col != st.overlay_edit_col
            {
                return;
            }

            let mut text = entry.text().to_string();
            text = truncate_to_char_count(&text, st.grid.edit_max_length);
            if text != entry.text() {
                st.suppress_entry_changed = true;
                entry.set_text(&text);
                st.suppress_entry_changed = false;
            }

            st.grid.edit.edit_text = text.clone();
            if let Some((a, b)) = entry.selection_bounds() {
                let start = a.min(b).max(0);
                st.grid.edit.sel_start = start;
                st.grid.edit.sel_length = (a - b).abs();
            } else {
                st.grid.edit.sel_start = entry.position().max(0);
                st.grid.edit.sel_length = 0;
            }

            st.grid
                .events
                .push(volvoxgrid_engine::event::GridEventData::CellEditChange { text });
            st.grid.mark_dirty();
            let s = drain_events(&mut st);
            status.set_text(&s);
            drop(st);
            area.queue_draw();
        });
    }

    // Enter in native editor commits edit.
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        let entry_ref = edit_entry.clone();
        edit_entry.connect_activate(move |entry| {
            let mut st = state.borrow_mut();
            if st.grid.edit.is_active() {
                st.grid.edit.edit_text =
                    truncate_to_char_count(&entry.text(), st.grid.edit_max_length);
                st.grid.edit.sel_start = entry.position().max(0);
                st.grid.edit.sel_length = 0;
                commit_active_edit(&mut st.grid);
            }
            sync_native_entry_overlay(&mut st, &entry_ref, &area);
            let s = drain_events(&mut st);
            status.set_text(&s);
            drop(st);
            area.queue_draw();
        });
    }

    // Escape/Tab in native editor.
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        let entry_ref = edit_entry.clone();
        let editor_key = EventControllerKey::new();
        editor_key.connect_key_pressed(move |_ctrl, keyval, _keycode, modifier| {
            let vk = gdk_keyval_to_vk(keyval);
            let mods = gdk_modifier_to_flags(modifier);
            if vk != 27 && vk != 9 {
                return glib::Propagation::Proceed;
            }

            let mut st = state.borrow_mut();
            if !st.grid.edit.is_active() {
                return glib::Propagation::Proceed;
            }

            if vk == 27 {
                cancel_active_edit(&mut st.grid);
            } else {
                st.grid.edit.edit_text =
                    truncate_to_char_count(&entry_ref.text(), st.grid.edit_max_length);
                st.grid.edit.sel_start = entry_ref.position().max(0);
                st.grid.edit.sel_length = 0;
                commit_active_edit(&mut st.grid);
                input::handle_key_down(&mut st.grid, 9, mods);
            }

            sync_native_entry_overlay(&mut st, &entry_ref, &area);
            let s = drain_events(&mut st);
            status.set_text(&s);
            drop(st);
            area.queue_draw();
            glib::Propagation::Stop
        });
        edit_entry.add_controller(editor_key);
    }

    // ── Mouse Click ─────────────────────────────────────────────────────
    let gesture_click = GestureClick::new();
    gesture_click.set_button(0);
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        let entry_ref = edit_entry.clone();
        let popover = context_popover.clone();
        gesture_click.connect_pressed(move |gesture, n_press, x, y| {
            let mut st = state.borrow_mut();
            area.grab_focus();
            st.mouse_pressed = true;
            let button = gesture.current_button() as i32;
            let modifier = gdk_modifier_to_flags(gesture.current_event_state());
            let hit = input::hit_test(&st.grid, x as f32, y as f32);

            // ── Right-click context menu ────────────────────────────────
            if button == 3 {
                st.mouse_pressed = false;
                let row = hit.row;
                let col = hit.col;
                let fixed_rows = st.grid.fixed_rows;
                let frozen_rows = st.grid.frozen_rows;
                let fixed_cols = st.grid.fixed_cols;
                let frozen_cols = st.grid.frozen_cols;
                let is_data_row = row >= fixed_rows + frozen_rows;
                let is_data_col = col >= fixed_cols + frozen_cols;
                let pin_state = if is_data_row {
                    st.grid.is_row_pinned(row)
                } else {
                    0
                };
                let row_sticky = if is_data_row {
                    st.grid.sticky_rows.get(&row).copied().unwrap_or(0)
                } else {
                    0
                };
                let col_sticky = if is_data_col {
                    st.grid.sticky_cols.get(&col).copied().unwrap_or(0)
                } else {
                    0
                };
                drop(st);

                // Build popover content
                let menu_box = GtkBox::new(Orientation::Vertical, 2);
                menu_box.set_margin_start(4);
                menu_box.set_margin_end(4);
                menu_box.set_margin_top(4);
                menu_box.set_margin_bottom(4);

                // Helper macro to add a menu button
                macro_rules! menu_item {
                    ($label:expr, $state_rc:expr, $area_ref:expr, $pop:expr, $action:expr) => {{
                        let btn = Button::with_label($label);
                        btn.set_has_frame(false);
                        btn.set_halign(Align::Start);
                        let st_clone = Rc::clone(&$state_rc);
                        let area_clone = $area_ref.clone();
                        let pop_clone = $pop.clone();
                        btn.connect_clicked(move |_| {
                            let mut st = st_clone.borrow_mut();
                            $action(&mut st);
                            st.grid.mark_dirty();
                            drop(st);
                            pop_clone.popdown();
                            area_clone.queue_draw();
                        });
                        menu_box.append(&btn);
                    }};
                }

                // Row pin/sticky items (data rows only)
                if is_data_row {
                    menu_item!(
                        &format!("Pin Row {} to Top", row),
                        state,
                        area,
                        popover,
                        |st: &mut State| {
                            st.grid.pin_row(row, 1);
                        }
                    );
                    menu_item!(
                        &format!("Pin Row {} to Bottom", row),
                        state,
                        area,
                        popover,
                        |st: &mut State| {
                            st.grid.pin_row(row, 2);
                        }
                    );
                    if pin_state != 0 {
                        menu_item!(
                            &format!("Unpin Row {}", row),
                            state,
                            area,
                            popover,
                            |st: &mut State| {
                                st.grid.pin_row(row, 0);
                            }
                        );
                    }

                    menu_box.append(&Separator::new(Orientation::Horizontal));

                    menu_item!(
                        &format!("Sticky Row {} to Top", row),
                        state,
                        area,
                        popover,
                        |st: &mut State| {
                            st.grid.set_row_sticky(row, 1);
                        }
                    );
                    menu_item!(
                        &format!("Sticky Row {} to Bottom", row),
                        state,
                        area,
                        popover,
                        |st: &mut State| {
                            st.grid.set_row_sticky(row, 2);
                        }
                    );
                    menu_item!(
                        &format!("Sticky Row {} Both", row),
                        state,
                        area,
                        popover,
                        |st: &mut State| {
                            st.grid.set_row_sticky(row, 5);
                        }
                    );
                    if row_sticky != 0 {
                        menu_item!(
                            &format!("Unsticky Row {}", row),
                            state,
                            area,
                            popover,
                            |st: &mut State| {
                                st.grid.set_row_sticky(row, 0);
                            }
                        );
                    }
                }

                // Col sticky items (data cols only)
                if is_data_col {
                    menu_box.append(&Separator::new(Orientation::Horizontal));

                    menu_item!(
                        &format!("Sticky Col {} to Left", col),
                        state,
                        area,
                        popover,
                        |st: &mut State| {
                            st.grid.set_col_sticky(col, 3);
                        }
                    );
                    menu_item!(
                        &format!("Sticky Col {} to Right", col),
                        state,
                        area,
                        popover,
                        |st: &mut State| {
                            st.grid.set_col_sticky(col, 4);
                        }
                    );
                    menu_item!(
                        &format!("Sticky Col {} Both", col),
                        state,
                        area,
                        popover,
                        |st: &mut State| {
                            st.grid.set_col_sticky(col, 5);
                        }
                    );
                    if col_sticky != 0 {
                        menu_item!(
                            &format!("Unsticky Col {}", col),
                            state,
                            area,
                            popover,
                            |st: &mut State| {
                                st.grid.set_col_sticky(col, 0);
                            }
                        );
                    }
                }

                // Always: Copy
                menu_box.append(&Separator::new(Orientation::Horizontal));
                menu_item!("Copy", state, area, popover, |st: &mut State| {
                    let (text, _) = clipboard::copy(&st.grid);
                    set_system_clipboard_text(&text);
                    st.clipboard_text = text;
                });

                // Position and show the popover
                popover.set_child(Some(&menu_box));
                popover.set_pointing_to(Some(&gdk::Rectangle::new(x as i32, y as i32, 1, 1)));
                popover.popup();
                return;
            }

            // GTK n_press can be unreliable depending on platform/input backend.
            // Keep a host-side double-click detector as fallback.
            let now = Instant::now();
            let dbl_by_time = st
                .last_click_at
                .map(|t| {
                    now.duration_since(t) <= Duration::from_millis(450)
                        && hit.row == st.last_click_row
                        && hit.col == st.last_click_col
                })
                .unwrap_or(false);
            let dbl = n_press >= 2 || (button == 1 && dbl_by_time);
            if button == 1 && hit.row >= 0 && hit.col >= 0 {
                st.last_click_at = Some(now);
                st.last_click_row = hit.row;
                st.last_click_col = hit.col;
            }

            // Combo dropdown selection by mouse click.
            if modifier == 0 {
                if let Some(idx) = active_dropdown_hit_index(&st.grid, x as f32, y as f32) {
                    st.grid.edit.set_dropdown_index(idx);
                    let text = st.grid.edit.edit_text.clone();
                    st.grid
                        .events
                        .push(volvoxgrid_engine::event::GridEventData::CellEditChange { text });
                    commit_active_edit(&mut st.grid);
                    // Reset mouse_pressed so motion events between now and
                    // the GTK released signal don't extend the selection.
                    st.mouse_pressed = false;
                    // Clear double-click tracker so the next normal click
                    // doesn't falsely trigger double-click.
                    st.last_click_at = None;
                    let s = drain_events(&mut st);
                    status.set_text(&s);
                    drop(st);
                    area.queue_draw();
                    return;
                }
            }

            // Click-away behavior: clicking another cell exits edit mode
            // (commit unless validation cancels).
            if st.grid.edit.is_active() {
                let er = st.grid.edit.edit_row;
                let ec = st.grid.edit.edit_col;
                let clicked_other_cell =
                    hit.row < 0 || hit.col < 0 || hit.row != er || hit.col != ec;
                if clicked_other_cell {
                    // Sync text/selection from native Entry when it is the active editor.
                    if gtk4::prelude::WidgetExt::is_visible(&entry_ref)
                        && st.overlay_edit_row == er
                        && st.overlay_edit_col == ec
                    {
                        st.grid.edit.edit_text =
                            truncate_to_char_count(&entry_ref.text(), st.grid.edit_max_length);
                        if let Some((a, b)) = entry_ref.selection_bounds() {
                            let start = a.min(b).max(0);
                            st.grid.edit.sel_start = start;
                            st.grid.edit.sel_length = (a - b).abs();
                        } else {
                            st.grid.edit.sel_start = entry_ref.position().max(0);
                            st.grid.edit.sel_length = 0;
                        }
                    }
                    commit_active_edit(&mut st.grid);
                    sync_native_entry_overlay(&mut st, &entry_ref, &area);
                }
            }

            if button == 1
                && (modifier & 2) != 0
                && st.grid.selection.mode == pb::SelectionMode::SelectionMultiRange as i32
                && is_multirange_selectable_hit(&hit)
            {
                let base_ranges = snapshot_multirange_base_ranges(&st.grid, hit.row, hit.col);
                st.last_click_at = None;
                st.multirange_drag_active = true;
                st.multirange_base_ranges = base_ranges.clone();
                st.multirange_anchor_row = hit.row;
                st.multirange_anchor_col = hit.col;
                st.multirange_drag_row = hit.row;
                st.multirange_drag_col = hit.col;
                apply_multirange_drag_selection(
                    &mut st.grid,
                    &base_ranges,
                    hit.row,
                    hit.col,
                    hit.row,
                    hit.col,
                );
                let s = drain_events(&mut st);
                status.set_text(&s);
                drop(st);
                area.queue_draw();
                return;
            }

            input::handle_pointer_down(&mut st.grid, x as f32, y as f32, button, modifier, dbl);

            // Double-click edit fallback for hosts that stay in keyboard edit mode.
            if dbl
                && !st.grid.edit.is_active()
                && st.grid.edit_trigger_mode >= 1
                && modifier == 0
                && hit.row >= st.grid.fixed_rows
                && hit.col >= st.grid.fixed_cols
            {
                input::handle_key_down(&mut st.grid, 113, 0); // F2 semantics
            }

            // Single click on a combo cell should open editor/dropdown.
            if !st.grid.edit.is_active()
                && st.grid.edit_trigger_mode >= 1
                && modifier == 0
                && hit.row >= st.grid.fixed_rows
                && hit.col >= st.grid.fixed_cols
                && matches!(
                    hit.area,
                    input::HitArea::Cell | input::HitArea::DropdownButton
                )
            {
                let list = st.grid.active_dropdown_list(hit.row, hit.col);
                if !list.is_empty() && list.trim() != "..." {
                    input::handle_key_down(&mut st.grid, 113, 0); // F2 semantics
                }
            }

            let s = drain_events(&mut st);
            status.set_text(&s);
            drop(st);
            area.queue_draw();
        });
    }
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        gesture_click.connect_released(move |gesture, _n_press, x, y| {
            let mut st = state.borrow_mut();
            st.mouse_pressed = false;
            if st.multirange_drag_active {
                let hit = input::hit_test(&st.grid, x as f32, y as f32);
                let end_row = if is_multirange_selectable_hit(&hit) {
                    hit.row
                } else {
                    st.multirange_drag_row
                };
                let end_col = if is_multirange_selectable_hit(&hit) {
                    hit.col
                } else {
                    st.multirange_drag_col
                };
                let base_ranges = st.multirange_base_ranges.clone();
                let anchor_row = st.multirange_anchor_row;
                let anchor_col = st.multirange_anchor_col;
                apply_multirange_drag_selection(
                    &mut st.grid,
                    &base_ranges,
                    anchor_row,
                    anchor_col,
                    end_row,
                    end_col,
                );
                clear_multirange_drag(&mut st);
                let s = drain_events(&mut st);
                status.set_text(&s);
                drop(st);
                area.queue_draw();
                return;
            }
            let button = gesture.current_button() as i32;
            input::handle_pointer_up(&mut st.grid, x as f32, y as f32, button, 0);
            let s = drain_events(&mut st);
            status.set_text(&s);
            drop(st);
            area.queue_draw();
        });
    }
    drawing_area.add_controller(gesture_click);

    // ── Mouse Motion ────────────────────────────────────────────────────
    let motion_controller = EventControllerMotion::new();
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let last_cursor_style: Rc<std::cell::Cell<i32>> = Rc::new(std::cell::Cell::new(0));
        let lcs = Rc::clone(&last_cursor_style);
        motion_controller.connect_motion(move |_ctrl, x, y| {
            let mut st = state.borrow_mut();
            if st.multirange_drag_active {
                let hit = input::hit_test(&st.grid, x as f32, y as f32);
                if is_multirange_selectable_hit(&hit)
                    && (hit.row != st.multirange_drag_row || hit.col != st.multirange_drag_col)
                {
                    st.multirange_drag_row = hit.row;
                    st.multirange_drag_col = hit.col;
                    let base_ranges = st.multirange_base_ranges.clone();
                    let anchor_row = st.multirange_anchor_row;
                    let anchor_col = st.multirange_anchor_col;
                    apply_multirange_drag_selection(
                        &mut st.grid,
                        &base_ranges,
                        anchor_row,
                        anchor_col,
                        hit.row,
                        hit.col,
                    );
                }
                if lcs.get() != 0 {
                    lcs.set(0);
                    area.set_cursor_from_name(Some("default"));
                }
                if st.grid.dirty {
                    queue_draw_if_needed(&mut st, &area);
                }
                return;
            }
            let button = if st.mouse_pressed { 1 } else { 0 };
            input::handle_pointer_move(&mut st.grid, x as f32, y as f32, button, 0);

            // Sync cursor style from engine
            let cs = st.grid.cursor_style;
            if cs != lcs.get() {
                lcs.set(cs);
                let cursor_name = match cs {
                    1 => "col-resize",
                    2 => "row-resize",
                    3 => "grab",
                    _ => "default",
                };
                area.set_cursor_from_name(Some(cursor_name));
            }

            if st.grid.dirty {
                queue_draw_if_needed(&mut st, &area);
            }
        });
    }
    drawing_area.add_controller(motion_controller);

    // ── Keyboard ────────────────────────────────────────────────────────
    let key_controller = EventControllerKey::new();
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        key_controller.connect_key_pressed(move |_ctrl, keyval, _keycode, modifier| {
            let mut st = state.borrow_mut();
            let key = gdk_keyval_to_vk(keyval);
            let mods = gdk_modifier_to_flags(modifier);

            // In edit mode we handle key input directly so edited text, combo
            // selection, commit/cancel all behave like an in-place editor.
            if maybe_handle_edit_key(&mut st.grid, keyval, key, mods) {
                let s = drain_events(&mut st);
                status.set_text(&s);
                queue_draw_if_needed(&mut st, &area);
                return glib::Propagation::Stop;
            }

            // Typing while not editing starts edit and injects first character.
            // This also handles keys that map to VK codes (a/c/v/...) for ctrl shortcuts.
            if !st.grid.edit.is_active() {
                if let Some(ch) = keyval.to_unicode() {
                    if !ch.is_control() && (mods & 2) == 0 && st.grid.edit_trigger_mode >= 1 {
                        input::handle_key_down(&mut st.grid, 113, mods); // F2 semantics
                        if st.grid.edit.is_active() {
                            let text = ch.to_string();
                            st.grid.edit.edit_text = text.clone();
                            st.grid.edit.sel_start = 1;
                            st.grid.edit.sel_length = 0;
                            st.grid.events.push(
                                volvoxgrid_engine::event::GridEventData::CellEditChange { text },
                            );
                            st.grid.mark_dirty();
                        }
                        let s = drain_events(&mut st);
                        status.set_text(&s);
                        queue_draw_if_needed(&mut st, &area);
                        return glib::Propagation::Stop;
                    }
                }
            }

            if key == 0 {
                return glib::Propagation::Proceed;
            }

            input::handle_key_down(&mut st.grid, key, mods);
            let s = drain_events(&mut st);
            status.set_text(&s);
            queue_draw_if_needed(&mut st, &area);
            glib::Propagation::Stop
        });
    }
    drawing_area.add_controller(key_controller);

    // ── Scroll ──────────────────────────────────────────────────────────
    let scroll_controller = EventControllerScroll::new(gtk4::EventControllerScrollFlags::BOTH_AXES);
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        scroll_controller.connect_scroll(move |_ctrl, dx, dy| {
            let mut st = state.borrow_mut();
            input::handle_scroll(
                &mut st.grid,
                dx as f32 * GTK_TEST_SCROLL_DELTA_SCALE,
                dy as f32 * GTK_TEST_SCROLL_DELTA_SCALE,
            );
            queue_draw_if_needed(&mut st, &area);
            glib::Propagation::Stop
        });
    }
    drawing_area.add_controller(scroll_controller);

    // ── Resize ──────────────────────────────────────────────────────────
    {
        let state = Rc::clone(&state);
        drawing_area.connect_resize(move |_area, w, h| {
            let mut st = state.borrow_mut();
            st.grid.resize_viewport(w, h);
        });
    }

    // ── Toolbar ─────────────────────────────────────────────────────────
    let toolbar_row1 = GtkBox::new(Orientation::Horizontal, 4);
    toolbar_row1.set_margin_start(4);
    toolbar_row1.set_margin_end(4);
    toolbar_row1.set_margin_top(4);

    let toolbar_row2 = GtkBox::new(Orientation::Horizontal, 4);
    toolbar_row2.set_margin_start(4);
    toolbar_row2.set_margin_end(4);
    toolbar_row2.set_margin_bottom(2);

    // Helper: create a toolbar button
    macro_rules! btn {
        ($label:expr) => {{
            let b = Button::with_label($label);
            b.set_focusable(false);
            b
        }};
    }

    // Row 1: Style, Selection mode, Sort, Span, Outline, Edit, Find
    let btn_style = btn!("Style");
    let selection_mode = DropDown::from_strings(&SELECTION_MODE_LABELS);
    selection_mode.set_focusable(false);
    selection_mode.set_selected(state.borrow().selection_mode_idx);
    let btn_sort_asc = btn!("Sort Asc");
    let btn_sort_desc = btn!("Sort Desc");
    let btn_span = btn!("Span");
    let btn_outline = btn!("Outline");
    let btn_edit = btn!("Edit: DblClick");
    let btn_find = btn!("Find");

    toolbar_row1.append(&btn_style);
    toolbar_row1.append(&selection_mode);
    toolbar_row1.append(&btn_sort_asc);
    toolbar_row1.append(&btn_sort_desc);
    toolbar_row1.append(&btn_span);
    toolbar_row1.append(&btn_outline);
    toolbar_row1.append(&btn_edit);
    toolbar_row1.append(&btn_find);

    // Row 2: Save, Load, Copy, Paste, +Row, -Row, HideCol, Freeze, AutoSize, Print, Mem, Flood, Drag
    let btn_save = btn!("Save");
    let btn_load = btn!("Load");
    let btn_copy = btn!("Copy");
    let btn_paste = btn!("Paste");
    let btn_add_row = btn!("+Row");
    let btn_del_row = btn!("-Row");
    let btn_hide_col = btn!("HideCol");
    let btn_freeze = btn!("Freeze");
    let btn_autosize = btn!("AutoSize");
    let btn_print = btn!("Print");
    let btn_mem = btn!("Mem");
    let btn_flood = btn!("Flood");
    let btn_drag = btn!("Drag");

    toolbar_row2.append(&btn_save);
    toolbar_row2.append(&btn_load);
    toolbar_row2.append(&btn_copy);
    toolbar_row2.append(&btn_paste);
    toolbar_row2.append(&btn_add_row);
    toolbar_row2.append(&btn_del_row);
    toolbar_row2.append(&btn_hide_col);
    toolbar_row2.append(&btn_freeze);
    toolbar_row2.append(&btn_autosize);
    toolbar_row2.append(&btn_print);
    toolbar_row2.append(&btn_mem);
    toolbar_row2.append(&btn_flood);
    toolbar_row2.append(&btn_drag);

    // Row 3: FormatStr, ColFmt, ExplBar toggle
    let toolbar_row3 = GtkBox::new(Orientation::Horizontal, 4);
    toolbar_row3.set_margin_start(4);
    toolbar_row3.set_margin_end(4);
    toolbar_row3.set_margin_bottom(2);

    let btn_format_str = btn!("FormatStr");
    let btn_col_fmt = btn!("ColFmt");
    let btn_expl_bar = btn!("ExplBar:Both");

    let btn_demo_stress = btn!("Stress");
    let btn_demo_sales = btn!("[Sales]");
    let btn_demo_hierarchy = btn!("Hierarchy");

    let btn_debug = btn!("Debug: OFF");
    let btn_gpu = btn!("CPU");
    let btn_anim = btn!("Anim: OFF");

    toolbar_row3.append(&btn_demo_sales);
    toolbar_row3.append(&btn_demo_hierarchy);
    toolbar_row3.append(&btn_demo_stress);
    toolbar_row3.append(&Separator::new(Orientation::Vertical));
    toolbar_row3.append(&btn_format_str);
    toolbar_row3.append(&btn_col_fmt);
    toolbar_row3.append(&btn_expl_bar);
    toolbar_row3.append(&btn_debug);
    toolbar_row3.append(&btn_gpu);
    toolbar_row3.append(&btn_anim);

    // ── Button Handlers ─────────────────────────────────────────────────

    // Helper: switch to a different demo mode
    macro_rules! demo_switch_handler {
        ($btn:expr, $mode:expr, $state:expr, $area:expr, $status:expr,
         $btn_stress:expr, $btn_sales:expr, $btn_hierarchy:expr) => {{
            let state = Rc::clone(&$state);
            let area = $area.clone();
            let status = $status.clone();
            let bs = $btn_stress.clone();
            let bsa = $btn_sales.clone();
            let bh = $btn_hierarchy.clone();
            $btn.connect_clicked(move |_| {
                let mut st = state.borrow_mut();
                if st.demo_mode == $mode {
                    return;
                }
                let w = st.grid.viewport_width.max(800);
                let h = st.grid.viewport_height.max(600);
                let renderer_mode = st.grid.renderer_mode;
                let debug_overlay = st.debug_overlay;
                st.grid = create_demo_grid($mode, w, h);
                st.grid.renderer_mode = renderer_mode;
                st.grid.debug_overlay = debug_overlay;
                st.grid.selection.mode = selection_mode_value(st.selection_mode_idx);
                st.demo_mode = $mode;
                st.frame_surface = None;
                clear_multirange_drag(&mut st);
                st.span_on = false;
                st.outline_on = false;
                st.frozen = false;
                st.col_hidden = false;
                st.saved_data = None;
                st.event_count = 0;
                st.last_event = "(none)".to_string();
                ensure_layout(&mut st.grid);
                let label = match $mode {
                    DEMO_SALES => "Sales Demo",
                    DEMO_HIERARCHY => "Hierarchy Demo",
                    _ => "Stress Demo",
                };
                let s = drain_events(&mut st);
                status.set_text(&format!(
                    "{} ({} rows x {} cols) | {}",
                    label, st.grid.rows, st.grid.cols, s
                ));
                bs.set_label(if $mode == DEMO_STRESS {
                    "[Stress]"
                } else {
                    "Stress"
                });
                bsa.set_label(if $mode == DEMO_SALES {
                    "[Sales]"
                } else {
                    "Sales"
                });
                bh.set_label(if $mode == DEMO_HIERARCHY {
                    "[Hierarchy]"
                } else {
                    "Hierarchy"
                });
                drop(st);
                area.queue_draw();
            });
        }};
    }

    demo_switch_handler!(
        btn_demo_stress,
        DEMO_STRESS,
        state,
        drawing_area,
        status_label,
        btn_demo_stress,
        btn_demo_sales,
        btn_demo_hierarchy
    );
    demo_switch_handler!(
        btn_demo_sales,
        DEMO_SALES,
        state,
        drawing_area,
        status_label,
        btn_demo_stress,
        btn_demo_sales,
        btn_demo_hierarchy
    );
    demo_switch_handler!(
        btn_demo_hierarchy,
        DEMO_HIERARCHY,
        state,
        drawing_area,
        status_label,
        btn_demo_stress,
        btn_demo_sales,
        btn_demo_hierarchy
    );

    // Style: apply cell-level style overrides
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_style.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            apply_styles(&mut st.grid);
            let s = drain_events(&mut st);
            status.set_text(&s);
            drop(st);
            area.queue_draw();
        });
    }

    // Selection mode dropdown: Free / ByRow / ByCol / Listbox / MultiRange
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        selection_mode.connect_selected_notify(move |dropdown| {
            let mut st = state.borrow_mut();
            st.selection_mode_idx = dropdown.selected();
            st.grid.selection.mode = selection_mode_value(st.selection_mode_idx);
            clear_multirange_drag(&mut st);
            let s = drain_events(&mut st);
            status.set_text(&s);
            drop(st);
            area.queue_draw();
        });
    }

    // Sort ascending (generic)
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_sort_asc.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            sort::sort_grid(&mut st.grid, 1, -1); // 1 = generic ascending, -1 = current col
            ensure_layout(&mut st.grid);
            let s = drain_events(&mut st);
            status.set_text(&s);
            drop(st);
            area.queue_draw();
        });
    }

    // Sort descending (generic)
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_sort_desc.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            sort::sort_grid(&mut st.grid, 2, -1); // 2 = generic descending
            ensure_layout(&mut st.grid);
            let s = drain_events(&mut st);
            status.set_text(&s);
            drop(st);
            area.queue_draw();
        });
    }

    // Span toggle
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_span.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            st.span_on = !st.span_on;
            if st.span_on {
                // Span only second column (index 1) in scrollable data cells.
                st.grid.span.mode = 4; // SPAN_RESTRICT_ALL
                st.grid.span.mode_fixed = 0; // SPAN_NEVER for fixed/header cells
                st.grid.span.span_rows.clear();
                st.grid.span.span_cols.clear();
                st.grid.span.span_cols.insert(1, true);
                st.grid.span.span_compare = 1; // no-case

                // Ensure adjacent duplicates for visible spans in Product column.
                sort::sort_grid(&mut st.grid, 5, 1); // string no-case ascending on col 1
            } else {
                st.grid.span.mode = 0; // SPAN_NEVER
                st.grid.span.mode_fixed = 0;
                st.grid.span.span_compare = 0;
                st.grid.span.span_rows.clear();
                st.grid.span.span_cols.clear();
            }
            st.grid.layout.invalidate();
            st.grid.mark_dirty();
            ensure_layout(&mut st.grid);
            let s = drain_events(&mut st);
            status.set_text(&s);
            drop(st);
            area.queue_draw();
        });
    }

    // Outline toggle: add subtotals + outline, or collapse/expand
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_outline.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            if !st.outline_on {
                // First sort by Category so groups are contiguous
                sort::sort_grid(&mut st.grid, 5, 2);
                // Add subtotals: group by col 2 (Category), SUM on col 3 (Sales)
                outline::subtotal(
                    &mut st.grid,
                    2, // AGG_SUM
                    2, // group_on_col = Category
                    3, // aggregate_col = Sales
                    "Total",
                    0xFFE0E0E0, // light gray background
                    0xFF000000, // black text
                    true,       // add_outline
                );
                st.grid.outline.tree_indicator = 1;
                st.outline_on = true;
            } else {
                // Toggle collapse: collapse level 0 to show only subtotals
                let current_row = st.grid.selection.row;
                if current_row >= st.grid.fixed_rows {
                    outline::toggle_collapse(&mut st.grid, current_row);
                } else {
                    // Collapse all to level 1
                    outline::outline(&mut st.grid, 0);
                }
            }
            ensure_layout(&mut st.grid);
            let s = drain_events(&mut st);
            status.set_text(&s);
            drop(st);
            area.queue_draw();
        });
    }

    // Edit mode toggle: 0 -> 1 -> 2 -> 0
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        let edit_btn = btn_edit.clone();
        btn_edit.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            st.grid.edit_trigger_mode = (st.grid.edit_trigger_mode + 1) % 3;
            let mode_str = match st.grid.edit_trigger_mode {
                0 => "Edit: OFF",
                1 => "Edit: Enter/F2",
                2 => "Edit: DblClick",
                _ => "Edit: ???",
            };
            edit_btn.set_label(mode_str);
            let s = drain_events(&mut st);
            status.set_text(&format!("{} | {}", mode_str, s));
            drop(st);
            area.queue_draw();
        });
    }

    // Find: search for "Widget" in Product column (col 1)
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_find.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            let start = st.grid.selection.row + 1;
            let row = search::find_row(&st.grid, "Gadget", start, 1, false, false);
            if row >= 0 {
                move_cursor_and_show(&mut st.grid, row, 1);
                let s = drain_events(&mut st);
                status.set_text(&format!("Found 'Gadget' at row {} | {}", row, s));
            } else {
                let fixed = st.grid.fixed_rows;
                let row2 = search::find_row(&st.grid, "Gadget", fixed, 1, false, false);
                if row2 >= 0 {
                    move_cursor_and_show(&mut st.grid, row2, 1);
                    let s = drain_events(&mut st);
                    status.set_text(&format!("Found 'Gadget' at row {} (wrapped) | {}", row2, s));
                } else {
                    status.set_text("'Gadget' not found");
                }
            }
            drop(st);
            area.queue_draw();
        });
    }

    // Save: binary format
    {
        let state = Rc::clone(&state);
        let status = status_label.clone();
        btn_save.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            let data = save::save_grid(&st.grid, 0, 0);
            let len = data.len();
            st.saved_data = Some(data);
            let s = drain_events(&mut st);
            status.set_text(&format!("Saved {} bytes (binary) | {}", len, s));
        });
    }

    // Load: from saved binary data
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_load.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            if let Some(ref data) = st.saved_data.clone() {
                save::load_grid(&mut st.grid, data, 0, 0);
                ensure_layout(&mut st.grid);
                let s = drain_events(&mut st);
                status.set_text(&format!("Loaded {} bytes | {}", data.len(), s));
            } else {
                status.set_text("No saved data — click Save first");
            }
            drop(st);
            area.queue_draw();
        });
    }

    // Copy
    {
        let state = Rc::clone(&state);
        let status = status_label.clone();
        btn_copy.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            let (text, _) = clipboard::copy(&st.grid);
            let len = text.len();
            set_system_clipboard_text(&text);
            st.clipboard_text = text;
            let s = drain_events(&mut st);
            status.set_text(&format!("Copied {} chars | {}", len, s));
        });
    }

    // Paste
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_paste.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            let text = st.clipboard_text.clone();
            if !text.is_empty() {
                clipboard::paste(&mut st.grid, &text);
                let s = drain_events(&mut st);
                status.set_text(&format!("Pasted {} chars | {}", text.len(), s));
            } else {
                status.set_text("Clipboard empty — Copy first");
            }
            drop(st);
            area.queue_draw();
        });
    }

    // Add rows using add_item (tab-delimited text)
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_add_row.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            let insert_at = st.grid.selection.row + 1;
            for i in 0..5 {
                let r = insert_at + i;
                let text = format!(
                    "{}\tNew-{}\tAdded\t{}\tQ1\tNorth\tActive\t50%\tnew note\tRed",
                    r,
                    r,
                    r * 50
                );
                st.grid.add_item(&text, insert_at + i);
            }
            ensure_layout(&mut st.grid);
            let s = drain_events(&mut st);
            status.set_text(&format!(
                "Added 5 rows at {} (total: {}) | {}",
                insert_at, st.grid.rows, s
            ));
            drop(st);
            area.queue_draw();
        });
    }

    // Delete row using remove_item
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_del_row.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            let row = st.grid.selection.row;
            if row >= st.grid.fixed_rows && st.grid.rows > st.grid.fixed_rows + 1 {
                st.grid.remove_item(row);
                ensure_layout(&mut st.grid);
                let s = drain_events(&mut st);
                status.set_text(&format!(
                    "Deleted row {} (total: {}) | {}",
                    row, st.grid.rows, s
                ));
            } else {
                status.set_text("Cannot delete: select a data row");
            }
            drop(st);
            area.queue_draw();
        });
    }

    // Hide/show column toggle (hides col 8 = Notes)
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_hide_col.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            st.col_hidden = !st.col_hidden;
            if st.col_hidden {
                st.grid.cols_hidden.insert(8);
            } else {
                st.grid.cols_hidden.remove(&8);
            }
            st.grid.layout.invalidate();
            st.grid.mark_dirty();
            ensure_layout(&mut st.grid);
            let s = drain_events(&mut st);
            let action = if st.col_hidden { "Hidden" } else { "Shown" };
            status.set_text(&format!("{} col 8 (Notes) | {}", action, s));
            drop(st);
            area.queue_draw();
        });
    }

    // Freeze toggle
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_freeze.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            st.frozen = !st.frozen;
            if st.frozen {
                st.grid.frozen_rows = 2;
                st.grid.frozen_cols = 1;
            } else {
                st.grid.frozen_rows = 0;
                st.grid.frozen_cols = 0;
            }
            st.grid.layout.invalidate();
            st.grid.mark_dirty();
            ensure_layout(&mut st.grid);
            let s = drain_events(&mut st);
            let action = if st.frozen {
                "Frozen 2 rows + 1 col"
            } else {
                "Unfrozen"
            };
            status.set_text(&format!("{} | {}", action, s));
            drop(st);
            area.queue_draw();
        });
    }

    // AutoSize all columns
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_autosize.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            let cols = st.grid.cols;
            for c in 0..cols {
                st.grid.auto_resize_col(c);
            }
            ensure_layout(&mut st.grid);
            let s = drain_events(&mut st);
            status.set_text(&format!("Auto-sized {} columns | {}", cols, s));
            drop(st);
            area.queue_draw();
        });
    }

    // Print
    {
        let state = Rc::clone(&state);
        let status = status_label.clone();
        btn_print.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            ensure_layout(&mut st.grid);
            let pages = print::print_grid(
                &mut st.grid,
                0, // portrait
                48,
                48,
                48,
                48, // margins
                "",
                "",
                false,
            );
            let page_count = pages.len();
            let total_bytes: usize = pages.iter().map(|p| p.image_data.len()).sum();
            let s = drain_events(&mut st);
            status.set_text(&format!(
                "Print: {} pages, {} bytes total | {}",
                page_count, total_bytes, s
            ));
        });
    }

    // Mem: report estimated heap usage for current grid instance
    {
        let state = Rc::clone(&state);
        let status = status_label.clone();
        btn_mem.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            let m = st.grid.memory_usage();
            let s = drain_events(&mut st);
            status.set_text(&format!(
                "Mem total={} cell={} style={} layout={} text={} rows={} cols={} cells={} | {}",
                human_bytes(m.total_bytes),
                human_bytes(m.cell_data_bytes),
                human_bytes(m.style_bytes),
                human_bytes(m.layout_bytes),
                human_bytes(m.text_engine_bytes),
                m.rows,
                m.cols,
                m.cell_count,
                s
            ));
        });
    }

    // Flood: toggle flood fill on Rating column
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_flood.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            let cur = st.grid.columns[7].progress_color;
            if cur != 0 {
                st.grid.columns[7].progress_color = 0;
            } else {
                st.grid.columns[7].progress_color = 0xFF4488CC;
            }
            st.grid.mark_dirty();
            let s = drain_events(&mut st);
            let action = if st.grid.columns[7].progress_color != 0 {
                "ON"
            } else {
                "OFF"
            };
            status.set_text(&format!("Flood fill {} on Rating column | {}", action, s));
            drop(st);
            area.queue_draw();
        });
    }

    // Drag: move current row down by 1
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_drag.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            let row = st.grid.selection.row;
            let col = st.grid.selection.col;
            if row >= st.grid.fixed_rows && row < st.grid.rows - 1 {
                drag::drag_row(&mut st.grid, row, row + 1);
                move_cursor_and_show(&mut st.grid, row + 1, col);
                ensure_layout(&mut st.grid);
                let s = drain_events(&mut st);
                status.set_text(&format!("Dragged row {} -> {} | {}", row, row + 1, s));
            } else {
                status.set_text("Cannot drag: select a data row (not last)");
            }
            drop(st);
            area.queue_draw();
        });
    }

    // FormatString: apply a pipe-delimited column format
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        btn_format_str.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            st.grid.format_string = "<#;40|<Product;110|<Category;90|>Sales;80|^Quarter;70|<Region;80|<Status;60|^Rating%;60|<Notes;120|<Combo;90".to_string();
            st.grid.apply_format_string();
            ensure_layout(&mut st.grid);
            let s = drain_events(&mut st);
            status.set_text(&format!("Applied FormatString ({} cols) | {}", st.grid.cols, s));
            drop(st);
            area.queue_draw();
        });
    }

    // ColFormat toggle: apply/clear currency format on Sales column
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        let fmt_btn = btn_col_fmt.clone();
        btn_col_fmt.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            let current = st.grid.columns[3].format.clone();
            if current.is_empty() {
                st.grid.columns[3].format = "$#,##0.00".to_string();
                fmt_btn.set_label("ColFmt:$");
            } else {
                st.grid.columns[3].format.clear();
                fmt_btn.set_label("ColFmt");
            }
            st.grid.mark_dirty();
            let s = drain_events(&mut st);
            let lbl = if st.grid.columns[3].format.is_empty() {
                "Cleared"
            } else {
                &st.grid.columns[3].format
            };
            status.set_text(&format!("ColFormat Sales: {} | {}", lbl, s));
            drop(st);
            area.queue_draw();
        });
    }

    // ExplorerBar mode cycle: 0 -> 1 -> 2 -> 3 -> 0
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let status = status_label.clone();
        let expl_btn = btn_expl_bar.clone();
        btn_expl_bar.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            st.grid.header_features = (st.grid.header_features + 1) % 4;
            let label = match st.grid.header_features {
                0 => "ExplBar:Off",
                1 => "ExplBar:Sort",
                2 => "ExplBar:Move",
                3 => "ExplBar:Both",
                _ => "ExplBar:?",
            };
            expl_btn.set_label(label);
            st.grid.mark_dirty();
            let s = drain_events(&mut st);
            status.set_text(&format!("{} | {}", label, s));
            drop(st);
            area.queue_draw();
        });
    }

    // Debug overlay toggle
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let dbg_btn = btn_debug.clone();
        btn_debug.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            st.debug_overlay = !st.debug_overlay;
            st.grid.debug_overlay = st.debug_overlay;
            dbg_btn.set_label(if st.debug_overlay {
                "Debug: ON"
            } else {
                "Debug: OFF"
            });
            st.grid.mark_dirty();
            drop(st);
            area.queue_draw();
        });
    }

    // GPU/CPU toggle
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let gpu_btn = btn_gpu.clone();
        btn_gpu.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            let new_mode = if st.grid.renderer_mode == 1 { 2 } else { 1 };
            st.grid.renderer_mode = new_mode;
            gpu_btn.set_label(if new_mode >= 2 { "GPU" } else { "CPU" });
            st.grid.mark_dirty();
            drop(st);
            area.queue_draw();
        });
    }

    // Animation toggle
    {
        let state = Rc::clone(&state);
        let area = drawing_area.clone();
        let anim_btn = btn_anim.clone();
        btn_anim.connect_clicked(move |_| {
            let mut st = state.borrow_mut();
            let enabled = !st.grid.animation.enabled;
            st.grid.animation.enabled = enabled;
            if !enabled {
                st.grid.animation.clear();
            }
            anim_btn.set_label(if enabled { "Anim: ON" } else { "Anim: OFF" });
            st.grid.mark_dirty();
            drop(st);
            area.queue_draw();
        });
    }

    // ── Main Layout ─────────────────────────────────────────────────────
    let vbox = GtkBox::new(Orientation::Vertical, 0);
    vbox.append(&toolbar_row1);
    vbox.append(&toolbar_row2);
    vbox.append(&toolbar_row3);
    vbox.append(&Separator::new(Orientation::Horizontal));
    vbox.append(&grid_overlay);
    vbox.append(&Separator::new(Orientation::Horizontal));
    vbox.append(&status_label);

    // ── Window ──────────────────────────────────────────────────────────
    let window = ApplicationWindow::builder()
        .application(app)
        .title("VolvoxGrid GTK4 — Full Feature Test")
        .default_width(width)
        .default_height(height)
        .child(&vbox)
        .build();

    // Grab focus on the drawing area after the window is shown
    {
        let area = drawing_area.clone();
        window.connect_show(move |_win| {
            area.grab_focus();
        });
    }

    window.present();
}

/// Apply diverse cell styles to demonstrate styling features.
fn apply_styles(grid: &mut VolvoxGrid) {
    // Toggle grid lines through: flat -> raised -> inset -> none -> flat
    grid.style.grid_lines = (grid.style.grid_lines + 1) % 4;

    // Color some header cells
    grid.cell_styles.insert(
        (0, 1),
        CellStyleOverride {
            back_color: Some(0xFF2244AA),
            fore_color: Some(0xFFFFFFFF),
            font_bold: Some(true),
            ..Default::default()
        },
    );
    grid.cell_styles.insert(
        (0, 3),
        CellStyleOverride {
            back_color: Some(0xFF228844),
            fore_color: Some(0xFFFFFFFF),
            font_bold: Some(true),
            ..Default::default()
        },
    );

    // Red background on some Sales cells
    for r in 1..=5 {
        grid.cell_styles.insert(
            (r, 3),
            CellStyleOverride {
                back_color: Some(0xFFFFE0E0),
                fore_color: Some(0xFFCC0000),
                font_bold: Some(true),
                ..Default::default()
            },
        );
    }

    // Italic on some Note cells
    for r in 1..=10 {
        grid.cell_styles.insert(
            (r, 8),
            CellStyleOverride {
                font_italic: Some(true),
                fore_color: Some(0xFF666666),
                ..Default::default()
            },
        );
    }

    // Bold alignment override on Region column
    for r in 1..=20 {
        grid.cell_styles.insert(
            (r, 5),
            CellStyleOverride {
                alignment: Some(1), // center
                font_bold: Some(true),
                ..Default::default()
            },
        );
    }

    grid.mark_dirty();
}

/// Convert RGBA pixel buffer to BGRA for Cairo ARGB32 on little-endian.
fn rgba_to_bgra(buf: &mut [u8]) {
    let len = buf.len();
    let mut i = 0;
    while i + 3 < len {
        buf.swap(i, i + 2); // swap R and B
        i += 4;
    }
}

/// Map GDK4 keyval to Windows virtual key code (used by the engine).
fn gdk_keyval_to_vk(keyval: gdk::Key) -> i32 {
    match keyval {
        gdk::Key::Left => 37,
        gdk::Key::Up => 38,
        gdk::Key::Right => 39,
        gdk::Key::Down => 40,
        gdk::Key::Page_Up => 33,
        gdk::Key::Page_Down => 34,
        gdk::Key::Home => 36,
        gdk::Key::End => 35,
        gdk::Key::Tab | gdk::Key::ISO_Left_Tab => 9,
        gdk::Key::Return | gdk::Key::KP_Enter => 13,
        gdk::Key::Delete => 46,
        gdk::Key::BackSpace => 8,
        gdk::Key::F2 => 113,
        gdk::Key::a => 65,
        gdk::Key::c => 67,
        gdk::Key::v => 86,
        gdk::Key::x => 88,
        gdk::Key::z => 90,
        gdk::Key::f => 70,
        gdk::Key::s => 83,
        gdk::Key::Escape => 27,
        _ => 0,
    }
}

/// Map GDK4 modifier state to engine modifier flags.
/// Engine: bit 0 = shift, bit 1 = ctrl
fn gdk_modifier_to_flags(state: gdk::ModifierType) -> i32 {
    let mut flags = 0;
    if state.contains(gdk::ModifierType::SHIFT_MASK) {
        flags |= 1;
    }
    if state.contains(gdk::ModifierType::CONTROL_MASK) {
        flags |= 2;
    }
    flags
}
