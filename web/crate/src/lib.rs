use js_sys::Array;
use prost::Message;
use wasm_bindgen::prelude::*;
#[cfg(feature = "gpu")]
use wasm_bindgen_futures::future_to_promise;

use volvoxgrid_engine::input;
use volvoxgrid_engine::render::Renderer;
use volvoxgrid_engine::sort;
use volvoxgrid_engine::GridManager;

use std::collections::{HashMap, HashSet, VecDeque};
use std::sync::{LazyLock, Mutex};
use std::time::Duration;
use web_time::Instant;

// v1 proto types (re-exported for generated WASM bindings)
pub use volvoxgrid_engine::proto::volvoxgrid::v1::*;

// Generated v1 WASM bindings (proto-based batch API)
mod volvoxgrid_wasm;

// ---------------------------------------------------------------------------
// Global singletons
// ---------------------------------------------------------------------------

static MANAGER: Mutex<Option<GridManager>> = Mutex::new(None);
static RENDERER: Mutex<Option<Renderer>> = Mutex::new(None);
static RENDER_BUF: Mutex<Vec<u8>> = Mutex::new(Vec::new());
static RENDER_DIRTY_RECT: Mutex<(i32, i32, i32, i32)> = Mutex::new((0, 0, 0, 0));
static LAST_MEM_CALC_MS: LazyLock<Mutex<HashMap<i64, f64>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));
static NEXT_EVENT_ID: LazyLock<Mutex<i64>> = LazyLock::new(|| Mutex::new(1));
static DECISION_ENABLED: LazyLock<Mutex<HashSet<i64>>> =
    LazyLock::new(|| Mutex::new(HashSet::new()));
static PENDING_ACTIONS: LazyLock<Mutex<HashMap<(i64, i64), PendingActionEntry>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));
static PENDING_DECISION_EVENTS: LazyLock<Mutex<HashMap<i64, VecDeque<PendingDecisionEvent>>>> =
    LazyLock::new(|| Mutex::new(HashMap::new()));

// GPU renderer globals (opt-in via `gpu` feature).
// On wasm32 the wgpu WebGPU backend types contain JsValue which is !Send/!Sync.
// WASM is single-threaded so this is safe — wrap in an unsafe Send/Sync newtype.
#[cfg(feature = "gpu")]
struct GpuCell(Option<volvoxgrid_engine::gpu_render::GpuRenderer>);
#[cfg(feature = "gpu")]
unsafe impl Send for GpuCell {}
#[cfg(feature = "gpu")]
unsafe impl Sync for GpuCell {}

#[cfg(feature = "gpu")]
static GPU_RENDERER: Mutex<GpuCell> = Mutex::new(GpuCell(None));
#[cfg(feature = "gpu")]
static GPU_AVAILABLE: Mutex<bool> = Mutex::new(false);

// Font data cache — replayed into GPU renderer at init time
static LOADED_FONTS: Mutex<Vec<Vec<u8>>> = Mutex::new(Vec::new());

const DEBUG_MEM_SAMPLE_MS: f64 = 10_000.0;
const DECISION_TIMEOUT: Duration = Duration::from_millis(250);

#[derive(Clone, Debug)]
enum PendingAction {
    BeginEdit {
        row: i32,
        col: i32,
        force: bool,
        seed_text: Option<String>,
        select_all: Option<bool>,
        click_caret: Option<i32>,
        caret_end: Option<bool>,
        formula_mode: Option<bool>,
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
struct PendingDecisionEvent {
    event_id: i64,
    data: volvoxgrid_engine::event::GridEventData,
}

fn ensure_manager() {
    let mut m = MANAGER.lock().unwrap();
    if m.is_none() {
        *m = Some(GridManager::new());
    }
}

fn ensure_renderer() {
    let mut r = RENDERER.lock().unwrap();
    if r.is_none() {
        *r = Some(Renderer::new());
    }
}

// ---------------------------------------------------------------------------
// Thin wrappers delegating to engine functions.
// ---------------------------------------------------------------------------

fn ensure_layout(grid: &mut volvoxgrid_engine::grid::VolvoxGrid) {
    grid.ensure_layout();
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

fn maybe_update_debug_memory(
    grid_id: i64,
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    now_ms: f64,
) {
    if !grid.debug_overlay {
        return;
    }

    let mut samples = LAST_MEM_CALC_MS.lock().unwrap();
    let should_update = samples.get(&grid_id).map_or(true, |last_ms| {
        now_ms >= *last_ms && (now_ms - *last_ms) >= DEBUG_MEM_SAMPLE_MS
    });
    if should_update {
        grid.debug_total_mem_bytes = grid.heap_size_bytes() as i64;
        samples.insert(grid_id, now_ms);
    }
}

fn replay_loaded_fonts_into_grid(grid: &mut volvoxgrid_engine::grid::VolvoxGrid) {
    let fonts = LOADED_FONTS.lock().unwrap();
    if fonts.is_empty() {
        return;
    }
    let te = grid.ensure_text_engine();
    for font_data in fonts.iter() {
        te.load_font_data(font_data.clone());
    }
}

const DEFAULT_ROW_INDICATOR_MODE_BITS: u32 =
    RowIndicatorMode::RowIndicatorCurrent as u32 | RowIndicatorMode::RowIndicatorSelection as u32;
const DEFAULT_COL_INDICATOR_MODE_BITS: u32 = ColIndicatorCellMode::ColIndicatorCellHeaderText
    as u32
    | ColIndicatorCellMode::ColIndicatorCellSortGlyph as u32;

fn apply_default_indicator_bands(grid: &mut volvoxgrid_engine::grid::VolvoxGrid) {
    grid.indicator_bands.row_start.visible = false;
    grid.indicator_bands.row_start.width_px =
        volvoxgrid_engine::indicator::DEFAULT_ROW_INDICATOR_WIDTH;
    grid.indicator_bands.row_start.mode_bits = DEFAULT_ROW_INDICATOR_MODE_BITS;

    grid.indicator_bands.col_top.visible = true;
    if grid.indicator_bands.col_top.band_rows <= 0 {
        grid.indicator_bands.col_top.band_rows = 1;
    }
    if grid.indicator_bands.col_top.default_row_height_px <= 0 {
        grid.indicator_bands.col_top.default_row_height_px =
            volvoxgrid_engine::indicator::DEFAULT_COL_INDICATOR_ROW_HEIGHT;
    }
    grid.indicator_bands.col_top.mode_bits = DEFAULT_COL_INDICATOR_MODE_BITS;
    grid.layout.invalidate();
    grid.dirty = true;
}

fn truncate_to_char_count(input: &str, max_chars: i32) -> String {
    if max_chars <= 0 {
        return input.to_string();
    }
    input.chars().take(max_chars as usize).collect()
}

fn next_event_id() -> i64 {
    let mut next = NEXT_EVENT_ID.lock().unwrap();
    let event_id = *next;
    *next += 1;
    event_id
}

fn decision_channel_enabled(grid_id: i64) -> bool {
    DECISION_ENABLED.lock().unwrap().contains(&grid_id)
}

fn set_decision_channel_enabled(grid_id: i64, enabled: bool) {
    let mut channels = DECISION_ENABLED.lock().unwrap();
    if enabled {
        channels.insert(grid_id);
    } else {
        channels.remove(&grid_id);
    }
}

fn clear_grid_decision_state(grid_id: i64) {
    DECISION_ENABLED.lock().unwrap().remove(&grid_id);
    PENDING_ACTIONS
        .lock()
        .unwrap()
        .retain(|(pending_grid, _), _| *pending_grid != grid_id);
    PENDING_DECISION_EVENTS.lock().unwrap().remove(&grid_id);
}

fn queue_pending_decision_event(
    grid_id: i64,
    event_id: i64,
    data: volvoxgrid_engine::event::GridEventData,
) {
    PENDING_DECISION_EVENTS
        .lock()
        .unwrap()
        .entry(grid_id)
        .or_default()
        .push_back(PendingDecisionEvent { event_id, data });
}

fn begin_edit_session_core(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    row: i32,
    col: i32,
    force: bool,
    emit_before_event: bool,
    seed_text: Option<String>,
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
        None,
        None,
        seed_text.as_deref(),
        None,
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
    if let Some(seed) = seed_text {
        if grid.edit.is_active() && grid.edit.edit_row == row && grid.edit.edit_col == col {
            grid.edit.edit_text = seed.clone();
            grid.edit.sel_start = seed.chars().count() as i32;
            grid.edit.sel_length = 0;
            grid.events
                .push(volvoxgrid_engine::event::GridEventData::CellEditChange { text: seed });
        }
    }
    grid.events
        .push(volvoxgrid_engine::event::GridEventData::StartEdit { row, col });
}

fn begin_edit_session_after_before(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    row: i32,
    col: i32,
    force: bool,
    seed_text: Option<String>,
) {
    begin_edit_session_core(grid, row, col, force, false, seed_text);
}

fn apply_edit_start_options(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    row: i32,
    col: i32,
    select_all: Option<bool>,
    click_caret: Option<i32>,
    caret_end: Option<bool>,
    formula_mode: Option<bool>,
) {
    if !grid.edit.is_active() || grid.edit.edit_row != row || grid.edit.edit_col != col {
        return;
    }

    if let Some(formula_mode) = formula_mode {
        grid.edit.set_formula_mode(formula_mode);
    }

    if caret_end == Some(true) || click_caret.is_some() {
        grid.edit.ui_mode = volvoxgrid_engine::edit::EditUiMode::EditMode;
    }

    if let Some(caret) = click_caret {
        grid.edit.sel_start = caret;
        grid.edit.sel_length = 0;
        grid.mark_dirty();
        return;
    }

    if caret_end == Some(true) {
        grid.edit.sel_start = grid.edit.edit_text.chars().count() as i32;
        grid.edit.sel_length = 0;
        grid.mark_dirty();
        return;
    }

    if select_all == Some(true) {
        grid.edit.sel_start = 0;
        grid.edit.sel_length = grid.edit.edit_text.chars().count() as i32;
        grid.mark_dirty();
    }
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

fn request_before_edit(
    grid_id: i64,
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    row: i32,
    col: i32,
    force: bool,
    seed_text: Option<String>,
    select_all: Option<bool>,
    click_caret: Option<i32>,
    caret_end: Option<bool>,
    formula_mode: Option<bool>,
) {
    if !grid.can_begin_edit(row, col, force) {
        return;
    }

    if !decision_channel_enabled(grid_id) {
        begin_edit_session_core(grid, row, col, force, true, seed_text);
        apply_edit_start_options(
            grid,
            row,
            col,
            select_all,
            click_caret,
            caret_end,
            formula_mode,
        );
        return;
    }

    let event_id = next_event_id();
    PENDING_ACTIONS.lock().unwrap().insert(
        (grid_id, event_id),
        PendingActionEntry {
            created_at: Instant::now(),
            action: PendingAction::BeginEdit {
                row,
                col,
                force,
                seed_text: seed_text.clone(),
                select_all,
                click_caret,
                caret_end,
                formula_mode,
            },
        },
    );
    let event = volvoxgrid_engine::event::GridEventData::BeforeEdit { row, col };
    grid.events.push_with_id(event_id, event.clone());
    queue_pending_decision_event(grid_id, event_id, event);
}

fn request_validate_edit(
    grid_id: i64,
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    row: i32,
    col: i32,
    old_text: String,
    new_text: String,
) {
    let committed_text = normalize_committed_edit_text(grid, row, col, &new_text);

    if !decision_channel_enabled(grid_id) {
        grid.events
            .push(volvoxgrid_engine::event::GridEventData::CellEditValidate {
                row,
                col,
                edit_text: committed_text.clone(),
            });
        if grid.edit.is_active() && grid.edit.edit_row == row && grid.edit.edit_col == col {
            grid.edit.cancel();
        }
        apply_committed_edit_text(grid, row, col, old_text, committed_text);
        return;
    }

    let event_id = next_event_id();
    PENDING_ACTIONS.lock().unwrap().insert(
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
    let event = volvoxgrid_engine::event::GridEventData::CellEditValidate {
        row,
        col,
        edit_text: committed_text,
    };
    grid.events.push_with_id(event_id, event.clone());
    queue_pending_decision_event(grid_id, event_id, event);
}

fn request_before_sort(grid_id: i64, grid: &mut volvoxgrid_engine::grid::VolvoxGrid, col: i32) {
    if !decision_channel_enabled(grid_id) {
        grid.events
            .push(volvoxgrid_engine::event::GridEventData::BeforeSort { col });
        apply_before_sort(grid, col);
        return;
    }

    let event_id = next_event_id();
    PENDING_ACTIONS.lock().unwrap().insert(
        (grid_id, event_id),
        PendingActionEntry {
            created_at: Instant::now(),
            action: PendingAction::BeforeSort { col },
        },
    );
    let event = volvoxgrid_engine::event::GridEventData::BeforeSort { col };
    grid.events.push_with_id(event_id, event.clone());
    queue_pending_decision_event(grid_id, event_id, event);
}

fn apply_pending_action(grid_id: i64, action: PendingAction, cancel: bool) {
    let _ = wasm_with_grid(grid_id, |grid| match action {
        PendingAction::BeginEdit {
            row,
            col,
            force,
            seed_text,
            select_all,
            click_caret,
            caret_end,
            formula_mode,
        } => {
            if cancel {
                return;
            }
            begin_edit_session_after_before(grid, row, col, force, seed_text);
            apply_edit_start_options(
                grid,
                row,
                col,
                select_all,
                click_caret,
                caret_end,
                formula_mode,
            );
        }
        PendingAction::ValidateEdit {
            row,
            col,
            old_text,
            committed_text,
        } => {
            if cancel {
                grid.mark_dirty();
                return;
            }
            if grid.edit.is_active() && grid.edit.edit_row == row && grid.edit.edit_col == col {
                grid.edit.cancel();
            }
            apply_committed_edit_text(grid, row, col, old_text, committed_text);
        }
        PendingAction::BeforeSort { col } => {
            if cancel {
                return;
            }
            apply_before_sort(grid, col);
        }
    });
}

fn resolve_event_decision(grid_id: i64, event_id: i64, cancel: bool) {
    if event_id <= 0 {
        return;
    }

    let pending = PENDING_ACTIONS.lock().unwrap().remove(&(grid_id, event_id));
    if let Some(entry) = pending {
        apply_pending_action(grid_id, entry.action, cancel);
    }
}

fn resolve_expired_actions(grid_id: i64) {
    let now = Instant::now();
    let expired: Vec<(i64, PendingAction)> = {
        let mut pending = PENDING_ACTIONS.lock().unwrap();
        let expired_keys: Vec<(i64, i64)> = pending
            .iter()
            .filter_map(|(key, entry)| {
                if key.0 == grid_id && now.duration_since(entry.created_at) >= DECISION_TIMEOUT {
                    Some(*key)
                } else {
                    None
                }
            })
            .collect();
        expired_keys
            .into_iter()
            .filter_map(|key| pending.remove(&key).map(|entry| (key.1, entry.action)))
            .collect()
    };

    for (_event_id, action) in expired {
        apply_pending_action(grid_id, action, false);
    }
}

fn resolve_all_pending_actions(grid_id: i64, cancel: bool) {
    let actions: Vec<PendingAction> = {
        let mut pending = PENDING_ACTIONS.lock().unwrap();
        let keys: Vec<(i64, i64)> = pending
            .keys()
            .copied()
            .filter(|(pending_grid, _)| *pending_grid == grid_id)
            .collect();
        keys.into_iter()
            .filter_map(|key| pending.remove(&key).map(|entry| entry.action))
            .collect()
    };

    for action in actions {
        apply_pending_action(grid_id, action, cancel);
    }
}

fn char_count(input: &str) -> i32 {
    input.chars().count() as i32
}

fn sync_dropdown_index_from_edit_text(grid: &mut volvoxgrid_engine::grid::VolvoxGrid) {
    if !grid.edit.is_active() {
        return;
    }
    if grid.edit.dropdown_count() <= 0 {
        grid.edit.dropdown_index = -1;
        return;
    }
    let mut idx = -1;
    for i in 0..grid.edit.dropdown_count() {
        if grid.edit.get_dropdown_item(i) == grid.edit.edit_text {
            idx = i;
            break;
        }
    }
    grid.edit.dropdown_index = idx;
}

fn active_edit_cell_rect(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
) -> Option<(i32, i32, i32, i32)> {
    ensure_layout(grid);
    if !grid.edit.is_active() {
        return None;
    }
    grid.edit_cell_rect(grid.edit.edit_row, grid.edit.edit_col)
}

fn apply_array_data_to_grid(
    grid: &mut volvoxgrid_engine::grid::VolvoxGrid,
    rows: i32,
    cols: i32,
    values: &Array,
) {
    let rows = rows.max(1);
    let cols = cols.max(1);

    grid.set_rows(rows);
    grid.set_cols(cols);
    grid.cells.clear_all();

    let max = (rows as usize).saturating_mul(cols as usize);
    let total = (values.length() as usize).min(max);
    for idx in 0..total {
        let value = values.get(idx as u32).as_string().unwrap_or_default();
        let idx = idx as i32;
        let row = idx / cols;
        let col = idx % cols;
        grid.cells.set_text(row, col, value);
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

fn capture_grid_picture(grid: &mut volvoxgrid_engine::grid::VolvoxGrid) -> Vec<u8> {
    ensure_layout(grid);
    let width = grid.viewport_width.max(1);
    let height = grid.viewport_height.max(1);
    let stride = width * 4;
    let mut buffer = vec![0u8; (stride * height) as usize];

    ensure_renderer();
    let mut renderer = RENDERER.lock().unwrap();
    if let Some(r) = renderer.as_mut() {
        r.render(grid, &mut buffer, width, height, stride);
    }
    apply_picture_type_to_rgba(&mut buffer, grid.picture_type);
    volvoxgrid_engine::print::encode_rgba_png(&buffer, width as u32, height as u32)
}

// ---------------------------------------------------------------------------
// WASM memory access (for zero-copy buffer reads from JS)
// ---------------------------------------------------------------------------

#[wasm_bindgen]
pub fn wasm_memory() -> JsValue {
    wasm_bindgen::memory()
}

/// Initialize the Rayon thread pool for WebAssembly.
///
/// Requires a cross-origin-isolated page (COOP+COEP) so SharedArrayBuffer
/// is available.  Call this once from JS after the wasm module is loaded.
#[cfg(feature = "wasm-threads")]
#[wasm_bindgen]
pub fn init_wasm_thread_pool(num_threads: usize) -> js_sys::Promise {
    wasm_bindgen_rayon::init_thread_pool(num_threads)
}

/// No-op fallback when `wasm-threads` is not enabled at build time.
#[cfg(not(feature = "wasm-threads"))]
#[wasm_bindgen]
pub fn init_wasm_thread_pool(_num_threads: usize) -> js_sys::Promise {
    js_sys::Promise::resolve(&JsValue::UNDEFINED)
}

// ---------------------------------------------------------------------------
// Font loading (required for WASM — no system fonts available)
// ---------------------------------------------------------------------------

/// Returns `true` when the engine was compiled with the built-in cosmic-text
/// text shaping/rendering engine.  JS can use this to decide whether to
/// register a Canvas2D fallback renderer.
#[wasm_bindgen]
pub fn has_builtin_text_engine() -> bool {
    cfg!(feature = "cosmic-text")
}

/// Load a font (TTF/OTF/TTC bytes) into the renderer's font system.
/// Must be called before the first render if you want text to appear.
#[wasm_bindgen]
pub fn load_font(data: &[u8]) {
    let owned = data.to_vec();

    // CPU renderer
    ensure_renderer();
    let mut renderer = RENDERER.lock().unwrap();
    if let Some(r) = renderer.as_mut() {
        r.load_font_data(owned.clone());
    }
    drop(renderer);

    // Store for later GPU renderer replay
    {
        let mut fonts = LOADED_FONTS.lock().unwrap();
        fonts.push(owned.clone());
    }

    // Feed GPU renderer if already initialised
    #[cfg(feature = "gpu")]
    {
        let mut gr = GPU_RENDERER.lock().unwrap();
        if let Some(gpu) = gr.0.as_mut() {
            gpu.load_font_data(owned.clone());
        }
    }

    // Feed existing grids so print/export paths that use grid-owned text engines
    // can render text with the same loaded fonts.
    ensure_manager();
    let grid_ids = {
        let mgr = MANAGER.lock().unwrap();
        mgr.as_ref().map_or_else(Vec::new, GridManager::grid_ids)
    };
    for id in grid_ids {
        let _ = wasm_with_grid(id, |grid| {
            let te = grid.ensure_text_engine();
            te.load_font_data(owned.clone());
        });
    }
}

// ---------------------------------------------------------------------------
// External text renderer (Full Canvas2D bypass for WASM)
// ---------------------------------------------------------------------------

/// JS callback wrapper implementing TextRenderer.
struct JsTextRenderer {
    measure_callback: js_sys::Function,
    render_callback: js_sys::Function,
}

// SAFETY: WASM is single-threaded — JsValue is not Send but there's no
// concurrent access.
unsafe impl Send for JsTextRenderer {}

impl volvoxgrid_engine::text::TextRenderer for JsTextRenderer {
    fn measure_text(
        &mut self,
        text: &str,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
        max_width: Option<f32>,
    ) -> (f32, f32) {
        let args = Array::new();
        args.push(&JsValue::from(text));
        args.push(&JsValue::from(font_name));
        args.push(&JsValue::from(font_size as f64));
        args.push(&JsValue::from(bold));
        args.push(&JsValue::from(italic));
        if let Some(w) = max_width {
            args.push(&JsValue::from(w as f64));
        } else {
            args.push(&JsValue::NULL);
        }

        let result = self.measure_callback.apply(&JsValue::NULL, &args).ok();
        if let Some(res) = result {
            let w = js_sys::Reflect::get(&res, &"width".into())
                .ok()
                .and_then(|v| v.as_f64())
                .unwrap_or(0.0) as f32;
            let h = js_sys::Reflect::get(&res, &"height".into())
                .ok()
                .and_then(|v| v.as_f64())
                .unwrap_or(0.0) as f32;
            (w, h)
        } else {
            (0.0, font_size * 1.2)
        }
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
        let args = Array::new();
        // We cannot pass a &mut [u8] directly to JS effectively without
        // copying or using a shared buffer.  Since the renderer already has
        // access to the WASM memory, we can pass the pointer and length.
        args.push(&JsValue::from(buffer_pixels.as_ptr() as u32));
        args.push(&JsValue::from(buf_width));
        args.push(&JsValue::from(buf_height));
        args.push(&JsValue::from(stride));
        args.push(&JsValue::from(x));
        args.push(&JsValue::from(y));
        args.push(&JsValue::from(clip_x));
        args.push(&JsValue::from(clip_y));
        args.push(&JsValue::from(clip_w));
        args.push(&JsValue::from(clip_h));
        args.push(&JsValue::from(text));
        args.push(&JsValue::from(font_name));
        args.push(&JsValue::from(font_size as f64));
        args.push(&JsValue::from(bold));
        args.push(&JsValue::from(italic));
        args.push(&JsValue::from(color));
        if let Some(w) = max_width {
            args.push(&JsValue::from(w as f64));
        } else {
            args.push(&JsValue::NULL);
        }

        let result = self.render_callback.apply(&JsValue::NULL, &args).ok();
        result.and_then(|v| v.as_f64()).unwrap_or(0.0) as f32
    }
}

/// Register JS callbacks as the external text renderer.
///
/// measure_callback: (text, fontName, fontSize, bold, italic, maxWidth) -> {width, height}
/// render_callback: (ptr, bufWidth, bufHeight, stride, x, y, clipX, clipY, clipW, clipH, text, fontName, fontSize, bold, italic, color, maxWidth) -> renderedWidth
#[wasm_bindgen]
pub fn set_text_renderer(measure_callback: js_sys::Function, render_callback: js_sys::Function) {
    ensure_renderer();
    let renderer = Box::new(JsTextRenderer {
        measure_callback,
        render_callback,
    });
    let mut r = RENDERER.lock().unwrap();
    if let Some(rend) = r.as_mut() {
        rend.set_custom_text_renderer(Some(renderer));
    }
}

/// Register JS callbacks as the external text renderer for a specific grid.
/// This is used for measurement (auto-size) when the built-in engine is disabled.
#[wasm_bindgen]
pub fn set_grid_text_renderer(
    id: i32,
    measure_callback: js_sys::Function,
    render_callback: js_sys::Function,
) {
    let _ = with_grid(id, |grid| {
        let te = grid.ensure_text_engine();
        let renderer = Box::new(JsTextRenderer {
            measure_callback,
            render_callback,
        });
        te.set_external_renderer(Some(renderer));
    });
}

// ---------------------------------------------------------------------------
// External glyph rasterizer (Canvas2D fallback for WASM)
// ---------------------------------------------------------------------------

/// JS callback wrapper implementing ExternalGlyphRasterizer.
struct JsGlyphRasterizer {
    callback: js_sys::Function,
}

// SAFETY: WASM is single-threaded — JsValue is not Send but there's no
// concurrent access.
unsafe impl Send for JsGlyphRasterizer {}

impl volvoxgrid_engine::glyph_rasterizer::ExternalGlyphRasterizer for JsGlyphRasterizer {
    fn rasterize_glyph(
        &mut self,
        character: char,
        font_name: &str,
        font_size: f32,
        bold: bool,
        italic: bool,
    ) -> Option<volvoxgrid_engine::glyph_rasterizer::GlyphBitmap> {
        let args = Array::new();
        args.push(&JsValue::from(String::from(character)));
        args.push(&JsValue::from(font_name));
        args.push(&JsValue::from(font_size as f64));
        args.push(&JsValue::from(bold));
        args.push(&JsValue::from(italic));

        let result = self.callback.apply(&JsValue::NULL, &args).ok()?;
        if result.is_null() || result.is_undefined() {
            return None;
        }

        let width = js_sys::Reflect::get(&result, &"width".into())
            .ok()?
            .as_f64()? as u32;
        let height = js_sys::Reflect::get(&result, &"height".into())
            .ok()?
            .as_f64()? as u32;
        let offset_x = js_sys::Reflect::get(&result, &"offsetX".into())
            .ok()?
            .as_f64()? as i32;
        let offset_y = js_sys::Reflect::get(&result, &"offsetY".into())
            .ok()?
            .as_f64()? as i32;
        let data_val = js_sys::Reflect::get(&result, &"data".into()).ok()?;
        let data_array = js_sys::Uint8Array::new(&data_val);
        let alpha_data = data_array.to_vec();

        let advance_width = js_sys::Reflect::get(&result, &"advanceWidth".into())
            .ok()
            .and_then(|v| v.as_f64())
            .map(|v| v as f32);

        Some(volvoxgrid_engine::glyph_rasterizer::GlyphBitmap {
            width,
            height,
            offset_x,
            offset_y,
            alpha_data,
            advance_width,
        })
    }
}

/// Register a JS callback as the external glyph rasterizer.
/// The callback receives `(char, fontName, fontSize, bold, italic)` and should
/// return `{width, height, offsetX, offsetY, data: Uint8Array}` or `null`.
///
/// This is used as a fallback when SwashCache cannot produce a glyph (e.g.
/// the font is not loaded into the engine but is available to the browser).
/// Sets the rasterizer on the CPU renderer unconditionally, and on the GPU
/// renderer when the `gpu` feature is enabled.
#[wasm_bindgen]
pub fn set_glyph_rasterizer(callback: js_sys::Function) {
    // CPU renderer (always)
    {
        ensure_renderer();
        let rasterizer = Box::new(JsGlyphRasterizer {
            callback: callback.clone(),
        });
        let mut renderer = RENDERER.lock().unwrap();
        if let Some(r) = renderer.as_mut() {
            r.set_external_glyph_rasterizer(rasterizer);
        }
    }
    // GPU renderer (when feature enabled)
    #[cfg(feature = "gpu")]
    {
        let rasterizer = Box::new(JsGlyphRasterizer { callback });
        let mut gr = GPU_RENDERER.lock().unwrap();
        if let Some(gpu) = gr.0.as_mut() {
            gpu.set_external_glyph_rasterizer(rasterizer);
        }
    }
}

// ---------------------------------------------------------------------------
// Grid lifecycle
// ---------------------------------------------------------------------------

/// Create a new grid with the given initial row/column counts.
/// Returns a unique grid ID (i32 for JS compatibility — no BigInt needed).
#[wasm_bindgen]
pub fn create_grid(rows: i32, cols: i32) -> i32 {
    create_grid_scaled(rows, cols, 1.0)
}

/// Create a new grid with an explicit host scale factor (e.g. devicePixelRatio).
#[wasm_bindgen]
pub fn create_grid_scaled(rows: i32, cols: i32, scale: f32) -> i32 {
    ensure_manager();
    let mgr = MANAGER.lock().unwrap();
    let mgr = mgr.as_ref().unwrap();
    let safe_scale = if scale.is_finite() && scale > 0.01 {
        scale
    } else {
        1.0
    };
    let id = mgr.create_grid(0, 0, rows, cols, 0, 0, safe_scale);
    let _ = mgr.with_grid(id, apply_default_indicator_bands);
    let _ = mgr.with_grid(id, replay_loaded_fonts_into_grid);
    id as i32
}

/// Update the engine-side DPI scale factor for an existing grid.
#[wasm_bindgen]
pub fn set_grid_scale(id: i32, scale: f32) {
    let safe_scale = if scale.is_finite() && scale > 0.01 {
        scale
    } else {
        1.0
    };
    with_grid(id, |grid| {
        grid.scale = safe_scale;
        grid.mark_dirty();
    });
}

/// Destroy a grid, freeing its resources.
#[wasm_bindgen]
pub fn destroy_grid(id: i32) {
    let mgr = MANAGER.lock().unwrap();
    if let Some(mgr) = mgr.as_ref() {
        mgr.destroy_grid(id as i64);
    }
    LAST_MEM_CALC_MS.lock().unwrap().remove(&(id as i64));
    clear_grid_decision_state(id as i64);
}

#[wasm_bindgen]
pub fn set_event_decision_enabled(id: i32, enabled: bool) {
    let grid_id = id as i64;
    if enabled {
        set_decision_channel_enabled(grid_id, true);
        return;
    }

    resolve_all_pending_actions(grid_id, false);
    set_decision_channel_enabled(grid_id, false);
    PENDING_DECISION_EVENTS.lock().unwrap().remove(&grid_id);
}

#[wasm_bindgen]
pub fn resolve_expired_event_decisions(id: i32) {
    resolve_expired_actions(id as i64);
}

#[wasm_bindgen]
pub fn take_pending_decision_event(id: i32) -> Vec<u8> {
    let grid_id = id as i64;
    resolve_expired_actions(grid_id);

    loop {
        let next = {
            let mut queues = PENDING_DECISION_EVENTS.lock().unwrap();
            let maybe_event = queues.get_mut(&grid_id).and_then(|queue| queue.pop_front());
            if queues
                .get(&grid_id)
                .map(|queue| queue.is_empty())
                .unwrap_or(false)
            {
                queues.remove(&grid_id);
            }
            maybe_event
        };

        let Some(event) = next else {
            return Vec::new();
        };

        if !PENDING_ACTIONS
            .lock()
            .unwrap()
            .contains_key(&(grid_id, event.event_id))
        {
            continue;
        }

        return engine_event_to_proto(grid_id, event.event_id, event.data).encode_to_vec();
    }
}

#[wasm_bindgen]
pub fn send_event_decision(id: i32, event_id: i64, cancel: bool) {
    resolve_event_decision(id as i64, event_id, cancel);
}

// ---------------------------------------------------------------------------
// Dimensions
// ---------------------------------------------------------------------------

#[wasm_bindgen]
pub fn set_rows(id: i32, n: i32) {
    with_grid(id, |grid| {
        grid.set_rows(n);
    });
}

#[wasm_bindgen]
pub fn set_cols(id: i32, n: i32) {
    with_grid(id, |grid| {
        grid.set_cols(n);
    });
}

#[wasm_bindgen]
pub fn get_rows(id: i32) -> i32 {
    with_grid(id, |grid| grid.rows).unwrap_or(0)
}

#[wasm_bindgen]
pub fn get_cols(id: i32) -> i32 {
    with_grid(id, |grid| grid.cols).unwrap_or(0)
}

#[wasm_bindgen]
pub fn set_fixed_rows(id: i32, n: i32) {
    with_grid(id, |grid| {
        grid.fixed_rows = n.max(0).min(grid.rows);
        grid.selection
            .clamp(grid.rows, grid.cols, grid.fixed_rows, grid.fixed_cols);
        grid.layout.invalidate();
        grid.dirty = true;
    });
}

#[wasm_bindgen]
pub fn set_fixed_cols(id: i32, n: i32) {
    with_grid(id, |grid| {
        grid.fixed_cols = n.max(0).min(grid.cols);
        grid.selection
            .clamp(grid.rows, grid.cols, grid.fixed_rows, grid.fixed_cols);
        grid.layout.invalidate();
        grid.dirty = true;
    });
}

#[wasm_bindgen]
pub fn get_fixed_rows(id: i32) -> i32 {
    with_grid(id, |grid| grid.fixed_rows).unwrap_or(0)
}

#[wasm_bindgen]
pub fn get_fixed_cols(id: i32) -> i32 {
    with_grid(id, |grid| grid.fixed_cols).unwrap_or(0)
}

#[wasm_bindgen]
pub fn set_frozen_rows(id: i32, n: i32) {
    with_grid(id, |grid| {
        grid.frozen_rows = n.max(0).min((grid.rows - grid.fixed_rows).max(0));
        grid.layout.invalidate();
        grid.dirty = true;
    });
}

#[wasm_bindgen]
pub fn set_frozen_cols(id: i32, n: i32) {
    with_grid(id, |grid| {
        grid.frozen_cols = n.max(0).min((grid.cols - grid.fixed_cols).max(0));
        grid.layout.invalidate();
        grid.dirty = true;
    });
}

#[wasm_bindgen]
pub fn get_frozen_rows(id: i32) -> i32 {
    with_grid(id, |grid| grid.frozen_rows).unwrap_or(0)
}

#[wasm_bindgen]
pub fn get_frozen_cols(id: i32) -> i32 {
    with_grid(id, |grid| grid.frozen_cols).unwrap_or(0)
}

#[wasm_bindgen]
pub fn set_show_column_headers(id: i32, visible: bool) {
    with_grid(id, |grid| {
        grid.indicator_bands.col_top.visible = visible;
        if visible {
            if grid.indicator_bands.col_top.band_rows <= 0 {
                grid.indicator_bands.col_top.band_rows = 1;
            }
            if grid.indicator_bands.col_top.mode_bits == 0 {
                grid.indicator_bands.col_top.mode_bits = DEFAULT_COL_INDICATOR_MODE_BITS;
            }
        }
        grid.layout.invalidate();
        grid.dirty = true;
    });
}

#[wasm_bindgen]
pub fn get_show_column_headers(id: i32) -> bool {
    with_grid(id, |grid| grid.indicator_bands.col_top.visible).unwrap_or(false)
}

#[wasm_bindgen]
pub fn set_col_indicator_top_mode_bits(id: i32, mode_bits: u32) {
    with_grid(id, |grid| {
        grid.indicator_bands.col_top.mode_bits = mode_bits;
        grid.indicator_bands.col_top.visible = mode_bits != 0;
        if grid.indicator_bands.col_top.visible && grid.indicator_bands.col_top.band_rows <= 0 {
            grid.indicator_bands.col_top.band_rows = 1;
        }
        grid.layout.invalidate();
        grid.dirty = true;
    });
}

#[wasm_bindgen]
pub fn get_col_indicator_top_mode_bits(id: i32) -> u32 {
    with_grid(id, |grid| grid.indicator_bands.col_top.mode_bits).unwrap_or(0)
}

#[wasm_bindgen]
pub fn set_col_indicator_top_band_rows(id: i32, band_rows: i32) {
    with_grid(id, |grid| {
        let normalized = band_rows.max(0);
        grid.indicator_bands.col_top.band_rows = normalized;
        grid.indicator_bands.col_top.visible = normalized != 0;
        grid.layout.invalidate();
        grid.dirty = true;
    });
}

#[wasm_bindgen]
pub fn get_col_indicator_top_band_rows(id: i32) -> i32 {
    with_grid(id, |grid| grid.indicator_bands.col_top.band_rows).unwrap_or(0)
}

#[wasm_bindgen]
pub fn set_col_indicator_top_default_row_height(id: i32, height_px: i32) {
    with_grid(id, |grid| {
        grid.indicator_bands.col_top.default_row_height_px = height_px.max(1);
        grid.layout.invalidate();
        grid.dirty = true;
    });
}

#[wasm_bindgen]
pub fn get_col_indicator_top_default_row_height(id: i32) -> i32 {
    with_grid(id, |grid| {
        grid.indicator_bands.col_top.default_row_height_px.max(1)
    })
    .unwrap_or(volvoxgrid_engine::indicator::DEFAULT_COL_INDICATOR_ROW_HEIGHT)
}

#[wasm_bindgen]
pub fn set_show_row_indicator(id: i32, visible: bool) {
    with_grid(id, |grid| {
        grid.indicator_bands.row_start.visible = visible;
        if visible {
            if grid.indicator_bands.row_start.width_px <= 0 {
                grid.indicator_bands.row_start.width_px =
                    volvoxgrid_engine::indicator::DEFAULT_ROW_INDICATOR_WIDTH;
            }
            if grid.indicator_bands.row_start.mode_bits == 0 {
                grid.indicator_bands.row_start.mode_bits = DEFAULT_ROW_INDICATOR_MODE_BITS;
            }
        }
        grid.layout.invalidate();
        grid.dirty = true;
    });
}

#[wasm_bindgen]
pub fn get_show_row_indicator(id: i32) -> bool {
    with_grid(id, |grid| grid.indicator_bands.row_start.visible).unwrap_or(false)
}

#[wasm_bindgen]
pub fn set_row_indicator_start_mode_bits(id: i32, mode_bits: u32) {
    with_grid(id, |grid| {
        grid.indicator_bands.row_start.mode_bits = mode_bits;
        grid.indicator_bands.row_start.visible = mode_bits != 0;
        grid.layout.invalidate();
        grid.dirty = true;
    });
}

#[wasm_bindgen]
pub fn get_row_indicator_start_mode_bits(id: i32) -> u32 {
    with_grid(id, |grid| grid.indicator_bands.row_start.mode_bits).unwrap_or(0)
}

#[wasm_bindgen]
pub fn set_row_indicator_start_width(id: i32, width_px: i32) {
    with_grid(id, |grid| {
        grid.indicator_bands.row_start.width_px = width_px.max(1);
        grid.layout.invalidate();
        grid.dirty = true;
    });
}

#[wasm_bindgen]
pub fn get_row_indicator_start_width(id: i32) -> i32 {
    with_grid(id, |grid| grid.indicator_bands.row_start.width_px)
        .unwrap_or(volvoxgrid_engine::indicator::DEFAULT_ROW_INDICATOR_WIDTH)
}

#[wasm_bindgen]
pub fn get_visible_row_start(id: i32) -> i32 {
    with_grid(id, |grid| grid.top_row()).unwrap_or(0)
}

#[wasm_bindgen]
pub fn get_visible_row_end(id: i32) -> i32 {
    with_grid(id, |grid| grid.bottom_row()).unwrap_or(-1)
}

#[wasm_bindgen]
pub fn set_top_row(id: i32, row: i32) {
    with_grid(id, |grid| {
        grid.set_top_row(row);
    });
}

#[wasm_bindgen]
pub fn get_top_row(id: i32) -> i32 {
    with_grid(id, |grid| grid.top_row()).unwrap_or(0)
}

#[wasm_bindgen]
pub fn set_left_col(id: i32, col: i32) {
    with_grid(id, |grid| {
        grid.set_left_col(col);
    });
}

#[wasm_bindgen]
pub fn get_left_col(id: i32) -> i32 {
    with_grid(id, |grid| grid.left_col()).unwrap_or(0)
}

#[wasm_bindgen]
pub fn get_bottom_row(id: i32) -> i32 {
    with_grid(id, |grid| grid.bottom_row()).unwrap_or(-1)
}

#[wasm_bindgen]
pub fn get_right_col(id: i32) -> i32 {
    with_grid(id, |grid| grid.right_col()).unwrap_or(-1)
}

#[wasm_bindgen]
pub fn get_row_pos(id: i32, row: i32) -> i32 {
    with_grid(id, |grid| {
        ensure_layout(grid);
        grid.row_pos(row)
    })
    .unwrap_or(0)
}

#[wasm_bindgen]
pub fn get_col_pos(id: i32, col: i32) -> i32 {
    with_grid(id, |grid| {
        ensure_layout(grid);
        grid.col_pos(col)
    })
    .unwrap_or(0)
}

#[wasm_bindgen]
pub fn has_cell(id: i32, row: i32, col: i32) -> i32 {
    with_grid(id, |grid| {
        if row < 0 || row >= grid.rows || col < 0 || col >= grid.cols {
            0
        } else if grid.cells.contains(row, col) {
            1
        } else {
            0
        }
    })
    .unwrap_or(0)
}

#[wasm_bindgen]
pub fn clear_cell_range(id: i32, row1: i32, col1: i32, row2: i32, col2: i32) {
    with_grid(id, |grid| {
        if grid.rows <= 0 || grid.cols <= 0 {
            return;
        }
        let r_lo = row1.min(row2).clamp(0, grid.rows - 1);
        let r_hi = row1.max(row2).clamp(0, grid.rows - 1);
        let c_lo = col1.min(col2).clamp(0, grid.cols - 1);
        let c_hi = col1.max(col2).clamp(0, grid.cols - 1);
        if r_lo > r_hi || c_lo > c_hi {
            return;
        }
        grid.cells.clear_range(r_lo, c_lo, r_hi, c_hi);
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn set_fling_enabled(id: i32, enabled: i32) {
    with_grid(id, |grid| {
        grid.fling_enabled = enabled != 0;
        if !grid.fling_enabled {
            grid.scroll.stop_fling();
        }
    });
}

#[wasm_bindgen]
pub fn get_fling_enabled(id: i32) -> i32 {
    with_grid(id, |grid| if grid.fling_enabled { 1 } else { 0 }).unwrap_or(0)
}

#[wasm_bindgen]
pub fn set_fling_impulse_gain(id: i32, gain: f32) {
    with_grid(id, |grid| {
        if gain.is_finite() {
            grid.fling_impulse_gain = gain.max(0.0);
        }
    });
}

#[wasm_bindgen]
pub fn set_fling_friction(id: i32, friction: f32) {
    with_grid(id, |grid| {
        if friction.is_finite() {
            grid.fling_friction = friction.max(0.1);
        }
    });
}

#[wasm_bindgen]
pub fn tick_fling(id: i32, dt_ms: f32) -> i32 {
    with_grid(id, |grid| {
        ensure_layout(grid);
        if !grid.fling_enabled {
            return 0;
        }
        let dt_sec = (dt_ms / 1000.0).max(0.0);
        if grid.scroll.tick_fling(dt_sec, grid.fling_friction) {
            grid.mark_dirty_visual();
            1
        } else {
            0
        }
    })
    .unwrap_or(0)
}

#[wasm_bindgen]
pub fn tick_scrollbar_fade(id: i32, dt_ms: f32) -> i32 {
    with_grid(id, |grid| {
        let dt_sec = (dt_ms / 1000.0).max(0.0);
        if grid.tick_scrollbar_fade(dt_sec) {
            1
        } else {
            0
        }
    })
    .unwrap_or(0)
}

// ---------------------------------------------------------------------------
// Editing / Combo
// ---------------------------------------------------------------------------

/// When enabled, the engine skips pointer-driven selection changes and edit
/// triggers.  The host adapter drives those via Select / Edit RPC while
/// engine-rendered UI (resize, scrollbar, fast-scroll) stays engine-handled.
#[wasm_bindgen]
pub fn set_host_pointer_dispatch(id: i32, enabled: i32) {
    with_grid(id, |grid| {
        grid.host_pointer_dispatch = enabled != 0;
    });
}

#[wasm_bindgen]
pub fn get_host_pointer_dispatch(id: i32) -> i32 {
    with_grid(id, |grid| if grid.host_pointer_dispatch { 1 } else { 0 }).unwrap_or(0)
}

#[wasm_bindgen]
pub fn set_edit_trigger(id: i32, mode: i32) {
    with_grid(id, |grid| {
        grid.edit_trigger_mode = mode.clamp(0, 2);
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn get_edit_trigger(id: i32) -> i32 {
    with_grid(id, |grid| grid.edit_trigger_mode).unwrap_or(0)
}

#[wasm_bindgen]
pub fn set_editable_mode(id: i32, mode: i32) {
    set_edit_trigger(id, mode);
}

#[wasm_bindgen]
pub fn get_editable_mode(id: i32) -> i32 {
    get_edit_trigger(id)
}

#[wasm_bindgen]
pub fn set_tab_behavior(id: i32, mode: i32) {
    with_grid(id, |grid| {
        grid.tab_behavior = mode.clamp(0, 1);
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn set_dropdown_trigger(id: i32, mode: i32) {
    with_grid(id, |grid| {
        grid.dropdown_trigger = mode.clamp(0, 2);
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn set_host_dropdown_overlay(id: i32, enabled: i32) {
    with_grid(id, |grid| {
        grid.host_dropdown_overlay = enabled != 0;
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn set_dropdown_search(id: i32, enabled: i32) {
    with_grid(id, |grid| {
        grid.dropdown_search = enabled != 0;
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn set_show_combo_button(id: i32, mode: i32) {
    set_dropdown_trigger(id, mode);
}

#[wasm_bindgen]
pub fn set_host_combo_overlay(id: i32, enabled: i32) {
    set_host_dropdown_overlay(id, enabled);
}

#[wasm_bindgen]
pub fn set_combo_search(id: i32, enabled: i32) {
    set_dropdown_search(id, enabled);
}

#[wasm_bindgen]
pub fn set_edit_max_length(id: i32, max_chars: i32) {
    with_grid(id, |grid| {
        grid.edit_max_length = max_chars.max(0);
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn get_edit_max_length(id: i32) -> i32 {
    with_grid(id, |grid| grid.edit_max_length).unwrap_or(0)
}

#[wasm_bindgen]
pub fn set_row_data(id: i32, row: i32, data: &[u8]) {
    with_grid(id, |grid| {
        if row < 0 || row >= grid.rows {
            return;
        }
        if data.is_empty() {
            grid.set_row_data(row, None);
        } else {
            grid.set_row_data(row, Some(data.to_vec()));
        }
    });
}

#[wasm_bindgen]
pub fn get_row_data(id: i32, row: i32) -> Vec<u8> {
    with_grid(id, |grid| {
        if row < 0 || row >= grid.rows {
            return Vec::new();
        }
        grid.get_row_data(row).unwrap_or_default()
    })
    .unwrap_or_default()
}

#[wasm_bindgen]
pub fn set_row_status(id: i32, row: i32, status: i32) {
    with_grid(id, |grid| {
        if row < 0 || row >= grid.rows {
            return;
        }
        grid.set_row_status(row, status);
    });
}

#[wasm_bindgen]
pub fn get_row_status(id: i32, row: i32) -> i32 {
    with_grid(id, |grid| {
        if row < 0 || row >= grid.rows {
            return 0;
        }
        grid.get_row_status(row)
    })
    .unwrap_or(0)
}

// ---------------------------------------------------------------------------
// Pin & Sticky
// ---------------------------------------------------------------------------

#[wasm_bindgen]
pub fn pin_row(id: i32, row: i32, pin: i32) {
    with_grid(id, |grid| {
        grid.pin_row(row, pin);
    });
}

#[wasm_bindgen]
pub fn is_row_pinned(id: i32, row: i32) -> i32 {
    with_grid(id, |grid| grid.is_row_pinned(row)).unwrap_or(0)
}

#[wasm_bindgen]
pub fn pin_col(id: i32, col: i32, pin: i32) {
    with_grid(id, |grid| {
        grid.pin_col(col, pin);
    });
}

#[wasm_bindgen]
pub fn is_col_pinned(id: i32, col: i32) -> i32 {
    with_grid(id, |grid| grid.is_col_pinned(col)).unwrap_or(0)
}

#[wasm_bindgen]
pub fn set_row_sticky(id: i32, row: i32, edge: i32) {
    with_grid(id, |grid| {
        grid.set_row_sticky(row, edge);
    });
}

#[wasm_bindgen]
pub fn set_col_sticky(id: i32, col: i32, edge: i32) {
    with_grid(id, |grid| {
        grid.set_col_sticky(col, edge);
    });
}

#[wasm_bindgen]
pub fn set_cell_sticky(id: i32, row: i32, col: i32, sticky_row: i32, sticky_col: i32) {
    with_grid(id, |grid| {
        grid.set_cell_sticky(row, col, sticky_row, sticky_col);
    });
}

#[wasm_bindgen]
pub fn get_row_sticky(id: i32, row: i32) -> i32 {
    with_grid(id, |grid| grid.sticky_rows.get(&row).copied().unwrap_or(0)).unwrap_or(0)
}

#[wasm_bindgen]
pub fn get_col_sticky(id: i32, col: i32) -> i32 {
    with_grid(id, |grid| {
        if col >= 0 && (col as usize) < grid.columns.len() {
            grid.columns[col as usize].sticky
        } else {
            0
        }
    })
    .unwrap_or(0)
}

#[wasm_bindgen]
pub fn copy_selection(id: i32) -> String {
    with_grid(id, |grid| {
        let (text, _rich_data) = volvoxgrid_engine::clipboard::copy(grid);
        text
    })
    .unwrap_or_default()
}

#[wasm_bindgen]
pub fn get_mouse_row(id: i32) -> i32 {
    with_grid(id, |grid| grid.mouse_row).unwrap_or(-1)
}

#[wasm_bindgen]
pub fn get_mouse_col(id: i32) -> i32 {
    with_grid(id, |grid| grid.mouse_col).unwrap_or(-1)
}

#[wasm_bindgen]
pub fn set_data_source_mode(id: i32, mode: i32) {
    with_grid(id, |grid| {
        grid.data_source_mode = mode.max(0);
    });
}

#[wasm_bindgen]
pub fn get_data_source_mode(id: i32) -> i32 {
    with_grid(id, |grid| grid.data_source_mode).unwrap_or(0)
}

#[wasm_bindgen]
pub fn set_data_mode(id: i32, mode: i32) {
    set_data_source_mode(id, mode);
}

#[wasm_bindgen]
pub fn get_data_mode(id: i32) -> i32 {
    get_data_source_mode(id)
}

#[wasm_bindgen]
pub fn set_virtual_mode(id: i32, enabled: i32) {
    with_grid(id, |grid| {
        grid.virtual_mode = enabled != 0;
    });
}

#[wasm_bindgen]
pub fn get_virtual_mode(id: i32) -> i32 {
    with_grid(id, |grid| if grid.virtual_mode { 1 } else { 0 }).unwrap_or(0)
}

#[wasm_bindgen]
pub fn set_virtual_data(id: i32, enabled: i32) {
    set_virtual_mode(id, enabled);
}

#[wasm_bindgen]
pub fn get_virtual_data(id: i32) -> i32 {
    get_virtual_mode(id)
}

#[wasm_bindgen]
pub fn set_picture_type(id: i32, picture_type: i32) {
    with_grid(id, |grid| {
        grid.picture_type = picture_type.clamp(0, 2);
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn get_picture_type(id: i32) -> i32 {
    with_grid(id, |grid| grid.picture_type).unwrap_or(0)
}

#[wasm_bindgen]
pub fn get_picture(id: i32) -> Vec<u8> {
    with_grid(id, |grid| capture_grid_picture(grid)).unwrap_or_default()
}

#[wasm_bindgen]
pub fn set_sort_ascending_picture(id: i32, data: &[u8]) {
    with_grid(id, |grid| {
        grid.sort_state.sort_ascending_picture = if data.is_empty() {
            None
        } else {
            Some(data.to_vec())
        };
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn get_sort_ascending_picture(id: i32) -> Vec<u8> {
    with_grid(id, |grid| {
        grid.sort_state
            .sort_ascending_picture
            .clone()
            .unwrap_or_default()
    })
    .unwrap_or_default()
}

#[wasm_bindgen]
pub fn set_sort_descending_picture(id: i32, data: &[u8]) {
    with_grid(id, |grid| {
        grid.sort_state.sort_descending_picture = if data.is_empty() {
            None
        } else {
            Some(data.to_vec())
        };
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn get_sort_descending_picture(id: i32) -> Vec<u8> {
    with_grid(id, |grid| {
        grid.sort_state
            .sort_descending_picture
            .clone()
            .unwrap_or_default()
    })
    .unwrap_or_default()
}

#[wasm_bindgen]
pub fn set_node_open_picture(id: i32, data: &[u8]) {
    with_grid(id, |grid| {
        grid.outline.node_open_picture = if data.is_empty() {
            None
        } else {
            Some(data.to_vec())
        };
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn get_node_open_picture(id: i32) -> Vec<u8> {
    with_grid(id, |grid| {
        grid.outline.node_open_picture.clone().unwrap_or_default()
    })
    .unwrap_or_default()
}

#[wasm_bindgen]
pub fn set_node_closed_picture(id: i32, data: &[u8]) {
    with_grid(id, |grid| {
        grid.outline.node_closed_picture = if data.is_empty() {
            None
        } else {
            Some(data.to_vec())
        };
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn get_node_closed_picture(id: i32) -> Vec<u8> {
    with_grid(id, |grid| {
        grid.outline.node_closed_picture.clone().unwrap_or_default()
    })
    .unwrap_or_default()
}

#[wasm_bindgen]
pub fn set_checkbox_checked_picture(id: i32, data: &[u8]) {
    with_grid(id, |grid| {
        grid.style.checkbox_checked_picture = if data.is_empty() {
            None
        } else {
            Some(data.to_vec())
        };
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn get_checkbox_checked_picture(id: i32) -> Vec<u8> {
    with_grid(id, |grid| {
        grid.style
            .checkbox_checked_picture
            .clone()
            .unwrap_or_default()
    })
    .unwrap_or_default()
}

#[wasm_bindgen]
pub fn set_checkbox_unchecked_picture(id: i32, data: &[u8]) {
    with_grid(id, |grid| {
        grid.style.checkbox_unchecked_picture = if data.is_empty() {
            None
        } else {
            Some(data.to_vec())
        };
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn get_checkbox_unchecked_picture(id: i32) -> Vec<u8> {
    with_grid(id, |grid| {
        grid.style
            .checkbox_unchecked_picture
            .clone()
            .unwrap_or_default()
    })
    .unwrap_or_default()
}

#[wasm_bindgen]
pub fn set_checkbox_indeterminate_picture(id: i32, data: &[u8]) {
    with_grid(id, |grid| {
        grid.style.checkbox_indeterminate_picture = if data.is_empty() {
            None
        } else {
            Some(data.to_vec())
        };
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn get_checkbox_indeterminate_picture(id: i32) -> Vec<u8> {
    with_grid(id, |grid| {
        grid.style
            .checkbox_indeterminate_picture
            .clone()
            .unwrap_or_default()
    })
    .unwrap_or_default()
}

fn icon_slot_mut(
    slots: &mut volvoxgrid_engine::style::IconSlots,
    slot: i32,
) -> Option<&mut Option<String>> {
    match slot {
        1 => Some(&mut slots.sort_ascending),
        2 => Some(&mut slots.sort_descending),
        3 => Some(&mut slots.sort_none),
        4 => Some(&mut slots.tree_expanded),
        5 => Some(&mut slots.tree_collapsed),
        6 => Some(&mut slots.menu),
        7 => Some(&mut slots.filter),
        8 => Some(&mut slots.filter_active),
        9 => Some(&mut slots.columns),
        10 => Some(&mut slots.drag_handle),
        11 => Some(&mut slots.checkbox_checked),
        12 => Some(&mut slots.checkbox_unchecked),
        13 => Some(&mut slots.checkbox_indeterminate),
        _ => None,
    }
}

fn icon_slot_ref(
    slots: &volvoxgrid_engine::style::IconSlots,
    slot: i32,
) -> Option<&Option<String>> {
    match slot {
        1 => Some(&slots.sort_ascending),
        2 => Some(&slots.sort_descending),
        3 => Some(&slots.sort_none),
        4 => Some(&slots.tree_expanded),
        5 => Some(&slots.tree_collapsed),
        6 => Some(&slots.menu),
        7 => Some(&slots.filter),
        8 => Some(&slots.filter_active),
        9 => Some(&slots.columns),
        10 => Some(&slots.drag_handle),
        11 => Some(&slots.checkbox_checked),
        12 => Some(&slots.checkbox_unchecked),
        13 => Some(&slots.checkbox_indeterminate),
        _ => None,
    }
}

fn icon_slot_style_mut(
    slots: &mut volvoxgrid_engine::style::IconSlotStyles,
    slot: i32,
) -> Option<&mut Option<volvoxgrid_engine::style::IconSlotStyle>> {
    match slot {
        1 => Some(&mut slots.sort_ascending),
        2 => Some(&mut slots.sort_descending),
        3 => Some(&mut slots.sort_none),
        4 => Some(&mut slots.tree_expanded),
        5 => Some(&mut slots.tree_collapsed),
        6 => Some(&mut slots.menu),
        7 => Some(&mut slots.filter),
        8 => Some(&mut slots.filter_active),
        9 => Some(&mut slots.columns),
        10 => Some(&mut slots.drag_handle),
        11 => Some(&mut slots.checkbox_checked),
        12 => Some(&mut slots.checkbox_unchecked),
        13 => Some(&mut slots.checkbox_indeterminate),
        _ => None,
    }
}

fn normalize_icon_align(value: i32) -> i32 {
    use volvoxgrid_engine::proto::volvoxgrid::v1::IconAlign;
    match value {
        v if v == IconAlign::InlineEnd as i32 => v,
        v if v == IconAlign::InlineStart as i32 => v,
        v if v == IconAlign::Start as i32 => v,
        v if v == IconAlign::End as i32 => v,
        v if v == IconAlign::Center as i32 => v,
        _ => IconAlign::InlineEnd as i32,
    }
}

fn sanitize_font_names(values: &Array) -> Vec<String> {
    let mut out = Vec::new();
    for i in 0..values.length() {
        if let Some(raw) = values.get(i).as_string() {
            let trimmed = raw.trim();
            if !trimmed.is_empty() {
                out.push(trimmed.to_string());
            }
        }
    }
    out
}

#[wasm_bindgen]
pub fn set_icon_theme_slot(id: i32, slot: i32, icon: &str) {
    with_grid(id, |grid| {
        let Some(target) = icon_slot_mut(&mut grid.style.icon_theme_slots, slot) else {
            return;
        };
        let next = icon.trim();
        if next.is_empty() {
            *target = None;
        } else {
            *target = Some(next.to_string());
        }
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn get_icon_theme_slot(id: i32, slot: i32) -> String {
    with_grid(id, |grid| {
        icon_slot_ref(&grid.style.icon_theme_slots, slot)
            .and_then(|v| v.as_ref())
            .cloned()
            .unwrap_or_default()
    })
    .unwrap_or_default()
}

#[wasm_bindgen]
pub fn patch_icon_theme_default_text_style(
    id: i32,
    font_name: Option<String>,
    font_size: Option<f32>,
    font_bold: Option<bool>,
    font_italic: Option<bool>,
    color: Option<u32>,
) {
    with_grid(id, |grid| {
        if let Some(v) = font_name {
            let trimmed = v.trim();
            if trimmed.is_empty() {
                grid.style.icon_theme_defaults.text_style.font_name = None;
                grid.style.icon_theme_defaults.text_style.font_names.clear();
            } else {
                grid.style.icon_theme_defaults.text_style.font_name = Some(trimmed.to_string());
                grid.style.icon_theme_defaults.text_style.font_names.clear();
            }
        }
        if let Some(v) = font_size {
            grid.style.icon_theme_defaults.text_style.font_size = if v.is_finite() && v > 0.0 {
                Some(v.clamp(1.0, 256.0))
            } else {
                None
            };
        }
        if let Some(v) = font_bold {
            grid.style.icon_theme_defaults.text_style.font_bold = Some(v);
        }
        if let Some(v) = font_italic {
            grid.style.icon_theme_defaults.text_style.font_italic = Some(v);
        }
        if let Some(v) = color {
            grid.style.icon_theme_defaults.text_style.color = Some(v);
        }
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn patch_icon_theme_default_font_names(id: i32, font_names: Option<Array>) {
    with_grid(id, |grid| {
        let Some(font_names) = font_names else {
            return;
        };
        let next = sanitize_font_names(&font_names);
        grid.style.icon_theme_defaults.text_style.font_name = next.first().cloned();
        grid.style.icon_theme_defaults.text_style.font_names = next;
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn patch_icon_theme_default_layout(id: i32, align: Option<i32>, gap_px: Option<i32>) {
    with_grid(id, |grid| {
        if let Some(v) = align {
            grid.style.icon_theme_defaults.layout.align = normalize_icon_align(v);
        }
        if let Some(v) = gap_px {
            grid.style.icon_theme_defaults.layout.gap_px = v.max(0);
        }
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn patch_icon_theme_slot_text_style(
    id: i32,
    slot: i32,
    font_name: Option<String>,
    font_size: Option<f32>,
    font_bold: Option<bool>,
    font_italic: Option<bool>,
    color: Option<u32>,
) {
    with_grid(id, |grid| {
        let Some(slot_entry) = icon_slot_style_mut(&mut grid.style.icon_theme_slot_styles, slot)
        else {
            return;
        };
        let slot_style =
            slot_entry.get_or_insert_with(volvoxgrid_engine::style::IconSlotStyle::default);
        if let Some(v) = font_name {
            let trimmed = v.trim();
            if trimmed.is_empty() {
                slot_style.text_style.font_name = None;
                slot_style.text_style.font_names.clear();
            } else {
                slot_style.text_style.font_name = Some(trimmed.to_string());
                slot_style.text_style.font_names.clear();
            }
        }
        if let Some(v) = font_size {
            slot_style.text_style.font_size = if v.is_finite() && v > 0.0 {
                Some(v.clamp(1.0, 256.0))
            } else {
                None
            };
        }
        if let Some(v) = font_bold {
            slot_style.text_style.font_bold = Some(v);
        }
        if let Some(v) = font_italic {
            slot_style.text_style.font_italic = Some(v);
        }
        if let Some(v) = color {
            slot_style.text_style.color = Some(v);
        }
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn patch_icon_theme_slot_font_names(id: i32, slot: i32, font_names: Option<Array>) {
    with_grid(id, |grid| {
        let Some(slot_entry) = icon_slot_style_mut(&mut grid.style.icon_theme_slot_styles, slot)
        else {
            return;
        };
        let Some(font_names) = font_names else {
            return;
        };
        let slot_style =
            slot_entry.get_or_insert_with(volvoxgrid_engine::style::IconSlotStyle::default);
        let next = sanitize_font_names(&font_names);
        slot_style.text_style.font_name = next.first().cloned();
        slot_style.text_style.font_names = next;
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn patch_icon_theme_slot_layout(id: i32, slot: i32, align: Option<i32>, gap_px: Option<i32>) {
    with_grid(id, |grid| {
        let Some(slot_entry) = icon_slot_style_mut(&mut grid.style.icon_theme_slot_styles, slot)
        else {
            return;
        };
        let slot_style =
            slot_entry.get_or_insert_with(volvoxgrid_engine::style::IconSlotStyle::default);
        let mut layout = slot_style
            .layout
            .unwrap_or(grid.style.icon_theme_defaults.layout);
        if let Some(v) = align {
            layout.align = normalize_icon_align(v);
        }
        if let Some(v) = gap_px {
            layout.gap_px = v.max(0);
        }
        slot_style.layout = Some(layout);
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn set_col_dropdown_items(id: i32, col: i32, list: &str) {
    with_grid(id, |grid| {
        if col < 0 || col >= grid.cols {
            return;
        }
        if let Some(props) = grid.columns.get_mut(col as usize) {
            props.dropdown_items = list.to_string();
            grid.mark_dirty();
        }
    });
}

#[wasm_bindgen]
pub fn set_col_combo_list(id: i32, col: i32, list: &str) {
    set_col_dropdown_items(id, col, list);
}

#[wasm_bindgen]
pub fn set_cell_dropdown_items(id: i32, row: i32, col: i32, list: &str) {
    with_grid(id, |grid| {
        if row < 0 || row >= grid.rows || col < 0 || col >= grid.cols {
            return;
        }
        grid.cells.get_mut(row, col).extra_mut().dropdown_items = list.to_string();
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn set_cell_combo_list(id: i32, row: i32, col: i32, list: &str) {
    set_cell_dropdown_items(id, row, col, list);
}

#[wasm_bindgen]
pub fn get_active_dropdown_list(id: i32, row: i32, col: i32) -> String {
    with_grid(id, |grid| grid.active_dropdown_list(row, col)).unwrap_or_default()
}

#[wasm_bindgen]
pub fn get_active_combo_list(id: i32, row: i32, col: i32) -> String {
    get_active_dropdown_list(id, row, col)
}

#[wasm_bindgen]
pub fn begin_edit_cell(id: i32, row: i32, col: i32) {
    let grid_id = id as i64;
    resolve_expired_actions(grid_id);
    with_grid(id, |grid| {
        ensure_layout(grid);
        request_before_edit(grid_id, grid, row, col, false, None, None, None, None, None);
    });
}

#[wasm_bindgen]
pub fn begin_edit_cell_at_click(id: i32, row: i32, col: i32, x_in_cell: f32) {
    let grid_id = id as i64;
    resolve_expired_actions(grid_id);
    with_grid(id, |grid| {
        ensure_layout(grid);
        let click_caret = grid.caret_index_from_display_click(row, col, x_in_cell);
        request_before_edit(
            grid_id,
            grid,
            row,
            col,
            false,
            None,
            None,
            Some(click_caret),
            Some(true),
            None,
        );
    });
}

#[wasm_bindgen]
pub fn begin_edit_at_selection(id: i32) {
    let grid_id = id as i64;
    resolve_expired_actions(grid_id);
    with_grid(id, |grid| {
        ensure_layout(grid);
        let row = grid.selection.row;
        let col = grid.selection.col;
        request_before_edit(grid_id, grid, row, col, false, None, None, None, None, None);
    });
}

#[wasm_bindgen]
pub fn is_editing(id: i32) -> i32 {
    with_grid(id, |grid| if grid.edit.is_active() { 1 } else { 0 }).unwrap_or(0)
}

#[wasm_bindgen]
pub fn get_edit_row(id: i32) -> i32 {
    with_grid(id, |grid| {
        if grid.edit.is_active() {
            grid.edit.edit_row
        } else {
            -1
        }
    })
    .unwrap_or(-1)
}

#[wasm_bindgen]
pub fn get_edit_col(id: i32) -> i32 {
    with_grid(id, |grid| {
        if grid.edit.is_active() {
            grid.edit.edit_col
        } else {
            -1
        }
    })
    .unwrap_or(-1)
}

#[wasm_bindgen]
pub fn get_edit_text(id: i32) -> String {
    with_grid(id, |grid| {
        if grid.edit.is_active() {
            grid.edit.edit_text.clone()
        } else {
            String::new()
        }
    })
    .unwrap_or_default()
}

#[wasm_bindgen]
pub fn get_edit_ui_mode(id: i32) -> i32 {
    with_grid(id, |grid| {
        if !grid.edit.is_active() {
            return 0;
        }
        match grid.edit.ui_mode {
            volvoxgrid_engine::edit::EditUiMode::EnterMode => 0,
            volvoxgrid_engine::edit::EditUiMode::EditMode => 1,
        }
    })
    .unwrap_or(0)
}

#[wasm_bindgen]
pub fn set_edit_ui_mode(id: i32, mode: i32) {
    with_grid(id, |grid| {
        if !grid.edit.is_active() {
            return;
        }
        grid.edit.ui_mode = if mode == 1 {
            volvoxgrid_engine::edit::EditUiMode::EditMode
        } else {
            volvoxgrid_engine::edit::EditUiMode::EnterMode
        };
    });
}

#[wasm_bindgen]
pub fn set_edit_text(id: i32, text: &str) {
    with_grid(id, |grid| {
        if !grid.edit.is_active() {
            return;
        }
        let next = truncate_to_char_count(text, grid.edit_max_length);
        if next == grid.edit.edit_text {
            return;
        }
        grid.edit.edit_text = next.clone();
        grid.edit.sel_start = char_count(&next);
        grid.edit.sel_length = 0;
        sync_dropdown_index_from_edit_text(grid);
        grid.events
            .push(volvoxgrid_engine::event::GridEventData::CellEditChange { text: next });
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn get_edit_sel_start(id: i32) -> i32 {
    with_grid(id, |grid| {
        if grid.edit.is_active() {
            grid.edit.sel_start
        } else {
            0
        }
    })
    .unwrap_or(0)
}

#[wasm_bindgen]
pub fn get_edit_sel_length(id: i32) -> i32 {
    with_grid(id, |grid| {
        if grid.edit.is_active() {
            grid.edit.sel_length
        } else {
            0
        }
    })
    .unwrap_or(0)
}

#[wasm_bindgen]
pub fn set_edit_selection(id: i32, sel_start: i32, sel_length: i32) {
    with_grid(id, |grid| {
        if !grid.edit.is_active() {
            return;
        }
        let total = char_count(&grid.edit.edit_text);
        let start = sel_start.clamp(0, total);
        let len = sel_length.clamp(0, total - start);
        grid.edit.sel_start = start;
        grid.edit.sel_length = len;
    });
}

#[wasm_bindgen]
pub fn get_edit_dropdown_count(id: i32) -> i32 {
    with_grid(id, |grid| {
        if grid.edit.is_active() {
            grid.edit.dropdown_count()
        } else {
            0
        }
    })
    .unwrap_or(0)
}

#[wasm_bindgen]
pub fn get_edit_combo_count(id: i32) -> i32 {
    get_edit_dropdown_count(id)
}

#[wasm_bindgen]
pub fn get_edit_dropdown_item(id: i32, idx: i32) -> String {
    with_grid(id, |grid| {
        if !grid.edit.is_active() {
            return String::new();
        }
        grid.edit.get_dropdown_item(idx).to_string()
    })
    .unwrap_or_default()
}

#[wasm_bindgen]
pub fn get_edit_combo_item(id: i32, idx: i32) -> String {
    get_edit_dropdown_item(id, idx)
}

#[wasm_bindgen]
pub fn is_edit_dropdown_editable(id: i32) -> i32 {
    with_grid(id, |grid| {
        if grid.edit.is_active() && grid.edit.dropdown_editable {
            1
        } else {
            0
        }
    })
    .unwrap_or(0)
}

#[wasm_bindgen]
pub fn is_edit_combo_editable(id: i32) -> i32 {
    is_edit_dropdown_editable(id)
}

#[wasm_bindgen]
pub fn get_edit_dropdown_index(id: i32) -> i32 {
    with_grid(id, |grid| {
        if grid.edit.is_active() {
            grid.edit.dropdown_index
        } else {
            -1
        }
    })
    .unwrap_or(-1)
}

#[wasm_bindgen]
pub fn get_edit_combo_index(id: i32) -> i32 {
    get_edit_dropdown_index(id)
}

#[wasm_bindgen]
pub fn set_edit_dropdown_index(id: i32, idx: i32) {
    with_grid(id, |grid| {
        if !grid.edit.is_active() || grid.edit.dropdown_count() <= 0 {
            return;
        }
        grid.edit.set_dropdown_index(idx);
        let text = grid.edit.edit_text.clone();
        grid.edit.sel_start = char_count(&text);
        grid.edit.sel_length = 0;
        grid.events
            .push(volvoxgrid_engine::event::GridEventData::CellEditChange { text });
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn set_edit_combo_index(id: i32, idx: i32) {
    set_edit_dropdown_index(id, idx);
}

#[wasm_bindgen]
pub fn dropdown_hit_index(id: i32, x: f32, y: f32) -> i32 {
    with_grid(id, |grid| {
        ensure_layout(grid);
        grid.dropdown_hit_index(x, y).unwrap_or(-1)
    })
    .unwrap_or(-1)
}

#[wasm_bindgen]
pub fn combo_dropdown_hit_index(id: i32, x: f32, y: f32) -> i32 {
    dropdown_hit_index(id, x, y)
}

#[wasm_bindgen]
pub fn choose_dropdown_item(id: i32, idx: i32) {
    let grid_id = id as i64;
    resolve_expired_actions(grid_id);
    with_grid(id, |grid| {
        if !grid.edit.is_active() {
            return;
        }
        if idx < 0 || idx >= grid.edit.dropdown_count() {
            return;
        }
        grid.edit.set_dropdown_index(idx);
        let text = grid.edit.edit_text.clone();
        grid.events
            .push(volvoxgrid_engine::event::GridEventData::CellEditChange { text });
        if decision_channel_enabled(grid_id) {
            let row = grid.edit.edit_row;
            let col = grid.edit.edit_col;
            let old_text = grid.cells.get_text(row, col).to_string();
            let new_text = grid.edit.edit_text.clone();
            request_validate_edit(grid_id, grid, row, col, old_text, new_text);
        } else {
            grid.commit_edit();
        }
    });
}

#[wasm_bindgen]
pub fn choose_combo_dropdown_item(id: i32, idx: i32) {
    choose_dropdown_item(id, idx);
}

#[wasm_bindgen]
pub fn commit_edit(id: i32) {
    let grid_id = id as i64;
    resolve_expired_actions(grid_id);
    with_grid(id, |grid| {
        if decision_channel_enabled(grid_id) && grid.edit.is_active() {
            grid.edit.flush_preedit();
            let row = grid.edit.edit_row;
            let col = grid.edit.edit_col;
            let old_text = grid.cells.get_text(row, col).to_string();
            let new_text = grid.edit.edit_text.clone();
            request_validate_edit(grid_id, grid, row, col, old_text, new_text);
        } else {
            grid.commit_edit();
        }
    });
}

#[wasm_bindgen]
pub fn cancel_edit(id: i32) {
    with_grid(id, |grid| {
        grid.cancel_edit();
    });
}

#[wasm_bindgen]
pub fn set_edit_preedit(id: i32, text: &str, cursor: i32) {
    with_grid(id, |grid| {
        if !grid.edit.is_active() {
            return;
        }
        if text.is_empty() {
            grid.edit.cancel_preedit();
        } else {
            grid.edit.set_preedit(text, cursor);
        }
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn commit_edit_preedit(id: i32, text: &str) {
    with_grid(id, |grid| {
        if !grid.edit.is_active() {
            return;
        }
        grid.edit.commit_preedit(text);
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn is_edit_composing(id: i32) -> i32 {
    with_grid(id, |grid| {
        if grid.edit.is_active() && grid.edit.composing {
            1
        } else {
            0
        }
    })
    .unwrap_or(0)
}

#[wasm_bindgen]
pub fn get_edit_cell_x(id: i32) -> i32 {
    with_grid(id, |grid| {
        active_edit_cell_rect(grid).map(|v| v.0).unwrap_or(-1)
    })
    .unwrap_or(-1)
}

#[wasm_bindgen]
pub fn get_edit_cell_y(id: i32) -> i32 {
    with_grid(id, |grid| {
        active_edit_cell_rect(grid).map(|v| v.1).unwrap_or(-1)
    })
    .unwrap_or(-1)
}

#[wasm_bindgen]
pub fn get_edit_cell_w(id: i32) -> i32 {
    with_grid(id, |grid| {
        active_edit_cell_rect(grid).map(|v| v.2).unwrap_or(0)
    })
    .unwrap_or(0)
}

#[wasm_bindgen]
pub fn get_edit_cell_h(id: i32) -> i32 {
    with_grid(id, |grid| {
        active_edit_cell_rect(grid).map(|v| v.3).unwrap_or(0)
    })
    .unwrap_or(0)
}

#[wasm_bindgen]
pub fn get_edit_font_size(id: i32) -> f32 {
    with_grid(id, |grid| {
        if !grid.edit.is_active() {
            return 0.0;
        }
        let row = grid.edit.edit_row;
        let col = grid.edit.edit_col;
        let style_override = grid.get_cell_style(row, col);
        style_override.font_size.unwrap_or(grid.style.font_size)
    })
    .unwrap_or(0.0)
}

#[wasm_bindgen]
pub fn get_edit_font_name(id: i32) -> String {
    with_grid(id, |grid| {
        if !grid.edit.is_active() {
            return String::new();
        }
        let row = grid.edit.edit_row;
        let col = grid.edit.edit_col;
        let style_override = grid.get_cell_style(row, col);
        style_override
            .font_name
            .clone()
            .unwrap_or_else(|| grid.style.font_name.clone())
    })
    .unwrap_or_default()
}

#[wasm_bindgen]
pub fn get_edit_font_bold(id: i32) -> i32 {
    with_grid(id, |grid| {
        if !grid.edit.is_active() {
            return 0;
        }
        let row = grid.edit.edit_row;
        let col = grid.edit.edit_col;
        let style_override = grid.get_cell_style(row, col);
        if style_override.font_bold.unwrap_or(grid.style.font_bold) {
            1
        } else {
            0
        }
    })
    .unwrap_or(0)
}

#[wasm_bindgen]
pub fn get_edit_font_italic(id: i32) -> i32 {
    with_grid(id, |grid| {
        if !grid.edit.is_active() {
            return 0;
        }
        let row = grid.edit.edit_row;
        let col = grid.edit.edit_col;
        let style_override = grid.get_cell_style(row, col);
        if style_override.font_italic.unwrap_or(grid.style.font_italic) {
            1
        } else {
            0
        }
    })
    .unwrap_or(0)
}

#[wasm_bindgen]
pub fn get_edit_cell_padding(id: i32) -> Vec<i32> {
    with_grid(id, |grid| {
        if !grid.edit.is_active() {
            return vec![0, 0, 0, 0];
        }
        let row = grid.edit.edit_row;
        let col = grid.edit.edit_col;
        let style_override = grid.get_cell_style(row, col);
        let p = grid.resolve_cell_padding(row, col, &style_override);
        vec![p.left, p.top, p.right, p.bottom]
    })
    .unwrap_or_else(|| vec![0, 0, 0, 0])
}

/// Screen-space rect (x, y, w, h) for any cell, accounting for scroll offset.
#[wasm_bindgen]
pub fn get_cell_screen_x(id: i32, row: i32, col: i32) -> i32 {
    with_grid(id, |grid| {
        ensure_layout(grid);
        grid.cell_screen_rect(row, col).map(|v| v.0).unwrap_or(-1)
    })
    .unwrap_or(-1)
}

#[wasm_bindgen]
pub fn get_cell_screen_y(id: i32, row: i32, col: i32) -> i32 {
    with_grid(id, |grid| {
        ensure_layout(grid);
        grid.cell_screen_rect(row, col).map(|v| v.1).unwrap_or(-1)
    })
    .unwrap_or(-1)
}

#[wasm_bindgen]
pub fn get_cell_screen_w(id: i32, row: i32, col: i32) -> i32 {
    with_grid(id, |grid| {
        ensure_layout(grid);
        grid.cell_screen_rect(row, col).map(|v| v.2).unwrap_or(0)
    })
    .unwrap_or(0)
}

#[wasm_bindgen]
pub fn get_cell_screen_h(id: i32, row: i32, col: i32) -> i32 {
    with_grid(id, |grid| {
        ensure_layout(grid);
        grid.cell_screen_rect(row, col).map(|v| v.3).unwrap_or(0)
    })
    .unwrap_or(0)
}

/// Hit-test: convert canvas pixel (x, y) to grid-space (row, col).
#[wasm_bindgen]
pub fn hit_test_row(id: i32, x: f32, y: f32) -> i32 {
    with_grid(id, |grid| {
        ensure_layout(grid);
        volvoxgrid_engine::input::hit_test(grid, x, y).row
    })
    .unwrap_or(-1)
}

#[wasm_bindgen]
pub fn hit_test_col(id: i32, x: f32, y: f32) -> i32 {
    with_grid(id, |grid| {
        ensure_layout(grid);
        volvoxgrid_engine::input::hit_test(grid, x, y).col
    })
    .unwrap_or(-1)
}

// ---------------------------------------------------------------------------
// Cell text
// ---------------------------------------------------------------------------

#[wasm_bindgen]
pub fn set_text_matrix(id: i32, row: i32, col: i32, text: &str) {
    with_grid(id, |grid| {
        grid.cells.set_text(row, col, text.to_string());
        grid.dirty = true;
    });
}

#[wasm_bindgen]
pub fn get_text_matrix(id: i32, row: i32, col: i32) -> String {
    with_grid(id, |grid| grid.cells.get_text(row, col).to_string()).unwrap_or_default()
}

#[wasm_bindgen]
pub fn set_text_array(id: i32, index: i32, text: &str) {
    with_grid(id, |grid| {
        grid.set_text_array(index, text.to_string());
    });
}

#[wasm_bindgen]
pub fn get_text_array(id: i32, index: i32) -> String {
    with_grid(id, |grid| grid.get_text_array(index)).unwrap_or_default()
}

#[wasm_bindgen]
pub fn load_array(id: i32, rows: i32, cols: i32, values: Array) {
    with_grid(id, |grid| {
        apply_array_data_to_grid(grid, rows, cols, &values);
        grid.data_source_mode = 0;
        grid.virtual_mode = false;
    });
}

#[wasm_bindgen]
pub fn bind_to_array(id: i32, rows: i32, cols: i32, values: Array) {
    with_grid(id, |grid| {
        apply_array_data_to_grid(grid, rows, cols, &values);
        grid.data_source_mode = 1;
        grid.virtual_mode = false;
    });
}

#[wasm_bindgen]
pub fn set_cell_progress(id: i32, row: i32, col: i32, percent: f32, color: u32) {
    with_grid(id, |grid| {
        let extra = grid.cells.get_mut(row, col).extra_mut();
        extra.progress_percent = percent;
        extra.progress_color = color;
        grid.dirty = true;
    });
}

#[wasm_bindgen]
pub fn set_cell_flood(id: i32, row: i32, col: i32, percent: f32, color: u32) {
    set_cell_progress(id, row, col, percent, color);
}

// ---------------------------------------------------------------------------
// Column widths / row heights
// ---------------------------------------------------------------------------

#[wasm_bindgen]
pub fn set_col_width(id: i32, col: i32, w: i32) {
    with_grid(id, |grid| {
        grid.set_col_width(col, w);
    });
}

#[wasm_bindgen]
pub fn set_col_caption(id: i32, col: i32, caption: &str) {
    with_grid(id, |grid| {
        if col < 0 || col >= grid.cols {
            return;
        }
        while grid.columns.len() <= col as usize {
            grid.columns.push(Default::default());
        }
        grid.columns[col as usize].caption = caption.to_string();
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn get_col_width(id: i32, col: i32) -> i32 {
    with_grid(id, |grid| grid.get_col_width(col)).unwrap_or(0)
}

#[wasm_bindgen]
pub fn set_default_col_width(id: i32, w: i32) {
    with_grid(id, |grid| {
        let next = w.max(1);
        if grid.default_col_width != next {
            grid.default_col_width = next;
            grid.layout.invalidate();
            grid.mark_dirty();
        }
    });
}

#[wasm_bindgen]
pub fn get_default_col_width(id: i32) -> i32 {
    with_grid(id, |grid| grid.default_col_width).unwrap_or(0)
}

#[wasm_bindgen]
pub fn scale_col_width_overrides(id: i32, scale: f32) {
    if !scale.is_finite() || scale <= 0.0 {
        return;
    }
    with_grid(id, |grid| {
        if grid.col_widths.is_empty() {
            return;
        }
        let entries: Vec<(i32, i32)> = grid.col_widths.iter().map(|(c, w)| (*c, *w)).collect();
        let mut changed = false;
        for (col, width) in entries {
            let scaled = ((width as f32) * scale).round() as i32;
            let next = grid.clamp_col_width(col, scaled.max(1));
            if grid.col_widths.get(&col).copied().unwrap_or(i32::MIN) != next {
                grid.col_widths.insert(col, next);
                changed = true;
            }
        }
        if changed {
            grid.layout.invalidate();
            grid.mark_dirty();
        }
    });
}

#[wasm_bindgen]
pub fn scale_row_height_overrides(id: i32, scale: f32) {
    if !scale.is_finite() || scale <= 0.0 {
        return;
    }
    with_grid(id, |grid| {
        if grid.row_heights.is_empty() {
            return;
        }
        let entries: Vec<(i32, i32)> = grid.row_heights.iter().map(|(r, h)| (*r, *h)).collect();
        let mut changed = false;
        for (row, height) in entries {
            let scaled = ((height as f32) * scale).round() as i32;
            let mut next = scaled.max(1);
            if grid.row_height_min > 0 && next < grid.row_height_min {
                next = grid.row_height_min;
            }
            if grid.row_height_max > 0 && next > grid.row_height_max {
                next = grid.row_height_max;
            }
            if grid.row_heights.get(&row).copied().unwrap_or(i32::MIN) != next {
                grid.row_heights.insert(row, next);
                changed = true;
            }
        }
        if changed {
            grid.layout.invalidate();
            grid.mark_dirty();
        }
    });
}

#[wasm_bindgen]
pub fn set_row_height(id: i32, row: i32, h: i32) {
    with_grid(id, |grid| {
        grid.set_row_height(row, h);
    });
}

#[wasm_bindgen]
pub fn get_row_height(id: i32, row: i32) -> i32 {
    with_grid(id, |grid| grid.get_row_height(row)).unwrap_or(0)
}

#[wasm_bindgen]
pub fn set_default_row_height(id: i32, h: i32) {
    with_grid(id, |grid| {
        let mut next = h.max(1);
        if grid.row_height_min > 0 && next < grid.row_height_min {
            next = grid.row_height_min;
        }
        if grid.row_height_max > 0 && next > grid.row_height_max {
            next = grid.row_height_max;
        }
        if grid.default_row_height != next {
            grid.default_row_height = next;
            grid.layout.invalidate();
            grid.mark_dirty();
        }
    });
}

#[wasm_bindgen]
pub fn get_default_row_height(id: i32) -> i32 {
    with_grid(id, |grid| grid.default_row_height).unwrap_or(0)
}

// ---------------------------------------------------------------------------
// Selection & appearance
// ---------------------------------------------------------------------------

/// Set the selection mode: 0=free, 1=by_row, 2=by_col, 3=listbox
#[wasm_bindgen]
pub fn set_selection_mode(id: i32, mode: i32) {
    with_grid(id, |grid| {
        grid.selection.mode = mode;
        grid.dirty = true;
    });
}

/// Set the highlight style: 0=never, 1=always, 2=with_focus
#[wasm_bindgen]
pub fn set_selection_visibility(id: i32, hl: i32) {
    with_grid(id, |grid| {
        grid.selection.selection_visibility = hl;
        grid.dirty = true;
    });
}

#[wasm_bindgen]
pub fn set_highlight(id: i32, hl: i32) {
    set_selection_visibility(id, hl);
}

/// Set the focus rect style: 0=none, 1=light, 2=heavy, 3=inset, 4=raised
#[wasm_bindgen]
pub fn set_focus_border(id: i32, fr: i32) {
    with_grid(id, |grid| {
        grid.selection.focus_border = fr;
        grid.dirty = true;
    });
}

#[wasm_bindgen]
pub fn set_focus_rect(id: i32, fr: i32) {
    set_focus_border(id, fr);
}

#[wasm_bindgen]
pub fn set_font_name(id: i32, name: &str) {
    with_grid(id, |grid| {
        let trimmed = name.trim();
        if trimmed.is_empty() {
            return;
        }
        grid.style.font_name = trimmed.to_string();
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn set_font_size(id: i32, size: f32) {
    with_grid(id, |grid| {
        if !size.is_finite() {
            return;
        }
        // Keep a wide range so DPI-driven render-scale changes can preserve
        // visual CSS size across low/high internal resolutions.
        grid.style.font_size = size.clamp(1.0, 256.0);
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn get_font_size(id: i32) -> f32 {
    with_grid(id, |grid| grid.style.font_size).unwrap_or(0.0)
}

/// Set the span mode: 0=never, 1=free, 2=restrict_rows, 3=restrict_cols,
/// 4=restrict_all, 5=fixed_only, 6=spill, 7=outline
#[wasm_bindgen]
pub fn set_span_mode(id: i32, mode: i32) {
    with_grid(id, |grid| {
        grid.span.mode = mode;
        // Keep fixed-zone_span behavior in sync with the legacy single-value API.
        // Without this, CELL_SPAN_HEADER_ONLY only updates non-fixed mode and
        // grouped headers (fixed rows) never span.
        grid.span.mode_fixed = mode;
        // Enable all rows and cols for spanning
        grid.span.span_rows.insert(-1, true);
        grid.span.span_cols.insert(-1, true);
        grid.layout.invalidate();
        grid.dirty = true;
    });
}

/// Add an explicit merge range. Explicit merges take priority over
/// content-based spans in `get_merged_range`.
#[wasm_bindgen]
pub fn merge_cells(id: i32, r1: i32, c1: i32, r2: i32, c2: i32) {
    with_grid(id, |grid| {
        grid.merged_regions.add_merge(r1, c1, r2, c2);
        grid.layout.invalidate();
        grid.dirty = true;
    });
}

/// Remove all explicit merges that overlap the given range.
#[wasm_bindgen]
pub fn unmerge_cells(id: i32, r1: i32, c1: i32, r2: i32, c2: i32) {
    with_grid(id, |grid| {
        grid.merged_regions.remove_overlapping(r1, c1, r2, c2);
        grid.layout.invalidate();
        grid.dirty = true;
    });
}

/// Return all explicit merge regions as a flat array [r1,c1,r2,c2, ...].
#[wasm_bindgen]
pub fn get_merged_regions(id: i32) -> Vec<i32> {
    with_grid(id, |grid| {
        grid.merged_regions
            .all_ranges()
            .iter()
            .flat_map(|&(r1, c1, r2, c2)| [r1, c1, r2, c2])
            .collect()
    })
    .unwrap_or_default()
}

/// Set the explorer bar mode for sort-glyph headers: 0=none, 1=sort,
/// 2=move, 3=sort+move
#[wasm_bindgen]
pub fn set_header_features(id: i32, mode: i32) {
    with_grid(id, |grid| {
        grid.header_features = mode;
        grid.dirty = true;
    });
}

#[wasm_bindgen]
pub fn set_explorer_bar(id: i32, mode: i32) {
    set_header_features(id, mode);
}

/// Set legacy grid line mode:
/// 0=none, 1=solid both, 2=inset both, 3=raised both,
/// 4=solid horizontal, 5=solid vertical,
/// 6=inset horizontal, 7=inset vertical,
/// 8=raised horizontal, 9=raised vertical.
#[wasm_bindgen]
pub fn set_grid_lines(id: i32, mode: i32) {
    with_grid(id, |grid| {
        grid.style.grid_lines = mode;
        grid.style.grid_lines_fixed = mode;
        grid.dirty = true;
    });
}

fn header_mark_height_from_mode(
    mode: i32,
    value: f32,
) -> volvoxgrid_engine::style::HeaderMarkHeight {
    if mode == 1 {
        let px = if value.is_finite() {
            value.round() as i32
        } else {
            1
        };
        volvoxgrid_engine::style::HeaderMarkHeight::Px(px.max(1))
    } else {
        let ratio = if value.is_finite() {
            value.clamp(0.0, 1.0)
        } else {
            0.5
        };
        volvoxgrid_engine::style::HeaderMarkHeight::Ratio(ratio)
    }
}

/// Set header separator style.
/// `height_mode`: 0=ratio, 1=px
#[wasm_bindgen]
pub fn set_header_separator_style(
    id: i32,
    enabled: i32,
    color: u32,
    width_px: i32,
    height_mode: i32,
    height_value: f32,
    skip_merged: i32,
) {
    with_grid(id, |grid| {
        grid.style.header_separator.enabled = enabled != 0;
        grid.style.header_separator.color = color;
        grid.style.header_separator.width_px = width_px.max(1);
        grid.style.header_separator.height =
            header_mark_height_from_mode(height_mode, height_value);
        grid.style.header_separator.skip_merged = skip_merged != 0;
        grid.mark_dirty();
    });
}

/// Set header resize handle style.
/// `height_mode`: 0=ratio, 1=px
#[wasm_bindgen]
pub fn set_header_resize_handle_style(
    id: i32,
    enabled: i32,
    color: u32,
    width_px: i32,
    height_mode: i32,
    height_value: f32,
    hit_width_px: i32,
    show_only_when_resizable: i32,
) {
    with_grid(id, |grid| {
        grid.style.header_resize_handle.enabled = enabled != 0;
        grid.style.header_resize_handle.color = color;
        grid.style.header_resize_handle.width_px = width_px.max(1);
        grid.style.header_resize_handle.height =
            header_mark_height_from_mode(height_mode, height_value);
        grid.style.header_resize_handle.hit_width_px = hit_width_px.max(1);
        grid.style.header_resize_handle.show_only_when_resizable = show_only_when_resizable != 0;
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn set_group_compare(id: i32, compare: i32) {
    with_grid(id, |grid| {
        grid.span.span_compare = compare;
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn get_group_compare(id: i32) -> i32 {
    with_grid(id, |grid| grid.span.span_compare).unwrap_or(0)
}

// ---------------------------------------------------------------------------
// Sort
// ---------------------------------------------------------------------------

/// Sort the grid by a column (single-column convenience).
/// order: 0=none, 1=asc generic, 2=desc generic, 3=asc numeric, 4=desc numeric, etc.
#[wasm_bindgen]
pub fn sort(id: i32, order: i32, col: i32) {
    with_grid(id, |grid| {
        sort::sort_grid(grid, order, col);
    });
}

/// Multi-column sort. `cols` and `orders` are parallel arrays of equal length.
/// Each pair (cols[i], orders[i]) defines one sort key in priority order.
#[wasm_bindgen]
pub fn sort_multi(id: i32, cols: &[i32], orders: &[i32]) {
    with_grid(id, |grid| {
        if cols.is_empty() || cols.len() != orders.len() {
            grid.sort_state.clear();
            grid.layout.invalidate();
            grid.mark_dirty();
            return;
        }
        let sort_keys: Vec<(i32, i32)> = cols
            .iter()
            .zip(orders.iter())
            .map(|(&c, &o)| (c, o))
            .collect();
        grid.sort_state.sort_keys = sort_keys;
        sort::sort_grid_all_multi(grid);
    });
}

// ---------------------------------------------------------------------------
// Render
// ---------------------------------------------------------------------------

/// Return a pointer to the internal render buffer.
/// JS uses this together with `render_buffer_len()` to create a view
/// into WASM linear memory.
#[wasm_bindgen]
pub fn render_buffer_ptr() -> *const u8 {
    let buf = RENDER_BUF.lock().unwrap();
    buf.as_ptr()
}

/// Return the current length of the render buffer in bytes.
#[wasm_bindgen]
pub fn render_buffer_len() -> usize {
    let buf = RENDER_BUF.lock().unwrap();
    buf.len()
}

#[wasm_bindgen]
pub fn render_dirty_x() -> i32 {
    let rect = RENDER_DIRTY_RECT.lock().unwrap();
    rect.0
}

#[wasm_bindgen]
pub fn render_dirty_y() -> i32 {
    let rect = RENDER_DIRTY_RECT.lock().unwrap();
    rect.1
}

#[wasm_bindgen]
pub fn render_dirty_w() -> i32 {
    let rect = RENDER_DIRTY_RECT.lock().unwrap();
    rect.2
}

#[wasm_bindgen]
pub fn render_dirty_h() -> i32 {
    let rect = RENDER_DIRTY_RECT.lock().unwrap();
    rect.3
}

/// Render the grid into the internal RGBA buffer.
///
/// The buffer is owned by Rust; JS reads it via `render_buffer_ptr()` /
/// `render_buffer_len()` after this call returns.
///
/// Returns 1 if pixels were painted, 0 if the grid was clean.
#[wasm_bindgen]
pub fn render(id: i32, width: i32, height: i32) -> i32 {
    resolve_expired_actions(id as i64);

    let mut dirty_rect = RENDER_DIRTY_RECT.lock().unwrap();
    *dirty_rect = (0, 0, 0, 0);
    drop(dirty_rect);

    if width <= 0 || height <= 0 {
        return 0;
    }

    let required = (width * height * 4) as usize;
    let id = id as i64;

    let mgr = MANAGER.lock().unwrap();
    let mgr = match mgr.as_ref() {
        Some(m) => m,
        None => return 0,
    };

    let grid_arc = match mgr.get_grid(id) {
        Ok(g) => g,
        Err(_) => return 0,
    };

    let mut grid = grid_arc.lock().unwrap();

    // Resize viewport to match the render target
    if grid.viewport_width != width || grid.viewport_height != height {
        grid.resize_viewport(width, height);
    }

    // Ensure layout is up-to-date
    ensure_layout(&mut grid);

    // Only render if dirty
    if !grid.dirty {
        return 0;
    }

    // Ensure the buffer is large enough
    let mut buf = RENDER_BUF.lock().unwrap();
    buf.resize(required, 0);

    ensure_renderer();
    let mut renderer = RENDERER.lock().unwrap();
    let renderer = renderer.as_mut().unwrap();

    let stride = width * 4;
    grid.debug_renderer_actual = 1; // CPU=1 (WASM always uses CPU renderer)
    grid.debug_gpu_backend.clear();
    grid.debug_gpu_present_mode.clear();
    let now_ms = js_sys::Date::now();
    maybe_update_debug_memory(id, &mut grid, now_ms);
    let t0 = js_sys::Date::now();
    let ((dirty_x, dirty_y, dirty_w, dirty_h), layer_times, zone_counts) =
        renderer.render(&grid, &mut buf, width, height, stride);
    if grid.layer_profiling {
        grid.layer_times_us = layer_times;
        grid.zone_cell_counts = zone_counts;
    }
    let elapsed = (js_sys::Date::now() - t0) as f32;
    grid.debug_frame_time_ms = elapsed;
    grid.debug_fps = grid.debug_fps * 0.9 + (1000.0 / elapsed.max(0.1)) * 0.1;
    grid.debug_instance_count = 0;
    grid.debug_text_cache_len = renderer.text_cache_len() as i32;

    let mut dirty_rect = RENDER_DIRTY_RECT.lock().unwrap();
    *dirty_rect = (dirty_x, dirty_y, dirty_w, dirty_h);

    grid.clear_dirty();
    1
}

// ---------------------------------------------------------------------------
// GPU Renderer (opt-in via `gpu` feature)
// ---------------------------------------------------------------------------

/// Set the renderer mode for a grid: 0=AUTO, 1=CPU, 2=GPU.
#[wasm_bindgen]
pub fn set_renderer_mode(id: i32, mode: i32) {
    with_grid(id, |grid| {
        grid.renderer_mode = mode;
        grid.mark_dirty();
    });
}

/// Get the current renderer mode for a grid.
#[wasm_bindgen]
pub fn get_renderer_mode(id: i32) -> i32 {
    with_grid(id, |grid| grid.renderer_mode).unwrap_or(0)
}

/// Check whether the GPU renderer feature is compiled in.
#[wasm_bindgen]
pub fn has_gpu_renderer() -> bool {
    cfg!(feature = "gpu")
}

/// Enable or disable the debug overlay.
#[wasm_bindgen]
pub fn set_debug_overlay(id: i32, enabled: bool) {
    with_grid(id, |grid| {
        grid.debug_overlay = enabled;
        grid.layer_profiling = enabled;
        grid.mark_dirty();
    });
}

/// Enable or disable scroll blit.
#[wasm_bindgen]
pub fn set_scroll_blit(id: i32, enabled: bool) {
    with_grid(id, |grid| {
        grid.scroll_blit_enabled = enabled;
        grid.mark_dirty();
    });
}

/// Set the render layer mask for a grid.
#[wasm_bindgen]
pub fn set_render_layer_mask(id: i32, mask_hi: i32, mask_lo: i32) {
    with_grid(id, |grid| {
        grid.render_layer_mask = ((mask_hi as u32 as u64) << 32) | (mask_lo as u32 as u64);
        grid.mark_dirty();
    });
}

/// Get the upper 32 bits of the render layer mask for a grid.
#[wasm_bindgen]
pub fn get_render_layer_mask_hi(id: i32) -> i32 {
    with_grid(id, |grid| (grid.render_layer_mask >> 32) as u32 as i32).unwrap_or(0)
}

/// Get the lower 32 bits of the render layer mask for a grid.
#[wasm_bindgen]
pub fn get_render_layer_mask_lo(id: i32) -> i32 {
    with_grid(id, |grid| grid.render_layer_mask as u32 as i32).unwrap_or(0)
}

/// Get the current debug overlay state.
#[wasm_bindgen]
pub fn get_debug_overlay(id: i32) -> bool {
    with_grid(id, |grid| grid.debug_overlay).unwrap_or(false)
}

/// Get the current scroll blit state.
#[wasm_bindgen]
pub fn get_scroll_blit(id: i32) -> bool {
    with_grid(id, |grid| grid.scroll_blit_enabled).unwrap_or(false)
}

/// Enable or disable layout animation.
/// `duration_ms` sets the animation duration in milliseconds (0 = default 200ms).
#[wasm_bindgen]
pub fn set_animation_enabled(id: i32, enabled: bool, duration_ms: i32) {
    with_grid(id, |grid| {
        grid.animation.enabled = enabled;
        if duration_ms > 0 {
            grid.animation.set_duration_ms(duration_ms);
        }
        if !enabled {
            grid.animation.clear();
            if grid.tick_scrollbar_fade(0.0) {
                grid.mark_dirty_visual();
            }
        }
    });
}

/// Get whether layout animation is enabled.
#[wasm_bindgen]
pub fn get_animation_enabled(id: i32) -> bool {
    with_grid(id, |grid| grid.animation.enabled).unwrap_or(false)
}

/// Set the text layout cache capacity.
#[wasm_bindgen]
pub fn set_text_layout_cache_cap(id: i32, cap: i32) {
    with_grid(id, |grid| {
        grid.set_text_layout_cache_cap(cap);
        grid.mark_dirty();
    });
}

// ---------------------------------------------------------------------------
// GPU Renderer init / surface / render (opt-in via `gpu` feature)
// ---------------------------------------------------------------------------

/// Async: initialise the GPU renderer. Returns a Promise<bool>.
/// true = GPU ready, false = GPU unavailable (fall back to CPU).
#[cfg(feature = "gpu")]
#[wasm_bindgen]
pub fn init_gpu() -> js_sys::Promise {
    future_to_promise(async {
        let gpu = match volvoxgrid_engine::gpu_render::GpuRenderer::new(None).await {
            Ok(g) => g,
            Err(e) => {
                web_sys::console::warn_1(&format!("GPU init failed: {}", e).into());
                return Ok(JsValue::from(false));
            }
        };

        let mut gr = GPU_RENDERER.lock().unwrap();
        gr.0 = Some(gpu);

        // Replay cached fonts into the GPU renderer
        let fonts = LOADED_FONTS.lock().unwrap().clone();
        if let Some(gpu) = gr.0.as_mut() {
            for font_data in fonts {
                gpu.load_font_data(font_data);
            }
        }

        *GPU_AVAILABLE.lock().unwrap() = true;
        Ok(JsValue::from(true))
    })
}

/// No-op stub when gpu feature is not compiled in.
#[cfg(not(feature = "gpu"))]
#[wasm_bindgen]
pub fn init_gpu() -> js_sys::Promise {
    js_sys::Promise::resolve(&JsValue::from(false))
}

/// Configure the GPU surface from an HTML canvas element.
/// Returns true on success.
#[cfg(feature = "gpu")]
#[wasm_bindgen]
pub fn gpu_configure_surface(
    canvas: web_sys::HtmlCanvasElement,
    w: u32,
    h: u32,
    present_mode: i32,
) -> bool {
    let mut gr = GPU_RENDERER.lock().unwrap();
    if let Some(gpu) = gr.0.as_mut() {
        match gpu.configure_surface_from_canvas(canvas, w, h, present_mode) {
            Ok(()) => true,
            Err(e) => {
                web_sys::console::warn_1(&format!("gpu_configure_surface failed: {}", e).into());
                false
            }
        }
    } else {
        false
    }
}

#[cfg(not(feature = "gpu"))]
#[wasm_bindgen]
pub fn gpu_configure_surface(
    _canvas: web_sys::HtmlCanvasElement,
    _w: u32,
    _h: u32,
    _present_mode: i32,
) -> bool {
    false
}

/// Resize the GPU surface.
#[cfg(feature = "gpu")]
#[wasm_bindgen]
pub fn gpu_resize_surface(w: u32, h: u32) {
    let mut gr = GPU_RENDERER.lock().unwrap();
    if let Some(gpu) = gr.0.as_mut() {
        gpu.resize_surface(w, h);
    }
}

#[cfg(not(feature = "gpu"))]
#[wasm_bindgen]
pub fn gpu_resize_surface(_w: u32, _h: u32) {}

/// Check whether the GPU renderer is initialised and ready.
#[wasm_bindgen]
pub fn is_gpu_ready() -> bool {
    #[cfg(feature = "gpu")]
    {
        *GPU_AVAILABLE.lock().unwrap()
    }
    #[cfg(not(feature = "gpu"))]
    {
        false
    }
}

/// Render via the GPU renderer directly to the configured surface.
/// Returns 1 if a frame was rendered, 0 if skipped.
#[cfg(feature = "gpu")]
#[wasm_bindgen]
pub fn render_gpu(id: i32, w: i32, h: i32) -> i32 {
    if w <= 0 || h <= 0 {
        return 0;
    }

    let id64 = id as i64;
    let mgr = MANAGER.lock().unwrap();
    let mgr = match mgr.as_ref() {
        Some(m) => m,
        None => return 0,
    };
    let grid_arc = match mgr.get_grid(id64) {
        Ok(g) => g,
        Err(_) => return 0,
    };
    let mut grid = grid_arc.lock().unwrap();

    if grid.viewport_width != w || grid.viewport_height != h {
        grid.resize_viewport(w, h);
    }
    grid.ensure_layout();

    if !grid.dirty {
        return 0;
    }

    let mut gr = GPU_RENDERER.lock().unwrap();
    let gpu = match gr.0.as_mut() {
        Some(g) => g,
        None => return 0,
    };

    grid.debug_renderer_actual = 2; // GPU=2
    grid.debug_gpu_backend = gpu.backend_name();
    grid.debug_gpu_present_mode = gpu.present_mode_name();
    let now_ms = js_sys::Date::now();
    maybe_update_debug_memory(id64, &mut grid, now_ms);
    let t0 = js_sys::Date::now();
    if let Ok((_, layer_times, zone_counts)) = gpu.render_to_surface(&grid, w, h) {
        if grid.layer_profiling {
            grid.layer_times_us = layer_times;
            grid.zone_cell_counts = zone_counts;
        }
    }
    let elapsed = (js_sys::Date::now() - t0) as f32;
    grid.debug_frame_time_ms = elapsed;
    grid.debug_fps = grid.debug_fps * 0.9 + (1000.0 / elapsed.max(0.1)) * 0.1;
    grid.debug_instance_count = gpu.instance_count() as i32;
    grid.debug_text_cache_len = gpu.text_cache_len() as i32;

    grid.clear_dirty();
    1
}

#[cfg(not(feature = "gpu"))]
#[wasm_bindgen]
pub fn render_gpu(_id: i32, _w: i32, _h: i32) -> i32 {
    0
}

// ---------------------------------------------------------------------------
// Input handling
// ---------------------------------------------------------------------------

#[wasm_bindgen]
pub fn handle_pointer_down(id: i32, x: f32, y: f32, button: i32, modifier: i32, dbl_click: bool) {
    let grid_id = id as i64;
    resolve_expired_actions(grid_id);
    with_grid(id, |grid| {
        ensure_layout(grid);
        if decision_channel_enabled(grid_id) {
            let hit = input::hit_test(grid, x, y);
            input::handle_pointer_down_with_behavior(
                grid,
                x,
                y,
                button,
                modifier,
                dbl_click,
                input::InputBehavior {
                    allow_begin_edit: false,
                    allow_header_sort: false,
                },
            );

            if hit.row >= 0 && hit.col >= 0 {
                let area = hit.area.clone();
                let is_cell_like = area == input::HitArea::Cell
                    || area == input::HitArea::FixedRow
                    || area == input::HitArea::FixedCol;
                let combo_list = if is_cell_like {
                    grid.active_dropdown_list(hit.row, hit.col)
                } else {
                    String::new()
                };
                let is_combo_cell = !combo_list.is_empty() && combo_list.trim() != "...";

                if area == input::HitArea::DropdownButton {
                    if !(grid.edit.is_active()
                        && grid.edit.edit_row == hit.row
                        && grid.edit.edit_col == hit.col)
                    {
                        request_before_edit(
                            grid_id, grid, hit.row, hit.col, false, None, None, None, None, None,
                        );
                    }
                } else if is_cell_like
                    && ((dbl_click && grid.edit_trigger_mode >= 2) || is_combo_cell)
                {
                    let click_caret = if dbl_click {
                        Some(grid.caret_index_from_display_click(hit.row, hit.col, hit.x_in_cell))
                    } else {
                        None
                    };
                    request_before_edit(
                        grid_id,
                        grid,
                        hit.row,
                        hit.col,
                        false,
                        None,
                        None,
                        click_caret,
                        if dbl_click { Some(true) } else { None },
                        None,
                    );
                }

                if area == input::HitArea::FixedRow
                    && hit.row < grid.fixed_rows
                    && !is_combo_cell
                    && grid.header_features > 0
                {
                    request_before_sort(grid_id, grid, hit.col);
                }
            }
        } else {
            input::handle_pointer_down(grid, x, y, button, modifier, dbl_click);
        }
    });
}

#[wasm_bindgen]
pub fn handle_pointer_move(id: i32, x: f32, y: f32, button: i32, modifier: i32) {
    with_grid(id, |grid| {
        ensure_layout(grid);
        input::handle_pointer_move(grid, x, y, button, modifier);
    });
}

#[wasm_bindgen]
pub fn handle_pointer_up(id: i32, x: f32, y: f32, button: i32) {
    with_grid(id, |grid| {
        ensure_layout(grid);
        input::handle_pointer_up(grid, x, y, button, 0);
    });
}

#[wasm_bindgen]
pub fn handle_key_down(id: i32, key_code: i32, modifier: i32) {
    let grid_id = id as i64;
    resolve_expired_actions(grid_id);
    with_grid(id, |grid| {
        ensure_layout(grid);
        if decision_channel_enabled(grid_id) {
            let was_editing = grid.edit.is_active();
            input::handle_key_down_with_behavior(
                grid,
                key_code,
                modifier,
                input::InputBehavior {
                    allow_begin_edit: false,
                    allow_header_sort: true,
                },
            );
            if (key_code == 13 || key_code == 113)
                && !grid.host_key_dispatch
                && grid.edit_trigger_mode >= 1
                && !was_editing
            {
                request_before_edit(
                    grid_id,
                    grid,
                    grid.selection.row,
                    grid.selection.col,
                    false,
                    None,
                    None,
                    None,
                    if key_code == 113 { Some(true) } else { None },
                    None,
                );
            }
        } else {
            input::handle_key_down(grid, key_code, modifier);
        }
    });
}

/// Handle a printable character input (key press).
/// char_code is a Unicode code point (e.g. 65 = 'A').
#[wasm_bindgen]
pub fn handle_key_press(id: i32, char_code: u32) {
    let grid_id = id as i64;
    resolve_expired_actions(grid_id);
    with_grid(id, |grid| {
        ensure_layout(grid);
        if decision_channel_enabled(grid_id) {
            let was_editing = grid.edit.is_active();
            input::handle_key_press_with_behavior(
                grid,
                char_code,
                input::InputBehavior {
                    allow_begin_edit: false,
                    allow_header_sort: true,
                },
            );
            if !was_editing
                && !grid.host_key_dispatch
                && grid.edit_trigger_mode >= 1
                && grid.type_ahead_mode == 0
            {
                if let Some(seed) = char::from_u32(char_code).map(|c| c.to_string()) {
                    if !seed.is_empty() {
                        request_before_edit(
                            grid_id,
                            grid,
                            grid.selection.row,
                            grid.selection.col,
                            false,
                            Some(seed),
                            None,
                            None,
                            None,
                            None,
                        );
                    }
                }
            }
        } else {
            input::handle_key_press(grid, char_code);
        }
    });
}

#[wasm_bindgen]
pub fn handle_scroll(id: i32, delta_x: f32, delta_y: f32) {
    with_grid(id, |grid| {
        ensure_layout(grid);
        input::handle_scroll(grid, delta_x, delta_y);
    });
}

// ---------------------------------------------------------------------------
// User resizing / freezing
// ---------------------------------------------------------------------------

#[wasm_bindgen]
pub fn set_resize_policy(id: i32, columns: bool, rows: bool, uniform: bool) {
    with_grid(id, |grid| {
        grid.allow_user_resizing = match (columns, rows, uniform) {
            (true, true, true) => 6,
            (true, true, false) => 3,
            (true, false, true) => 4,
            (true, false, false) => 1,
            (false, true, true) => 5,
            (false, true, false) => 2,
            (false, false, _) => 0,
        };
    });
}

#[wasm_bindgen]
pub fn get_resize_policy_mode(id: i32) -> i32 {
    with_grid(id, |grid| grid.allow_user_resizing).unwrap_or(0)
}

#[wasm_bindgen]
pub fn set_freeze_policy(id: i32, columns: bool, rows: bool) {
    with_grid(id, |grid| {
        grid.allow_user_freezing = match (columns, rows) {
            (true, true) => 3,
            (true, false) => 1,
            (false, true) => 2,
            (false, false) => 0,
        };
    });
}

#[wasm_bindgen]
pub fn get_freeze_policy_mode(id: i32) -> i32 {
    with_grid(id, |grid| grid.allow_user_freezing).unwrap_or(0)
}

/// Enable/disable auto-size on double-click of column border.
#[wasm_bindgen]
pub fn set_auto_size_mouse(id: i32, enabled: i32) {
    with_grid(id, |grid| {
        grid.auto_size_mouse = enabled != 0;
    });
}

#[wasm_bindgen]
pub fn get_auto_size_mouse(id: i32) -> i32 {
    with_grid(id, |grid| if grid.auto_size_mouse { 1 } else { 0 }).unwrap_or(0)
}

/// Auto-resize a column to fit its content.
#[wasm_bindgen]
pub fn auto_resize_col(id: i32, col: i32) {
    with_grid(id, |grid| {
        grid.auto_resize_col(col);
    });
}

/// Auto-resize a row to fit its content.
#[wasm_bindgen]
pub fn auto_resize_row(id: i32, row: i32) {
    with_grid(id, |grid| {
        grid.auto_resize_row(row);
    });
}

// ---------------------------------------------------------------------------
// FormatString / ColFormat / EditMask
// ---------------------------------------------------------------------------

/// Set the format_string property (pipe-delimited column defs like
/// "<Name|>Amount;120|^Status").
#[wasm_bindgen]
pub fn set_format_string(id: i32, fmt: &str) {
    with_grid(id, |grid| {
        grid.format_string = fmt.to_string();
    });
}

#[wasm_bindgen]
pub fn get_format_string(id: i32) -> String {
    with_grid(id, |grid| grid.format_string.clone()).unwrap_or_default()
}

/// Apply the current format_string to configure columns.
#[wasm_bindgen]
pub fn apply_format_string(id: i32) {
    with_grid(id, |grid| {
        grid.apply_format_string();
    });
}

/// Set display format for a column (e.g. "$#,##0.00", "0.0%").
#[wasm_bindgen]
pub fn set_col_format(id: i32, col: i32, format: &str) {
    with_grid(id, |grid| {
        if col >= 0 && (col as usize) < grid.columns.len() {
            grid.columns[col as usize].format = format.to_string();
            grid.mark_dirty();
        }
    });
}

#[wasm_bindgen]
pub fn get_col_format(id: i32, col: i32) -> String {
    with_grid(id, |grid| {
        if col >= 0 && (col as usize) < grid.columns.len() {
            grid.columns[col as usize].format.clone()
        } else {
            String::new()
        }
    })
    .unwrap_or_default()
}

#[wasm_bindgen]
pub fn set_col_progress_color(id: i32, col: i32, color: u32) {
    with_grid(id, |grid| {
        if col >= 0 && (col as usize) < grid.columns.len() {
            grid.columns[col as usize].progress_color = color;
            grid.mark_dirty();
        }
    });
}

#[wasm_bindgen]
pub fn set_col_flood_color(id: i32, col: i32, color: u32) {
    set_col_progress_color(id, col, color);
}

/// Set the global edit mask (e.g. "(###) ###-####").
#[wasm_bindgen]
pub fn set_edit_mask(id: i32, mask: &str) {
    with_grid(id, |grid| {
        grid.edit_mask = mask.to_string();
    });
}

#[wasm_bindgen]
pub fn get_edit_mask(id: i32) -> String {
    with_grid(id, |grid| grid.edit_mask.clone()).unwrap_or_default()
}

/// Set per-column edit mask.
#[wasm_bindgen]
pub fn set_col_edit_mask(id: i32, col: i32, mask: &str) {
    with_grid(id, |grid| {
        if col >= 0 && (col as usize) < grid.columns.len() {
            grid.columns[col as usize].edit_mask = mask.to_string();
        }
    });
}

// ---------------------------------------------------------------------------
// AddItem / RemoveItem
// ---------------------------------------------------------------------------

/// Insert a row with tab-delimited text. at_row = -1 to append at end.
#[wasm_bindgen]
pub fn add_item(id: i32, text: &str, at_row: i32) {
    with_grid(id, |grid| {
        grid.add_item(text, at_row);
        ensure_layout(grid);
    });
}

/// Remove a data row (must be >= fixed_rows).
#[wasm_bindgen]
pub fn remove_item(id: i32, row: i32) {
    with_grid(id, |grid| {
        grid.remove_item(row);
        ensure_layout(grid);
    });
}

// ---------------------------------------------------------------------------
// Display text
// ---------------------------------------------------------------------------

/// Get the display text for a cell (applies ColFormat and combo translation).
#[wasm_bindgen]
pub fn get_display_text(id: i32, row: i32, col: i32) -> String {
    with_grid(id, |grid| grid.get_display_text(row, col)).unwrap_or_default()
}

// ---------------------------------------------------------------------------
// Query helpers
// ---------------------------------------------------------------------------

/// Returns 1 if the grid has pending changes requiring a repaint.
#[wasm_bindgen]
pub fn is_dirty(id: i32) -> i32 {
    with_grid(id, |grid| if grid.dirty { 1 } else { 0 }).unwrap_or(0)
}

/// Returns the cursor style the host should display.
/// 0 = default, 1 = col-resize, 2 = row-resize, 3 = move/grab
#[wasm_bindgen]
pub fn get_cursor_style(id: i32) -> i32 {
    with_grid(id, |grid| grid.cursor_style).unwrap_or(0)
}

/// Returns the current cursor row.
#[wasm_bindgen]
pub fn get_selection_row(id: i32) -> i32 {
    with_grid(id, |grid| grid.selection.row).unwrap_or(-1)
}

/// Returns the current cursor col.
#[wasm_bindgen]
pub fn get_selection_col(id: i32) -> i32 {
    with_grid(id, |grid| grid.selection.col).unwrap_or(-1)
}

/// Returns the selection range-end row.
#[wasm_bindgen]
pub fn get_selection_row_end(id: i32) -> i32 {
    with_grid(id, |grid| grid.selection.row_end).unwrap_or(-1)
}

/// Returns the selection range-end col.
#[wasm_bindgen]
pub fn get_selection_col_end(id: i32) -> i32 {
    with_grid(id, |grid| grid.selection.col_end).unwrap_or(-1)
}

/// Mark the grid as needing a repaint.
#[wasm_bindgen]
pub fn invalidate(id: i32) {
    with_grid(id, |grid| {
        grid.mark_dirty();
    });
}

/// Set the redraw flag.  When false, data mutations skip the internal
/// dirty/repaint bookkeeping.  Use to batch many cell updates, then set
/// back to true and call invalidate().
#[wasm_bindgen]
pub fn set_redraw(id: i32, on: bool) {
    with_grid(id, |grid| {
        let was_off = !grid.redraw;
        grid.redraw = on;
        if on && was_off {
            grid.animation.suppress_next = true;
            grid.animation.clear();
        }
    });
}

#[wasm_bindgen]
pub fn set_scroll_bars(id: i32, mode: i32) {
    with_grid(id, |grid| {
        match mode {
            1 => {
                grid.scrollbar_show_h = ScrollBarMode::ScrollbarModeAuto as i32;
                grid.scrollbar_show_v = ScrollBarMode::ScrollbarModeNever as i32;
            }
            2 => {
                grid.scrollbar_show_h = ScrollBarMode::ScrollbarModeNever as i32;
                grid.scrollbar_show_v = ScrollBarMode::ScrollbarModeAuto as i32;
            }
            3 => {
                grid.scrollbar_show_h = ScrollBarMode::ScrollbarModeAuto as i32;
                grid.scrollbar_show_v = ScrollBarMode::ScrollbarModeAuto as i32;
            }
            _ => {
                grid.scrollbar_show_h = ScrollBarMode::ScrollbarModeNever as i32;
                grid.scrollbar_show_v = ScrollBarMode::ScrollbarModeNever as i32;
            }
        }
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn set_fast_scroll_enabled(id: i32, enabled: bool) {
    with_grid(id, |grid| {
        grid.fast_scroll_enabled = enabled;
        grid.mark_dirty();
    });
}

#[wasm_bindgen]
pub fn is_fast_scroll_active(id: i32) -> bool {
    with_grid(id, |grid| grid.fast_scroll_active).unwrap_or(false)
}

#[wasm_bindgen]
pub fn set_debug_zoom_level(id: i32, level: f64) {
    with_grid(id, |grid| {
        grid.debug_zoom_level = level;
    });
}

// ---------------------------------------------------------------------------
// Internals
// ---------------------------------------------------------------------------

fn with_grid<F, R>(id: i32, f: F) -> Option<R>
where
    F: FnOnce(&mut volvoxgrid_engine::grid::VolvoxGrid) -> R,
{
    let mgr = MANAGER.lock().unwrap();
    let mgr = mgr.as_ref()?;
    let grid_arc = mgr.get_grid(id as i64).ok()?;
    let mut grid = grid_arc.lock().unwrap();
    Some(f(&mut grid))
}

// ---------------------------------------------------------------------------
// Demo functions
// ---------------------------------------------------------------------------

/// Create a fully configured stress demo grid (1M rows).
/// Returns the grid ID.
#[wasm_bindgen]
pub fn demo_create_stress_grid(data_rows: i32, preload_rows: i32) -> i32 {
    ensure_manager();
    let grid = volvoxgrid_engine::demo::create_stress_grid(0, 0, 0, data_rows, preload_rows);
    let mgr = MANAGER.lock().unwrap();
    let mgr = mgr.as_ref().unwrap();
    let rows = grid.rows;
    let cols = grid.cols;
    let fr = grid.fixed_rows;
    let fc = grid.fixed_cols;
    let id = mgr.create_grid(0, 0, rows, cols, fr, fc, 1.0);
    let _ = mgr.with_grid(id, |dest| {
        *dest = grid;
        dest.id = id;
    });
    id as i32
}

/// Set up an existing grid as a stress test demo.
#[wasm_bindgen]
pub fn demo_setup_stress_grid(id: i32) {
    with_grid(id, |grid| {
        volvoxgrid_engine::demo::setup_stress_demo(grid);
    });
}

/// Set up an existing grid as the sales showcase demo (~1000 rows).
#[wasm_bindgen]
pub fn demo_setup_sales_demo(id: i32) {
    with_grid(id, |grid| {
        volvoxgrid_engine::demo::setup_sales_demo(grid);
    });
}

/// Set up an existing grid as the hierarchy showcase demo (~200 rows).
#[wasm_bindgen]
pub fn demo_setup_hierarchy_demo(id: i32) {
    with_grid(id, |grid| {
        volvoxgrid_engine::demo::setup_hierarchy_demo(grid);
    });
}

/// Materialize a single stress test data row.
#[wasm_bindgen]
pub fn demo_materialize_row(id: i32, row: i32) {
    with_grid(id, |grid| {
        volvoxgrid_engine::demo::stress_materialize_row(grid, row);
    });
}

/// Materialize visible rows + padding for the stress test.
#[wasm_bindgen]
pub fn demo_materialize_visible_rows(id: i32, padding: i32) {
    let pad = if padding <= 0 {
        volvoxgrid_engine::demo::STRESS_MATERIALIZE_PADDING
    } else {
        padding
    };
    with_grid(id, |grid| {
        volvoxgrid_engine::demo::stress_materialize_visible_rows(grid, pad);
    });
}

// ===========================================================================
// v1 proto-based batch API (WasmPlugin implementation)
// ===========================================================================

struct WasmPlugin;

fn wasm_with_grid<F, R>(id: i64, f: F) -> Result<R, String>
where
    F: FnOnce(&mut volvoxgrid_engine::grid::VolvoxGrid) -> R,
{
    let mgr = MANAGER.lock().unwrap();
    let mgr = mgr.as_ref().ok_or("manager not initialized")?;
    mgr.with_grid(id, f)
}

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
        E::EnterCell { row, col } => {
            Some(grid_event::Event::EnterCell(EnterCellEvent { row, col }))
        }
        E::LeaveCell { row, col } => {
            Some(grid_event::Event::LeaveCell(LeaveCellEvent { row, col }))
        }
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
        E::CellButtonClick { row, col } => {
            Some(grid_event::Event::CellButtonClick(CellButtonClickEvent {
                row,
                col,
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
        E::BeforeSort { col } => Some(grid_event::Event::BeforeSort(BeforeSortEvent { col })),
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
        E::BeforeMouseDown { row, col } => {
            Some(grid_event::Event::BeforeMouseDown(BeforeMouseDownEvent {
                row,
                col,
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
        } => Some(grid_event::Event::MouseMove(MouseMoveEvent {
            button,
            modifier,
            x,
            y,
        })),
        E::Click => Some(grid_event::Event::Click(ClickEvent {})),
        E::DblClick => Some(grid_event::Event::DblClick(DblClickEvent {})),
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

fn selection_range_tuples(grid: &volvoxgrid_engine::grid::VolvoxGrid) -> Vec<(i32, i32, i32, i32)> {
    grid.selection.all_ranges(grid.rows, grid.cols)
}

fn proto_ranges_from_tuples(ranges: &[(i32, i32, i32, i32)]) -> Vec<CellRange> {
    ranges
        .iter()
        .map(|&(row1, col1, row2, col2)| CellRange {
            row1,
            col1,
            row2,
            col2,
        })
        .collect()
}

fn selection_ranges_proto(grid: &volvoxgrid_engine::grid::VolvoxGrid) -> Vec<CellRange> {
    let ranges = selection_range_tuples(grid);
    proto_ranges_from_tuples(&ranges)
}

impl volvoxgrid_wasm::VolvoxGridServicePlugin for WasmPlugin {
    fn create(&self, request: CreateRequest) -> Result<CreateResponse, String> {
        ensure_manager();
        let rows = request
            .config
            .as_ref()
            .and_then(|c| c.layout.as_ref())
            .and_then(|l| l.rows)
            .unwrap_or(10);
        let cols = request
            .config
            .as_ref()
            .and_then(|c| c.layout.as_ref())
            .and_then(|l| l.cols)
            .unwrap_or(5);
        let fixed_rows = request
            .config
            .as_ref()
            .and_then(|c| c.layout.as_ref())
            .and_then(|l| l.fixed_rows)
            .unwrap_or(0);
        let fixed_cols = request
            .config
            .as_ref()
            .and_then(|c| c.layout.as_ref())
            .and_then(|l| l.fixed_cols)
            .unwrap_or(0);
        let mgr = MANAGER.lock().unwrap();
        let mgr = mgr.as_ref().unwrap();
        let id = mgr.create_grid(
            request.viewport_width,
            request.viewport_height,
            rows,
            cols,
            fixed_rows,
            fixed_cols,
            if request.scale > 0.01 {
                request.scale
            } else {
                1.0
            },
        );
        let apply_default_bands = request
            .config
            .as_ref()
            .and_then(|c| c.indicators.as_ref())
            .is_none();
        if let Some(config) = &request.config {
            let _ = mgr.with_grid(id, |grid| grid.apply_config(config));
        }
        if apply_default_bands {
            let _ = mgr.with_grid(id, apply_default_indicator_bands);
        }
        let _ = mgr.with_grid(id, replay_loaded_fonts_into_grid);
        Ok(CreateResponse {
            handle: Some(GridHandle { id }),
            warnings: Vec::new(),
        })
    }

    fn destroy(&self, request: GridHandle) -> Result<Empty, String> {
        let mgr = MANAGER.lock().unwrap();
        if let Some(mgr) = mgr.as_ref() {
            mgr.destroy_grid(request.id);
        }
        LAST_MEM_CALC_MS.lock().unwrap().remove(&request.id);
        Ok(Empty {})
    }

    fn configure(&self, request: ConfigureRequest) -> Result<Empty, String> {
        wasm_with_grid(request.grid_id, |grid| {
            if let Some(config) = &request.config {
                grid.apply_config(config);
            }
        })?;
        Ok(Empty {})
    }

    fn get_config(&self, request: GridHandle) -> Result<GridConfig, String> {
        wasm_with_grid(request.id, |grid| grid.get_config())
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

        load_font(request.data.as_slice());
        Ok(Empty {})
    }

    fn define_columns(&self, request: DefineColumnsRequest) -> Result<Empty, String> {
        wasm_with_grid(request.grid_id, |grid| {
            grid.define_columns(&request.columns);
        })?;
        Ok(Empty {})
    }

    fn get_schema(&self, request: GridHandle) -> Result<DefineColumnsRequest, String> {
        wasm_with_grid(request.id, |grid| grid.get_schema(request.id))
    }

    fn define_rows(&self, request: DefineRowsRequest) -> Result<Empty, String> {
        wasm_with_grid(request.grid_id, |grid| {
            grid.define_rows(&request.rows);
        })?;
        Ok(Empty {})
    }

    fn insert_rows(&self, request: InsertRowsRequest) -> Result<Empty, String> {
        wasm_with_grid(request.grid_id, |grid| {
            for i in 0..request.count.max(1) {
                let text = request
                    .text
                    .get(i as usize)
                    .map(|s| s.as_str())
                    .unwrap_or("");
                grid.add_item(text, request.index);
            }
        })?;
        Ok(Empty {})
    }

    fn remove_rows(&self, request: RemoveRowsRequest) -> Result<Empty, String> {
        wasm_with_grid(request.grid_id, |grid| {
            for i in (0..request.count.max(1)).rev() {
                grid.remove_item(request.index + i);
            }
        })?;
        Ok(Empty {})
    }

    fn move_column(&self, request: MoveColumnRequest) -> Result<Empty, String> {
        wasm_with_grid(request.grid_id, |grid| {
            grid.move_col_by_positions(request.col, request.position);
        })?;
        Ok(Empty {})
    }

    fn move_row(&self, _request: MoveRowRequest) -> Result<Empty, String> {
        // move_row not yet implemented in engine
        Ok(Empty {})
    }

    fn update_cells(&self, request: UpdateCellsRequest) -> Result<WriteResult, String> {
        wasm_with_grid(request.grid_id, |grid| {
            grid.write_cells(&request.cells, request.atomic)
        })
    }

    fn get_cells(&self, request: GetCellsRequest) -> Result<CellsResponse, String> {
        wasm_with_grid(request.grid_id, |grid| CellsResponse {
            cells: grid.get_cells(
                request.row1,
                request.col1,
                request.row2,
                request.col2,
                request.include_style,
                request.include_checked,
                request.include_typed,
            ),
        })
    }

    fn load_table(&self, request: LoadTableRequest) -> Result<WriteResult, String> {
        wasm_with_grid(request.grid_id, |grid| {
            grid.load_table(request.rows, request.cols, &request.values, request.atomic)
        })
    }

    fn clear(&self, request: ClearRequest) -> Result<Empty, String> {
        wasm_with_grid(request.grid_id, |grid| {
            let (r1, c1, r2, c2) = match request.region {
                0 => (
                    grid.fixed_rows,
                    grid.fixed_cols,
                    grid.rows - 1,
                    grid.cols - 1,
                ),
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
                    for (sr1, sc1, sr2, sc2) in selection_range_tuples(grid) {
                        grid.cells.clear_range(sr1, sc1, sr2, sc2);
                        for r in sr1..=sr2 {
                            for c in sc1..=sc2 {
                                grid.cell_styles.remove(&(r, c));
                            }
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
        wasm_with_grid(request.grid_id, |grid| {
            let active_row = request.active_row;
            let active_col = request.active_col;
            let ranges: Vec<(i32, i32, i32, i32)> = request
                .ranges
                .iter()
                .map(|r| (r.row1, r.col1, r.row2, r.col2))
                .collect();
            let old_ranges = selection_range_tuples(grid);
            grid.selection
                .select_ranges(active_row, active_col, &ranges, grid.rows, grid.cols);
            let new_ranges = selection_range_tuples(grid);
            grid.events
                .push(volvoxgrid_engine::event::GridEventData::SelectionChanging {
                    old_ranges: old_ranges.clone(),
                    new_ranges: new_ranges.clone(),
                    active_row: grid.selection.row,
                    active_col: grid.selection.col,
                });
            grid.events
                .push(volvoxgrid_engine::event::GridEventData::SelectionChanged {
                    old_ranges,
                    new_ranges,
                    active_row: grid.selection.row,
                    active_col: grid.selection.col,
                });
            if request.show.unwrap_or(false) {
                ensure_layout(grid);
                grid.scroll.show_cell(
                    active_row,
                    active_col,
                    &grid.layout,
                    grid.data_viewport_width(),
                    grid.data_viewport_height(),
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
        wasm_with_grid(request.id, |grid| {
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

    fn edit(&self, request: EditCommand) -> Result<EditState, String> {
        let grid_id = request.grid_id;
        wasm_with_grid(grid_id, |grid| {
            use edit_command::Command;
            match request.command {
                Some(Command::Start(s)) => {
                    let select_all = Some(s.select_all.unwrap_or(true));
                    let caret_end = Some(s.caret_end.unwrap_or(false));
                    let formula_mode = Some(s.formula_mode.unwrap_or(false));
                    if decision_channel_enabled(grid_id) {
                        request_before_edit(
                            grid_id,
                            grid,
                            s.row,
                            s.col,
                            false,
                            s.seed_text.clone(),
                            select_all,
                            None,
                            caret_end,
                            formula_mode,
                        );
                    } else {
                        grid.begin_edit(s.row, s.col);
                        if grid.edit.is_active()
                            && grid.edit.edit_row == s.row
                            && grid.edit.edit_col == s.col
                        {
                            grid.edit.set_formula_mode(formula_mode.unwrap_or(false));

                            if let Some(seed) = s.seed_text {
                                grid.edit.ui_mode = volvoxgrid_engine::edit::EditUiMode::EnterMode;
                                grid.edit.update_text(seed);
                                grid.edit.sel_start = grid.edit.edit_text.chars().count() as i32;
                                grid.edit.sel_length = 0;
                            } else if caret_end == Some(true) {
                                grid.edit.ui_mode = volvoxgrid_engine::edit::EditUiMode::EditMode;
                                grid.edit.sel_start = grid.edit.edit_text.chars().count() as i32;
                                grid.edit.sel_length = 0;
                            } else if select_all == Some(true) {
                                grid.edit.ui_mode = volvoxgrid_engine::edit::EditUiMode::EnterMode;
                                grid.edit.sel_start = 0;
                                grid.edit.sel_length = grid.edit.edit_text.chars().count() as i32;
                            }
                            grid.mark_dirty();
                        }
                    }
                }
                Some(Command::Commit(c)) => {
                    if grid.edit.is_active() {
                        grid.edit.flush_preedit();
                        let row = grid.edit.edit_row;
                        let col = grid.edit.edit_col;
                        let old_text = grid.cells.get_text(row, col).to_string();
                        let new_text = c.text.unwrap_or_else(|| grid.edit.edit_text.clone());
                        if decision_channel_enabled(grid_id) {
                            let pending_text =
                                truncate_to_char_count(&new_text, grid.edit_max_length);
                            grid.edit.update_text(pending_text.clone());
                            grid.edit.sel_start = pending_text.chars().count() as i32;
                            grid.edit.sel_length = 0;
                            request_validate_edit(grid_id, grid, row, col, old_text, pending_text);
                        } else {
                            grid.edit.update_text(new_text);
                            grid.commit_edit();
                        }
                    }
                }
                Some(Command::Cancel(_)) => {
                    grid.edit.cancel();
                }
                Some(Command::SetText(t)) => {
                    grid.edit.update_text(t.text);
                }
                Some(Command::SetSelection(s)) => {
                    grid.edit.sel_start = s.start;
                    grid.edit.sel_length = s.length;
                }
                Some(Command::SetHighlights(set_highlights)) => {
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
                Some(Command::SetPreedit(preedit)) => {
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
                Some(Command::Finish(_)) => {
                    if grid.edit.is_active() && decision_channel_enabled(grid_id) {
                        grid.edit.flush_preedit();
                        let row = grid.edit.edit_row;
                        let col = grid.edit.edit_col;
                        let old_text = grid.cells.get_text(row, col).to_string();
                        let new_text = grid.edit.edit_text.clone();
                        request_validate_edit(grid_id, grid, row, col, old_text, new_text);
                    } else {
                        grid.commit_edit();
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
        })
    }

    fn sort(&self, request: SortRequest) -> Result<Empty, String> {
        wasm_with_grid(request.grid_id, |grid| {
            if request.sort_columns.is_empty() {
                grid.sort_state.clear();
                grid.layout.invalidate();
                grid.mark_dirty();
            } else {
                let sort_keys: Vec<(i32, i32)> = request
                    .sort_columns
                    .iter()
                    .filter_map(|sc| {
                        let merged = volvoxgrid_engine::sort::merge_sort_spec(
                            volvoxgrid_engine::sort::SORT_NONE,
                            sc.order,
                            sc.r#type,
                        );
                        (merged != volvoxgrid_engine::sort::SORT_NONE).then_some((sc.col, merged))
                    })
                    .collect();
                grid.sort_state.sort_keys = sort_keys;
                volvoxgrid_engine::sort::sort_grid_all_multi(grid);
            }
        })?;
        Ok(Empty {})
    }

    fn subtotal(&self, request: SubtotalRequest) -> Result<Empty, String> {
        wasm_with_grid(request.grid_id, |grid| {
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
        wasm_with_grid(request.grid_id, |grid| {
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
        wasm_with_grid(request.grid_id, |grid| {
            volvoxgrid_engine::outline::outline(grid, request.level);
        })?;
        Ok(Empty {})
    }

    fn get_node(&self, request: GetNodeRequest) -> Result<NodeInfo, String> {
        wasm_with_grid(request.grid_id, |grid| {
            let rp = grid.row_props.get(&request.row);
            NodeInfo {
                row: request.row,
                level: rp.map_or(0, |p| p.outline_level),
                is_expanded: rp.map_or(true, |p| !p.is_collapsed),
                child_count: 0,
                parent_row: -1,
                first_child: -1,
                last_child: -1,
            }
        })
    }

    fn find(&self, request: FindRequest) -> Result<FindResponse, String> {
        wasm_with_grid(request.grid_id, |grid| {
            use find_request::Query;
            match &request.query {
                Some(Query::TextQuery(t)) => {
                    let row = volvoxgrid_engine::search::find_row(
                        grid,
                        &t.text,
                        request.start_row,
                        request.col,
                        t.case_sensitive,
                        t.full_match,
                    );
                    FindResponse { row }
                }
                Some(Query::RegexQuery(r)) => {
                    let row = volvoxgrid_engine::search::find_row_regex(
                        grid,
                        &r.pattern,
                        request.start_row,
                        request.col,
                    );
                    FindResponse { row }
                }
                None => FindResponse { row: -1 },
            }
        })
    }

    fn aggregate(&self, request: AggregateRequest) -> Result<AggregateResponse, String> {
        wasm_with_grid(request.grid_id, |grid| {
            let val = volvoxgrid_engine::search::aggregate(
                grid,
                request.aggregate,
                request.row1,
                request.col1,
                request.row2,
                request.col2,
            );
            AggregateResponse { value: val }
        })
    }

    fn get_merged_range(&self, request: GetMergedRangeRequest) -> Result<CellRange, String> {
        wasm_with_grid(request.grid_id, |grid| {
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
        wasm_with_grid(request.grid_id, |grid| {
            grid.merged_regions
                .add_merge(range.row1, range.col1, range.row2, range.col2);
            grid.layout.invalidate();
            grid.mark_dirty();
        })?;
        Ok(Empty {})
    }

    fn unmerge_cells(&self, request: UnmergeCellsRequest) -> Result<Empty, String> {
        let range = request.range.unwrap_or_default();
        wasm_with_grid(request.grid_id, |grid| {
            grid.merged_regions
                .remove_overlapping(range.row1, range.col1, range.row2, range.col2);
            grid.layout.invalidate();
            grid.mark_dirty();
        })?;
        Ok(Empty {})
    }

    fn get_merged_regions(&self, request: GridHandle) -> Result<MergedRegionsResponse, String> {
        wasm_with_grid(request.id, |grid| MergedRegionsResponse {
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
        wasm_with_grid(request.id, |grid| grid.memory_usage())
    }

    fn clipboard(&self, request: ClipboardCommand) -> Result<ClipboardResponse, String> {
        wasm_with_grid(request.grid_id, |grid| match request.command {
            Some(clipboard_command::Command::Copy(_)) => {
                let (text, rich_data) = volvoxgrid_engine::clipboard::copy(grid);
                ClipboardResponse { text, rich_data }
            }
            Some(clipboard_command::Command::Cut(_)) => {
                let (text, rich_data) = volvoxgrid_engine::clipboard::cut(grid);
                ClipboardResponse { text, rich_data }
            }
            Some(clipboard_command::Command::Paste(p)) => {
                volvoxgrid_engine::clipboard::paste(grid, &p.text);
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
        wasm_with_grid(request.grid_id, |grid| {
            let data = volvoxgrid_engine::save::save_grid(grid, request.format, request.scope);
            ExportResponse {
                data,
                format: request.format,
            }
        })
    }

    fn import(&self, request: ImportRequest) -> Result<Empty, String> {
        wasm_with_grid(request.grid_id, |grid| {
            volvoxgrid_engine::save::load_grid(grid, &request.data, request.format, request.scope);
        })?;
        Ok(Empty {})
    }

    fn print(&self, request: PrintRequest) -> Result<PrintResponse, String> {
        wasm_with_grid(request.grid_id, |grid| {
            ensure_layout(grid);
            let orientation = request.orientation.unwrap_or(0);
            let pages = volvoxgrid_engine::print::print_grid(
                grid,
                orientation,
                request.margin_left.unwrap_or(48),
                request.margin_top.unwrap_or(48),
                request.margin_right.unwrap_or(48),
                request.margin_bottom.unwrap_or(48),
                &request.header.as_deref().unwrap_or(""),
                &request.footer.as_deref().unwrap_or(""),
                request.show_page_numbers.unwrap_or(false),
            );
            PrintResponse {
                pages: pages
                    .into_iter()
                    .map(|p| PrintPage {
                        page_number: p.page_number,
                        image_data: p.image_data,
                        width: p.width,
                        height: p.height,
                    })
                    .collect(),
            }
        })
    }

    fn archive(&self, request: ArchiveRequest) -> Result<ArchiveResponse, String> {
        wasm_with_grid(request.grid_id, |grid| {
            let (data, names) = volvoxgrid_engine::save::archive(
                grid,
                &request.name,
                request.action,
                &request.data,
            );
            ArchiveResponse { data, names }
        })
    }

    fn show_cell(&self, request: ShowCellRequest) -> Result<Empty, String> {
        wasm_with_grid(request.grid_id, |grid| {
            ensure_layout(grid);
            grid.scroll.show_cell(
                request.row,
                request.col,
                &grid.layout,
                grid.data_viewport_width(),
                grid.data_viewport_height(),
                grid.fixed_rows,
                grid.fixed_cols,
                grid.pinned_top_height() + grid.pinned_bottom_height(),
                grid.pinned_left_width() + grid.pinned_right_width(),
            );
            grid.mark_dirty_visual();
        })?;
        Ok(Empty {})
    }

    fn set_top_row(&self, request: SetRowRequest) -> Result<Empty, String> {
        wasm_with_grid(request.grid_id, |grid| {
            grid.set_top_row(request.row);
        })?;
        Ok(Empty {})
    }

    fn set_left_col(&self, request: SetColRequest) -> Result<Empty, String> {
        wasm_with_grid(request.grid_id, |grid| {
            grid.set_left_col(request.col);
        })?;
        Ok(Empty {})
    }

    fn resize_viewport(&self, request: ResizeViewportRequest) -> Result<Empty, String> {
        wasm_with_grid(request.grid_id, |grid| {
            grid.viewport_width = request.width;
            grid.viewport_height = request.height;
            grid.mark_dirty();
        })?;
        Ok(Empty {})
    }

    fn set_redraw(&self, request: SetRedrawRequest) -> Result<Empty, String> {
        wasm_with_grid(request.grid_id, |grid| {
            grid.redraw = request.enabled;
            if request.enabled {
                grid.mark_dirty();
            }
        })?;
        Ok(Empty {})
    }

    fn refresh(&self, request: GridHandle) -> Result<Empty, String> {
        wasm_with_grid(request.id, |grid| {
            grid.mark_dirty();
        })?;
        Ok(Empty {})
    }

    fn load_demo(&self, request: LoadDemoRequest) -> Result<Empty, String> {
        wasm_with_grid(request.grid_id, |grid| match request.demo.as_str() {
            "sales" => volvoxgrid_engine::demo::setup_sales_demo(grid),
            "hierarchy" => volvoxgrid_engine::demo::setup_hierarchy_demo(grid),
            "stress" => volvoxgrid_engine::demo::setup_stress_demo(grid),
            _ => {}
        })?;
        Ok(Empty {})
    }

    fn render_session(
        &self,
        stream: &dyn volvoxgrid_wasm::PluginStreamBidi<RenderInput, RenderOutput>,
    ) -> Result<(), String> {
        while let Some(input) = stream.recv() {
            let grid_id = input.grid_id as i32;

            match input.input {
                Some(render_input::Input::Viewport(vs)) => {
                    with_grid(grid_id, |grid| {
                        grid.resize_viewport(vs.width, vs.height);
                    });
                    if !stream.send(RenderOutput {
                        rendered: false,
                        event: None,
                    }) {
                        break;
                    }
                }
                Some(render_input::Input::Pointer(p)) => {
                    with_grid(grid_id, |grid| {
                        ensure_layout(grid);
                        match p.r#type {
                            0 => input::handle_pointer_down(
                                grid,
                                p.x,
                                p.y,
                                p.button,
                                p.modifier,
                                p.dbl_click,
                            ),
                            1 => input::handle_pointer_up(grid, p.x, p.y, p.button, 0),
                            2 => input::handle_pointer_move(grid, p.x, p.y, p.button, p.modifier),
                            _ => {}
                        }
                    });
                    if !stream.send(RenderOutput {
                        rendered: false,
                        event: None,
                    }) {
                        break;
                    }
                }
                Some(render_input::Input::Key(k)) => {
                    with_grid(grid_id, |grid| {
                        ensure_layout(grid);
                        match k.r#type {
                            0 => input::handle_key_down(grid, k.key_code, k.modifier),
                            1 => {}
                            2 => {
                                let ch = k.character.chars().next().unwrap_or('\0') as u32;
                                if ch != 0 {
                                    input::handle_key_press(grid, ch);
                                }
                            }
                            _ => {}
                        }
                    });
                    if !stream.send(RenderOutput {
                        rendered: false,
                        event: None,
                    }) {
                        break;
                    }
                }
                Some(render_input::Input::Scroll(s)) => {
                    with_grid(grid_id, |grid| {
                        ensure_layout(grid);
                        input::handle_scroll(grid, s.delta_x, s.delta_y);
                    });
                    if !stream.send(RenderOutput {
                        rendered: false,
                        event: None,
                    }) {
                        break;
                    }
                }
                Some(render_input::Input::Zoom(_)) => {
                    if !stream.send(RenderOutput {
                        rendered: false,
                        event: None,
                    }) {
                        break;
                    }
                }
                Some(render_input::Input::GpuSurface(_)) => {
                    if !stream.send(RenderOutput {
                        rendered: false,
                        event: None,
                    }) {
                        break;
                    }
                }
                Some(render_input::Input::EventDecision(_)) => {
                    if !stream.send(RenderOutput {
                        rendered: false,
                        event: None,
                    }) {
                        break;
                    }
                }
                Some(render_input::Input::Buffer(buf)) => {
                    let rendered = render(grid_id, buf.width, buf.height) != 0;
                    let (dirty_x, dirty_y, dirty_w, dirty_h) = *RENDER_DIRTY_RECT.lock().unwrap();
                    let metrics = if rendered {
                        wasm_with_grid(grid_id as i64, |grid| current_frame_metrics(grid))
                            .ok()
                            .flatten()
                    } else {
                        None
                    };
                    if !stream.send(RenderOutput {
                        rendered,
                        event: Some(render_output::Event::FrameDone(FrameDone {
                            handle: buf.handle,
                            dirty_x,
                            dirty_y,
                            dirty_w,
                            dirty_h,
                            metrics,
                        })),
                    }) {
                        break;
                    }
                }
                None => {
                    if !stream.send(RenderOutput {
                        rendered: false,
                        event: None,
                    }) {
                        break;
                    }
                }
            }
        }
        Ok(())
    }

    fn event_stream(
        &self,
        request: GridHandle,
        stream: &dyn volvoxgrid_wasm::PluginStreamSender<GridEvent>,
    ) -> Result<(), String> {
        let events = wasm_with_grid(request.id, |grid| grid.events.drain())?;
        for evt in events {
            let proto_evt = engine_event_to_proto(request.id, evt.event_id, evt.data);
            if proto_evt.event.is_none() {
                continue;
            }
            if !stream.send(proto_evt) {
                break;
            }
        }
        Ok(())
    }
}

/// Register the WASM plugin implementation. Call once on module init.
#[wasm_bindgen]
pub fn init_v1_plugin() {
    ensure_manager();
    volvoxgrid_wasm::register_volvox_grid_service_plugin(WasmPlugin);
}
