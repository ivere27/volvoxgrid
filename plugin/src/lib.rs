use std::collections::{HashMap, HashSet};
use std::sync::{
    atomic::{AtomicI64, Ordering},
    Mutex,
};
use std::time::{Duration, Instant};

use volvoxgrid_engine::cell::CellValueData;
use volvoxgrid_engine::proto::volvoxgrid::v1::*;
use volvoxgrid_engine::GridManager;

#[path = "volvoxgrid_ffi_plugin.rs"]
mod ffi_impl;
use ffi_impl::*;

#[cfg(all(target_os = "windows", target_env = "gnu"))]
unsafe extern "C" {
    fn volvoxgrid_windows_mingw_compat_force_link();
}

// Shared GridManager accessible by both the plugin and demo FFI exports.
lazy_static::lazy_static! {
    static ref SHARED_GRID_MANAGER: GridManager = GridManager::new();
}

struct VolvoxGridPlugin {
    next_event_id: AtomicI64,
    decision_enabled: Mutex<HashSet<i64>>,
    pending_actions: Mutex<HashMap<(i64, i64), PendingActionEntry>>,
    zoom_levels: Mutex<HashMap<i64, f64>>,
    loaded_font_data: Mutex<Vec<Vec<u8>>>,
}

#[derive(Clone, Debug)]
enum PendingAction {
    BeginEdit {
        row: i32,
        col: i32,
        force: bool,
        prefer_combo: bool,
        seed_text: Option<String>,
    },
    ValidateEdit {
        row: i32,
        col: i32,
        old_text: String,
        committed_text: String,
    },
    BeforeSort {
        col: i32,
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
    base_font_size: Option<f32>,
}

impl VolvoxGridPlugin {
    const DECISION_TIMEOUT: Duration = Duration::from_millis(250);

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

// ---------------------------------------------------------------------------
// Helper: convert proto CellValue to engine CellValueData
// ---------------------------------------------------------------------------
fn proto_value_to_engine(cv: &Option<CellValue>) -> CellValueData {
    match cv {
        Some(cv) => match &cv.value {
            Some(cell_value::Value::Text(t)) => CellValueData::Text(t.clone()),
            Some(cell_value::Value::Number(n)) => CellValueData::Number(*n),
            Some(cell_value::Value::Flag(b)) => CellValueData::Bool(*b),
            Some(cell_value::Value::Data(d)) => CellValueData::Bytes(d.clone()),
            Some(cell_value::Value::Timestamp(ts)) => CellValueData::Timestamp(*ts),
            None => CellValueData::Empty,
        },
        None => CellValueData::Empty,
    }
}

// ---------------------------------------------------------------------------
// Helper: convert engine CellValueData to proto CellValue
// ---------------------------------------------------------------------------
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
            value: Some(cell_value::Value::Data(d.clone())),
        },
        CellValueData::Timestamp(ts) => CellValue {
            value: Some(cell_value::Value::Timestamp(*ts)),
        },
        CellValueData::Empty => CellValue { value: None },
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
                cancel: false,
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
            old_row_end,
            old_col_end,
            new_row_end,
            new_col_end,
        } => Some(grid_event::Event::SelectionChanging(
            SelectionChangingEvent {
                old_ranges: vec![normalize_range(
                    old_row_end,
                    old_col_end,
                    old_row_end,
                    old_col_end,
                )],
                new_ranges: vec![normalize_range(
                    new_row_end,
                    new_col_end,
                    new_row_end,
                    new_col_end,
                )],
                active_row: new_row_end,
                active_col: new_col_end,
                cancel: false,
            },
        )),
        E::SelectionChanged {
            old_row_end,
            old_col_end,
            new_row_end,
            new_col_end,
        } => Some(grid_event::Event::SelectionChanged(SelectionChangedEvent {
            old_ranges: vec![normalize_range(
                old_row_end,
                old_col_end,
                old_row_end,
                old_col_end,
            )],
            new_ranges: vec![normalize_range(
                new_row_end,
                new_col_end,
                new_row_end,
                new_col_end,
            )],
            active_row: new_row_end,
            active_col: new_col_end,
        })),
        E::EnterCell { row, col } => {
            Some(grid_event::Event::EnterCell(EnterCellEvent { row, col }))
        }
        E::LeaveCell { row, col } => {
            Some(grid_event::Event::LeaveCell(LeaveCellEvent { row, col }))
        }
        E::BeforeEdit { row, col } => Some(grid_event::Event::BeforeEdit(BeforeEditEvent {
            row,
            col,
            cancel: false,
        })),
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
            cancel: false,
        })),
        E::CellEditChange { text } => {
            Some(grid_event::Event::CellEditChange(CellEditChangeEvent {
                text,
            }))
        }
        E::CellButtonClick { row, col } => {
            Some(grid_event::Event::CellButtonClick(CellButtonClickEvent {
                row,
                col,
            }))
        }
        E::KeyDownEdit { key_code, shift } => {
            Some(grid_event::Event::KeyDownEdit(KeyDownEditEvent {
                key_code,
                shift,
            }))
        }
        E::KeyPressEdit { key_ascii } => Some(grid_event::Event::KeyPressEdit(KeyPressEditEvent {
            key_ascii,
        })),
        E::KeyUpEdit { key_code, shift } => Some(grid_event::Event::KeyUpEdit(KeyUpEditEvent {
            key_code,
            shift,
        })),
        E::CellEditConfigureStyle { row, col } => Some(grid_event::Event::CellEditConfigureStyle(
            CellEditConfigureStyleEvent { row, col },
        )),
        E::CellEditConfigureWindow { row, col } => Some(
            grid_event::Event::CellEditConfigureWindow(CellEditConfigureWindowEvent { row, col }),
        ),
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
                status,
            }))
        }
        E::BeforeSort { col } => Some(grid_event::Event::BeforeSort(BeforeSortEvent {
            col,
            cancel: false,
        })),
        E::AfterSort { col } => Some(grid_event::Event::AfterSort(AfterSortEvent { col })),
        E::Compare {
            row1,
            row2,
            col,
            result,
        } => Some(grid_event::Event::Compare(CompareEvent {
            row1,
            row2,
            col,
            result,
        })),
        E::BeforeNodeToggle { row, collapse } => {
            Some(grid_event::Event::BeforeNodeToggle(BeforeNodeToggleEvent {
                row,
                collapse,
                cancel: false,
            }))
        }
        E::AfterNodeToggle { row, collapse } => {
            Some(grid_event::Event::AfterNodeToggle(AfterNodeToggleEvent {
                row,
                collapse,
            }))
        }
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
            cancel: false,
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
                cancel: false,
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
                cancel: false,
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
                cancel: false,
            }))
        }
        E::AfterMoveRow { row, old_position } => {
            Some(grid_event::Event::AfterMoveRow(AfterMoveRowEvent {
                row,
                old_position,
            }))
        }
        E::BeforeMouseDown { row, col } => {
            Some(grid_event::Event::BeforeMouseDown(BeforeMouseDownEvent {
                row,
                col,
                cancel: false,
            }))
        }
        E::MouseDown {
            button,
            shift,
            x,
            y,
        } => Some(grid_event::Event::MouseDown(MouseDownEvent {
            button,
            shift,
            x,
            y,
        })),
        E::MouseUp {
            button,
            shift,
            x,
            y,
        } => Some(grid_event::Event::MouseUp(MouseUpEvent {
            button,
            shift,
            x,
            y,
        })),
        E::MouseMove {
            button,
            shift,
            x,
            y,
        } => Some(grid_event::Event::MouseMove(MouseMoveEvent {
            button,
            shift,
            x,
            y,
        })),
        E::Click => Some(grid_event::Event::Click(ClickEvent {})),
        E::DblClick => Some(grid_event::Event::DblClick(DblClickEvent {})),
        E::KeyDown { key_code, shift } => {
            Some(grid_event::Event::KeyDown(KeyDownEvent { key_code, shift }))
        }
        E::KeyPress { key_ascii } => Some(grid_event::Event::KeyPress(KeyPressEvent { key_ascii })),
        E::KeyUp { key_code, shift } => {
            Some(grid_event::Event::KeyUp(KeyUpEvent { key_code, shift }))
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
        E::DataRefreshing => Some(grid_event::Event::DataRefreshing(DataRefreshingEvent {
            cancel: false,
        })),
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
                cancel: false,
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

fn truncate_to_char_count(s: &str, max_chars: i32) -> String {
    if max_chars <= 0 {
        return s.to_string();
    }
    let max = max_chars as usize;
    let mut out = String::new();
    for (i, ch) in s.chars().enumerate() {
        if i >= max {
            break;
        }
        out.push(ch);
    }
    out
}

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
    let (x, y, w, h) = grid.edit_cell_rect(row, col)?;
    let current_value =
        if grid.edit.is_active() && grid.edit.edit_row == row && grid.edit.edit_col == col {
            grid.edit.edit_text.clone()
        } else {
            grid.get_display_text(row, col)
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
    if prefer_combo && grid.edit.dropdown_count() > 0 {
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

fn begin_edit_session_core(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    row: i32,
    col: i32,
    force: bool,
    emit_before_event: bool,
) {
    begin_edit_session_core_opts(
        grid,
        row,
        col,
        force,
        emit_before_event,
        None,
        None,
        None,
        None,
    );
}

fn begin_edit_session_core_opts(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    row: i32,
    col: i32,
    force: bool,
    emit_before_event: bool,
    select_all: Option<bool>,
    caret_end: Option<bool>,
    seed_text: Option<String>,
    formula_mode: Option<bool>,
) {
    if !grid.can_begin_edit(row, col, force) {
        return;
    }

    let combo_list = grid.active_dropdown_list(row, col);
    if emit_before_event {
        grid.events
            .push(volvoxgrid_engine::event::GridEventData::BeforeEdit { row, col });
    }

    if combo_list.trim() == "..." {
        grid.events
            .push(volvoxgrid_engine::event::GridEventData::CellButtonClick { row, col });
        return;
    }

    let stored_text = grid.cells.get_text(row, col).to_string();
    let display_text = grid.get_display_text(row, col);
    grid.edit.start_edit_with_options(
        row,
        col,
        &display_text,
        select_all,
        caret_end,
        seed_text.as_deref(),
        formula_mode,
    );
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
    }

    if !combo_list.is_empty() {
        grid.events
            .push(volvoxgrid_engine::event::GridEventData::DropdownOpened);
    }
    grid.events
        .push(volvoxgrid_engine::event::GridEventData::StartEdit { row, col });
}

fn begin_edit_session(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    row: i32,
    col: i32,
    force: bool,
) {
    begin_edit_session_core(grid, row, col, force, true);
}

fn begin_edit_session_after_before(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    row: i32,
    col: i32,
    force: bool,
) {
    begin_edit_session_core(grid, row, col, force, false);
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

    if old_text != committed {
        grid.events
            .push(volvoxgrid_engine::event::GridEventData::AfterEdit {
                row,
                col,
                old_text: old_text.clone(),
                new_text: committed.clone(),
            });
        grid.events
            .push(volvoxgrid_engine::event::GridEventData::CellChanged {
                row,
                col,
                old_text,
                new_text: committed,
            });
    }

    let active_combo = grid.active_dropdown_list(row, col);
    if !active_combo.is_empty() && active_combo.trim() != "..." {
        grid.events
            .push(volvoxgrid_engine::event::GridEventData::DropdownClosed);
    }
    grid.mark_dirty();
}

fn apply_before_sort(grid: &mut volvoxgrid_engine::grid::VolvoxGrid, col: i32) {
    let old_sort_keys = grid.sort_state.sort_keys.clone();
    volvoxgrid_engine::sort::handle_header_click(grid, col);
    if grid.sort_state.sort_keys != old_sort_keys {
        grid.events
            .push(volvoxgrid_engine::event::GridEventData::AfterSort { col });
    }
}

// ---------------------------------------------------------------------------
// VolvoxGridPlugin pending action / decision helpers
// ---------------------------------------------------------------------------
impl VolvoxGridPlugin {
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

    fn clear_grid_state(&self, grid_id: i64) {
        self.decision_enabled
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .remove(&grid_id);
        self.pending_actions
            .lock()
            .unwrap_or_else(|e| e.into_inner())
            .retain(|(pending_grid, _), _| *pending_grid != grid_id);
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
    ) -> Option<RenderOutput> {
        if !grid.can_begin_edit(row, col, force) {
            return None;
        }

        if !self.decision_channel_enabled(grid_id) {
            begin_edit_session(grid, row, col, force);
            if let Some(seed) = seed_text {
                if grid.edit.is_active() && grid.edit.edit_row == row && grid.edit.edit_col == col {
                    grid.edit.edit_text = seed.clone();
                    grid.edit.sel_start = seed.chars().count() as i32;
                    grid.edit.sel_length = 0;
                    grid.events
                        .push(volvoxgrid_engine::event::GridEventData::CellEditChange {
                            text: seed,
                        });
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
                    },
                },
            );
        grid.events.push_with_id(
            event_id,
            volvoxgrid_engine::event::GridEventData::BeforeEdit { row, col },
        );
        None
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
        let committed_text = normalize_committed_edit_text(grid, row, col, &new_text);

        if !self.decision_channel_enabled(grid_id) {
            grid.events
                .push(volvoxgrid_engine::event::GridEventData::CellEditValidate {
                    row,
                    col,
                    edit_text: committed_text.clone(),
                });
            apply_committed_edit_text(grid, row, col, old_text, committed_text);
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
            apply_before_sort(grid, col);
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

    fn apply_pending_action(
        &self,
        grid_id: i64,
        action: PendingAction,
        cancel: bool,
    ) -> Option<RenderOutput> {
        if cancel {
            return None;
        }

        match action {
            PendingAction::BeginEdit {
                row,
                col,
                force,
                prefer_combo,
                seed_text,
            } => self
                .manager()
                .with_grid(grid_id, |grid| {
                    begin_edit_session_after_before(grid, row, col, force);
                    if let Some(seed) = seed_text {
                        if grid.edit.is_active()
                            && grid.edit.edit_row == row
                            && grid.edit.edit_col == col
                        {
                            grid.edit.edit_text = seed.clone();
                            grid.edit.sel_start = seed.chars().count() as i32;
                            grid.edit.sel_length = 0;
                            grid.events.push(
                                volvoxgrid_engine::event::GridEventData::CellEditChange {
                                    text: seed,
                                },
                            );
                        }
                    }
                    maybe_render_editor_output(grid, prefer_combo)
                })
                .ok()
                .flatten(),
            PendingAction::ValidateEdit {
                row,
                col,
                old_text,
                committed_text,
            } => {
                let _ = self.manager().with_grid(grid_id, |grid| {
                    apply_committed_edit_text(grid, row, col, old_text, committed_text);
                });
                None
            }
            PendingAction::BeforeSort { col } => {
                let _ = self.manager().with_grid(grid_id, |grid| {
                    apply_before_sort(grid, col);
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
                    if key.0 == grid_id
                        && now.duration_since(entry.created_at) >= Self::DECISION_TIMEOUT
                    {
                        Some(*key)
                    } else {
                        None
                    }
                })
                .collect();
            for key in expired_keys {
                if let Some(entry) = pending.remove(&key) {
                    expired_actions.push(entry.action);
                }
            }
        }

        let mut outputs = Vec::new();
        for action in expired_actions {
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

impl VolvoxGridServicePlugin for VolvoxGridPlugin {
    // ── Lifecycle ──

    fn create(&self, request: CreateRequest) -> Result<GridHandle, String> {
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
        self.set_current_zoom_scale(id, 1.0);

        if let Some(config) = config {
            let _ = self.manager().with_grid(id, |grid| {
                grid.apply_config(config);
            });
        }

        Ok(GridHandle { id })
    }

    fn destroy(&self, request: GridHandle) -> Result<Empty, String> {
        self.clear_grid_state(request.id);
        self.manager().destroy_grid(request.id);
        Ok(Empty {})
    }

    // ── Configuration ──

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

    fn load_font_data(&self, request: LoadFontDataRequest) -> Result<Empty, String> {
        if request.data.is_empty() {
            return Err("font data is empty".to_string());
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
            return Ok(Empty {});
        }
        loaded.push(request.data);
        Ok(Empty {})
    }

    // ── Structure ──

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
                let row = request.index;
                if row < grid.fixed_rows || row >= grid.rows {
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

    // ── Data ──

    fn update_cells(&self, request: UpdateCellsRequest) -> Result<WriteResult, String> {
        self.manager()
            .with_grid(request.grid_id, |grid| grid.write_cells(&request.cells, request.atomic))
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
                ), // scrollable
                1 => (0, 0, grid.fixed_rows - 1, grid.cols - 1), // fixed rows
                2 => (0, 0, grid.rows - 1, grid.fixed_cols - 1), // fixed cols
                3 => (0, 0, grid.fixed_rows - 1, grid.fixed_cols - 1), // fixed both
                4 => (0, 0, grid.rows - 1, grid.cols - 1),       // all rows
                5 => (0, 0, grid.rows - 1, grid.cols - 1),       // all cols
                6 => (0, 0, grid.rows - 1, grid.cols - 1),       // all
                _ => (
                    grid.fixed_rows,
                    grid.fixed_cols,
                    grid.rows - 1,
                    grid.cols - 1,
                ),
            };
            match request.scope {
                0 => {
                    // CLEAR_EVERYTHING
                    grid.cells.clear_range(r1, c1, r2, c2);
                    for r in r1..=r2 {
                        for c in c1..=c2 {
                            grid.cell_styles.remove(&(r, c));
                        }
                    }
                }
                1 => {
                    // CLEAR_FORMATTING
                    for r in r1..=r2 {
                        for c in c1..=c2 {
                            grid.cell_styles.remove(&(r, c));
                        }
                    }
                }
                2 => {
                    // CLEAR_DATA
                    grid.cells.clear_range(r1, c1, r2, c2);
                }
                3 => {
                    // CLEAR_SELECTION
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

    // ── Selection ──

    fn select(&self, request: SelectRequest) -> Result<Empty, String> {
        fn end_from_range(range: &CellRange, active_row: i32, active_col: i32) -> (i32, i32) {
            if range.row1 == active_row && range.col1 == active_col {
                (range.row2, range.col2)
            } else if range.row2 == active_row && range.col2 == active_col {
                (range.row1, range.col1)
            } else {
                (range.row2, range.col2)
            }
        }

        self.manager().with_grid(request.grid_id, |grid| {
            let active_row = request.active_row;
            let active_col = request.active_col;
            let (row_end, col_end) = request
                .ranges
                .first()
                .map(|r| end_from_range(r, active_row, active_col))
                .unwrap_or((active_row, active_col));
            grid.selection.select(
                active_row, active_col, row_end, col_end, grid.rows, grid.cols,
            );
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
                ranges: vec![CellRange {
                    row1: grid.selection.row.min(grid.selection.row_end),
                    col1: grid.selection.col.min(grid.selection.col_end),
                    row2: grid.selection.row.max(grid.selection.row_end),
                    col2: grid.selection.col.max(grid.selection.col_end),
                }],
                top_row: grid.top_row(),
                left_col: grid.left_col(),
                bottom_row: grid.bottom_row(),
                right_col: grid.right_col(),
                mouse_row: grid.mouse_row,
                mouse_col: grid.mouse_col,
            }
        })
    }

    // ── Editing ──

    fn edit(&self, request: EditCommand) -> Result<EditState, String> {
        let grid_id = request.grid_id;
        let state = self.manager().with_grid(grid_id, |grid| {
            match request.command {
                Some(edit_command::Command::Start(start)) => {
                    begin_edit_session_core_opts(
                        grid,
                        start.row,
                        start.col,
                        false,
                        true,
                        start.select_all,
                        start.caret_end,
                        start.seed_text,
                        start.formula_mode,
                    );
                }
                Some(edit_command::Command::Commit(commit)) => {
                    if grid.edit.is_active() {
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
                        grid.edit.update_text(t.clone());
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
                Some(edit_command::Command::Finish(_)) => {
                    if grid.edit.is_active() {
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
            }
        })?;
        Ok(state)
    }

    // ── Actions ──

    fn sort(&self, request: SortRequest) -> Result<Empty, String> {
        self.manager().with_grid(request.grid_id, |grid| {
            if request.sort_columns.is_empty() {
                // No columns — clear sort state
                grid.sort_state.clear();
                grid.layout.invalidate();
                grid.mark_dirty();
            } else {
                let sort_keys: Vec<(i32, i32)> = request
                    .sort_columns
                    .iter()
                    .map(|sc| (sc.col, sc.order))
                    .collect();
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
                request.back_color,
                request.fore_color,
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
                // Find max width across the range and set all equal
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
            let _ = level; // unused, outline_level is returned
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

    // ── Clipboard ──

    fn clipboard(&self, request: ClipboardCommand) -> Result<ClipboardResponse, String> {
        let grid_id = request.grid_id;
        self.manager()
            .with_grid(grid_id, |grid| match request.command {
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

    // ── Import / Export ──

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

            let raw_pages = volvoxgrid_engine::print::print_grid(
                grid,
                orientation,
                margin_left,
                margin_top,
                margin_right,
                margin_bottom,
                header,
                footer,
                show_page_numbers,
            );

            raw_pages
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

    // ── Render Control ──

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
            Ok(Empty {})
        }
        #[cfg(not(feature = "demo"))]
        {
            let _ = request;
            Err("demo feature is not enabled".into())
        }
    }

    // ── Streaming: Render Session ──

    fn render_session(
        &self,
        stream: &dyn PluginStreamBidi<RenderInput, RenderOutput>,
    ) -> Result<(), String> {
        let mut renderer: Option<volvoxgrid_engine::render::Renderer> = None;
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
        let mut zoom_sessions: HashMap<i64, ZoomGestureState> = HashMap::new();

        while let Some(input) = stream.recv() {
            let grid_id = input.grid_id;
            for output in self.resolve_expired_actions(grid_id) {
                stream.send(output);
            }

            match input.input {
                Some(render_input::Input::Viewport(vs)) => {
                    let _ = self.manager().with_grid(grid_id, |grid| {
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

                    let result = self.manager().with_grid(grid_id, |grid| {
                        let needs_fling_tick = grid.fling_enabled && grid.scroll.fling_active;
                        if !grid.dirty && !needs_fling_tick {
                            return (false, 0, 0, 0, 0);
                        }

                        if !grid.layout.valid {
                            ensure_layout(grid);
                        }
                        let pinned_h = grid.pinned_top_height() + grid.pinned_bottom_height();
                        let pinned_w = grid.pinned_left_width() + grid.pinned_right_width();
                        grid.scroll.update_bounds(
                            &grid.layout,
                            grid.viewport_width,
                            grid.viewport_height,
                            grid.fixed_rows,
                            grid.fixed_cols,
                            pinned_h,
                            pinned_w,
                        );

                        if needs_fling_tick {
                            if grid.scroll.tick_fling(dt_seconds, grid.fling_friction) {
                                grid.mark_dirty();
                            }
                        }

                        if !grid.dirty {
                            return (false, 0, 0, 0, 0);
                        }

                        let handle = buf_ready.handle;
                        let stride = buf_ready.stride;
                        let width = buf_ready.width;
                        let height = buf_ready.height;

                        if handle == 0 || width <= 0 || height <= 0 || stride <= 0 {
                            return (false, 0, 0, 0, 0);
                        }

                        let buf_size = (stride * height) as usize;
                        let buffer =
                            unsafe { std::slice::from_raw_parts_mut(handle as *mut u8, buf_size) };

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
                                        grid.renderer_mode = 1;
                                    }
                                }
                            }
                            if let Some(gr) = gpu_renderer.as_mut() {
                                self.sync_fonts_into_gpu_renderer(gr, &mut gpu_font_count_applied);
                                grid.debug_renderer_actual = RendererMode::RendererGpu as i32;
                                grid.debug_gpu_backend = gr.backend_name();
                                grid.debug_gpu_present_mode = gr.present_mode_name();
                                grid.debug_text_cache_len = gr.text_cache_len() as i32;
                                let (dx, dy, dw, dh) =
                                    gr.render_to_buffer(grid, buffer, width, height, stride);
                                grid.debug_instance_count = gr.instance_count() as i32;
                                let elapsed = frame_start.elapsed().as_secs_f32() * 1000.0;
                                grid.debug_frame_time_ms = elapsed;
                                grid.debug_fps =
                                    grid.debug_fps * 0.9 + (1000.0 / elapsed.max(0.1)) * 0.1;
                                grid.clear_dirty();
                                return (true, dx, dy, dw, dh);
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
                        let (dx, dy, dw, dh) = r.render(grid, buffer, width, height, stride);
                        grid.debug_text_cache_len = r.text_cache_len() as i32;
                        let elapsed = frame_start.elapsed().as_secs_f32() * 1000.0;
                        grid.debug_frame_time_ms = elapsed;
                        grid.debug_fps = grid.debug_fps * 0.9 + (1000.0 / elapsed.max(0.1)) * 0.1;
                        grid.clear_dirty();
                        (true, dx, dy, dw, dh)
                    });

                    match result {
                        Ok((rendered, dx, dy, dw, dh)) => {
                            stream.send(RenderOutput {
                                rendered,
                                event: Some(render_output::Event::FrameDone(FrameDone {
                                    handle: buf_ready.handle,
                                    dirty_x: dx,
                                    dirty_y: dy,
                                    dirty_w: dw,
                                    dirty_h: dh,
                                })),
                            });
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
                        let _ = self.manager().with_grid(grid_id, |grid| {
                            grid.scroll.stop_fling();
                        });
                        stream.send(RenderOutput {
                            rendered: false,
                            event: Some(render_output::Event::GpuFrameDone(GpuFrameDone {
                                dirty_x: 0,
                                dirty_y: 0,
                                dirty_w: 0,
                                dirty_h: 0,
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
                                let _ = self.manager().with_grid(grid_id, |grid| {
                                    grid.renderer_mode = 1; // CPU fallback
                                });
                                stream.send(RenderOutput {
                                    rendered: false,
                                    event: Some(render_output::Event::GpuFrameDone(GpuFrameDone {
                                        dirty_x: 0,
                                        dirty_y: 0,
                                        dirty_w: 0,
                                        dirty_h: 0,
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
                            let _ = self.manager().with_grid(grid_id, |grid| {
                                grid.renderer_mode = 1; // CPU fallback
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
                                })),
                            });
                            continue;
                        }
                        last_surface_handle = handle;
                        last_present_mode = requested_pm;
                        // Surface reconfiguration can happen after Android HOME/resume
                        // with no data mutation. Force one redraw so the newly bound
                        // surface is populated instead of staying black.
                        let _ = self.manager().with_grid(grid_id, |grid| {
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
                                })),
                            });
                            continue;
                        }
                    }

                    self.sync_fonts_into_gpu_renderer(gr, &mut gpu_font_count_applied);

                    let gr_backend_name = gr.backend_name();
                    let gr_present_mode_name = gr.present_mode_name();
                    let gr_text_cache_len = gr.text_cache_len() as i32;

                    let result = self.manager().with_grid(grid_id, |grid| {
                        let needs_fling_tick = grid.fling_enabled && grid.scroll.fling_active;
                        if !grid.dirty && !needs_fling_tick {
                            return Ok((false, 0, 0, 0, 0));
                        }

                        if !grid.layout.valid {
                            ensure_layout(grid);
                        }
                        let pinned_h = grid.pinned_top_height() + grid.pinned_bottom_height();
                        let pinned_w = grid.pinned_left_width() + grid.pinned_right_width();
                        grid.scroll.update_bounds(
                            &grid.layout,
                            grid.viewport_width,
                            grid.viewport_height,
                            grid.fixed_rows,
                            grid.fixed_cols,
                            pinned_h,
                            pinned_w,
                        );

                        if needs_fling_tick {
                            if grid.scroll.tick_fling(dt_seconds, grid.fling_friction) {
                                grid.mark_dirty();
                            }
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
                            Ok((dx, dy, dw, dh)) => {
                                grid.debug_instance_count = gr.instance_count() as i32;
                                let elapsed = frame_start.elapsed().as_secs_f32() * 1000.0;
                                grid.debug_frame_time_ms = elapsed;
                                grid.debug_fps = grid.debug_fps * 0.9 + (1000.0 / elapsed.max(0.1)) * 0.1;
                                grid.clear_dirty();
                                Ok((true, dx, dy, dw, dh))
                            }
                            Err(e) => Err(e),
                        }
                    });

                    match result {
                        Ok(Ok((rendered, dx, dy, dw, dh))) => {
                            stream.send(RenderOutput {
                                rendered,
                                event: Some(render_output::Event::GpuFrameDone(GpuFrameDone {
                                    dirty_x: dx,
                                    dirty_y: dy,
                                    dirty_w: dw,
                                    dirty_h: dh,
                                })),
                            });
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
                                })),
                            });
                        }
                    }
                }

                Some(render_input::Input::Pointer(pe)) => {
                    let sel_and_editor = self.manager().with_grid(grid_id, |grid| {
                        if !grid.layout.valid {
                            ensure_layout(grid);
                        }

                        let decision_enabled = self.decision_channel_enabled(grid_id);
                        let was_editing = grid.edit.is_active();
                        let prev_edit_row = grid.edit.edit_row;
                        let prev_edit_col = grid.edit.edit_col;
                        let prev_sel = (
                            grid.selection.row,
                            grid.selection.col,
                            grid.selection.row_end,
                            grid.selection.col_end,
                        );
                        let hit = if pe.r#type == 0 {
                            Some(volvoxgrid_engine::input::hit_test(grid, pe.x, pe.y))
                        } else {
                            None
                        };
                        let prefer_combo = hit
                            .as_ref()
                            .map(|h| h.area == volvoxgrid_engine::input::HitArea::DropdownButton)
                            .unwrap_or(false);

                        match pe.r#type {
                            0 => {
                                // DOWN
                                if decision_enabled {
                                    volvoxgrid_engine::input::handle_pointer_down_with_behavior(
                                        grid,
                                        pe.x,
                                        pe.y,
                                        pe.button,
                                        pe.modifier,
                                        pe.dbl_click,
                                        volvoxgrid_engine::input::InputBehavior {
                                            allow_begin_edit: false,
                                            allow_header_sort: false,
                                        },
                                    );

                                    if let Some(hit) = hit.as_ref() {
                                        if hit.row >= 0 && hit.col >= 0 {
                                            let is_cell_like = hit.area
                                                == volvoxgrid_engine::input::HitArea::Cell
                                                || hit.area
                                                    == volvoxgrid_engine::input::HitArea::FixedRow
                                                || hit.area
                                                    == volvoxgrid_engine::input::HitArea::FixedCol;
                                            let combo_list = if is_cell_like {
                                                grid.active_dropdown_list(hit.row, hit.col)
                                            } else {
                                                String::new()
                                            };
                                            let is_combo_cell = !combo_list.is_empty()
                                                && combo_list.trim() != "...";

                                            if hit.area
                                                == volvoxgrid_engine::input::HitArea::DropdownButton
                                            {
                                                if !(grid.edit.is_active()
                                                    && grid.edit.edit_row == hit.row
                                                    && grid.edit.edit_col == hit.col)
                                                {
                                                    let _ = self.request_before_edit(
                                                        grid_id, grid, hit.row, hit.col, false,
                                                        true, None,
                                                    );
                                                }
                                            } else if is_cell_like
                                                && ((pe.dbl_click && grid.edit_trigger_mode >= 2)
                                                    || is_combo_cell)
                                            {
                                                let _ = self.request_before_edit(
                                                    grid_id,
                                                    grid,
                                                    hit.row,
                                                    hit.col,
                                                    false,
                                                    is_combo_cell,
                                                    None,
                                                );
                                            }

                                            if hit.area
                                                == volvoxgrid_engine::input::HitArea::FixedRow
                                                && hit.row < grid.fixed_rows
                                                && !is_combo_cell
                                                && grid.header_features > 0
                                            {
                                                self.request_before_sort(grid_id, grid, hit.col);
                                            }
                                        }
                                    }
                                } else {
                                    volvoxgrid_engine::input::handle_pointer_down(
                                        grid,
                                        pe.x,
                                        pe.y,
                                        pe.button,
                                        pe.modifier,
                                        pe.dbl_click,
                                    );
                                }
                            }
                            1 => {
                                // UP
                                volvoxgrid_engine::input::handle_pointer_up(
                                    grid,
                                    pe.x,
                                    pe.y,
                                    pe.button,
                                    pe.modifier,
                                );
                            }
                            2 => {
                                // MOVE
                                volvoxgrid_engine::input::handle_pointer_move(
                                    grid,
                                    pe.x,
                                    pe.y,
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
                            if started_or_changed || prefer_combo {
                                editor_output = maybe_render_editor_output(grid, prefer_combo);
                            }
                        }

                        let next_sel = (
                            grid.selection.row,
                            grid.selection.col,
                            grid.selection.row_end,
                            grid.selection.col_end,
                        );
                        let selection_changed = next_sel != prev_sel;

                        (
                            selection_changed,
                            grid.selection.row,
                            grid.selection.col,
                            grid.selection.row_end,
                            grid.selection.col_end,
                            editor_output,
                        )
                    });
                    if let Ok((selection_changed, row, col, row_end, col_end, editor_output)) =
                        sel_and_editor
                    {
                        if pe.r#type != 2 || selection_changed {
                            stream.send(RenderOutput {
                                rendered: false,
                                event: Some(render_output::Event::Selection(SelectionUpdate {
                                    active_row: row,
                                    active_col: col,
                                    ranges: vec![CellRange {
                                        row1: row.min(row_end),
                                        col1: col.min(col_end),
                                        row2: row.max(row_end),
                                        col2: col.max(col_end),
                                    }],
                                })),
                            });
                        }
                        if let Some(output) = editor_output {
                            stream.send(output);
                        }
                    }
                }

                Some(render_input::Input::Key(ke)) => {
                    let sel_and_editor = self.manager().with_grid(grid_id, |grid| {
                        if !grid.layout.valid {
                            ensure_layout(grid);
                        }
                        let decision_enabled = self.decision_channel_enabled(grid_id);
                        let was_editing = grid.edit.is_active();
                        let prev_edit_row = grid.edit.edit_row;
                        let prev_edit_col = grid.edit.edit_col;
                        match ke.r#type {
                            0 => {
                                // KEY_DOWN
                                if decision_enabled {
                                    volvoxgrid_engine::input::handle_key_down_with_behavior(
                                        grid,
                                        ke.key_code,
                                        ke.modifier,
                                        volvoxgrid_engine::input::InputBehavior {
                                            allow_begin_edit: false,
                                            allow_header_sort: true,
                                        },
                                    );
                                    if (ke.key_code == 13 || ke.key_code == 113)
                                        && !grid.host_key_dispatch
                                        && grid.edit_trigger_mode >= 1
                                        && !was_editing
                                    {
                                        let _ = self.request_before_edit(
                                            grid_id,
                                            grid,
                                            grid.selection.row,
                                            grid.selection.col,
                                            false,
                                            false,
                                            None,
                                        );
                                    }
                                } else {
                                    volvoxgrid_engine::input::handle_key_down(
                                        grid,
                                        ke.key_code,
                                        ke.modifier,
                                    );
                                }
                            }
                            1 => {
                                // KEY_UP
                                grid.events
                                    .push(volvoxgrid_engine::event::GridEventData::KeyUp {
                                        key_code: ke.key_code,
                                        shift: ke.modifier,
                                    });
                            }
                            2 => {
                                // KEY_PRESS
                                if decision_enabled {
                                    volvoxgrid_engine::input::handle_key_press_with_behavior(
                                        grid,
                                        ke.character.chars().next().map(|c| c as u32).unwrap_or(0),
                                        volvoxgrid_engine::input::InputBehavior {
                                            allow_begin_edit: false,
                                            allow_header_sort: true,
                                        },
                                    );
                                    if !was_editing
                                        && !grid.host_key_dispatch
                                        && grid.edit_trigger_mode >= 1
                                        && grid.type_ahead_mode == 0
                                    {
                                        let seed =
                                            ke.character.chars().next().map(|c| c.to_string());
                                        if let Some(seed) = seed {
                                            if !seed.is_empty() {
                                                let _ = self.request_before_edit(
                                                    grid_id,
                                                    grid,
                                                    grid.selection.row,
                                                    grid.selection.col,
                                                    false,
                                                    false,
                                                    Some(seed),
                                                );
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
                            grid.selection.row_end,
                            grid.selection.col_end,
                            editor_output,
                        )
                    });
                    if let Ok((row, col, row_end, col_end, editor_output)) = sel_and_editor {
                        stream.send(RenderOutput {
                            rendered: false,
                            event: Some(render_output::Event::Selection(SelectionUpdate {
                                active_row: row,
                                active_col: col,
                                ranges: vec![CellRange {
                                    row1: row.min(row_end),
                                    col1: col.min(col_end),
                                    row2: row.max(row_end),
                                    col2: col.max(col_end),
                                }],
                            })),
                        });
                        if let Some(output) = editor_output {
                            stream.send(output);
                        }
                    }
                }

                Some(render_input::Input::Scroll(se)) => {
                    let tooltip = self.manager().with_grid(grid_id, |grid| {
                        if !grid.layout.valid {
                            ensure_layout(grid);
                        }
                        volvoxgrid_engine::input::handle_scroll(grid, se.delta_x, se.delta_y);
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
                    stream.send(RenderOutput {
                        rendered: false,
                        event: tooltip
                            .ok()
                            .flatten()
                            .map(render_output::Event::TooltipRequest),
                    });
                }

                Some(render_input::Input::Zoom(ze)) => {
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
                        0 => {
                            // ZOOM_BEGIN
                            let base_zoom_scale = self.current_zoom_scale(grid_id);
                            if let Ok(state) = self.manager().with_grid(grid_id, |grid| {
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
                        1 => {
                            // ZOOM_UPDATE
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
                                if let Ok(state) = self.manager().with_grid(grid_id, |grid| {
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
                        2 => {
                            // ZOOM_END
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
                                let _ = self.manager().with_grid(grid_id, |grid| {
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
                                let _ = self.manager().with_grid(grid_id, |grid| {
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
                        stream.send(output);
                    }
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
        Ok(())
    }

    // ── Streaming: Event Stream ──

    fn event_stream(
        &self,
        request: GridHandle,
        stream: &dyn PluginStreamSender<GridEvent>,
    ) -> Result<(), String> {
        let grid_id = request.id;

        loop {
            let events = self
                .manager()
                .with_grid(grid_id, |grid| grid.events.drain());

            match events {
                Ok(event_list) => {
                    if event_list.is_empty() {
                        std::thread::sleep(std::time::Duration::from_millis(10));
                    }
                    for evt in event_list {
                        let proto_evt = engine_event_to_proto(grid_id, evt.event_id, evt.data);
                        if proto_evt.event.is_some() {
                            if !stream.send(proto_evt) {
                                return Ok(());
                            }
                        }
                    }
                }
                Err(_) => {
                    return Ok(());
                }
            }

            if stream.is_cancelled() {
                return Ok(());
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Plugin registration
// ---------------------------------------------------------------------------

/// Factory for lazy plugin initialization (called by generated FFI dispatcher).
pub(crate) fn create_plugin() -> Box<dyn VolvoxGridServicePlugin + 'static> {
    Box::new(VolvoxGridPlugin::new())
}

#[allow(non_snake_case)]
#[no_mangle]
pub extern "C" fn VolvoxGrid_Init() {
    #[cfg(all(target_os = "windows", target_env = "gnu"))]
    unsafe {
        volvoxgrid_windows_mingw_compat_force_link();
    }
    register_volvox_grid_service_plugin(VolvoxGridPlugin::new());
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
