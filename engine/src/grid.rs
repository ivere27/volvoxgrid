use std::cell::{Cell, RefCell};
use std::collections::{HashMap, HashSet};
use std::hash::{Hash, Hasher};
use std::sync::Arc;
#[cfg(not(target_arch = "wasm32"))]
use std::time::Instant;
use unicode_width::UnicodeWidthStr;
#[cfg(target_arch = "wasm32")]
use web_time::Instant;

use crate::animation::AnimationState;
use crate::cell::CellStore;
use crate::column::ColumnProps;
use crate::control::CellControl;
use crate::drag::DragState;
use crate::edit::EditState;
use crate::event::EventQueue;
use crate::indicator::{ColIndicatorRowDefState, IndicatorBandsState};
use crate::layout::LayoutCache;
use crate::outline::OutlineState;
use crate::proto::volvoxgrid::v1 as pb;
use crate::row::RowProps;
use crate::scroll::ScrollState;
use crate::scrollbar::{
    reset_scrollbar_fade_state, scrollbar_fade_animating, scrollbar_overlays_content,
    ScrollBarColors, DEFAULT_SCROLLBAR_FADE_DELAY_MS, DEFAULT_SCROLLBAR_FADE_DURATION_MS,
    DEFAULT_SCROLLBAR_MARGIN, DEFAULT_SCROLLBAR_MIN_THUMB,
};
use crate::selection::SelectionState;
use crate::sort::SortState;
use crate::span::SpanState;
use crate::style::{CellStylePatch, GridStyleState, Padding};
use crate::text::{TextEngine, DEFAULT_LAYOUT_CACHE_CAP};

/// Default row height in pixels.
pub const DEFAULT_ROW_HEIGHT: i32 = 20;

/// Default column width in pixels.
pub const DEFAULT_COL_WIDTH: i32 = 68;
pub const DEFAULT_TUI_ROW_HEIGHT: i32 = 1;
pub const DEFAULT_TUI_COL_WIDTH: i32 = 15;
/// Default fixed-rate pacing fallback when no platform frame clock is available.
pub const DEFAULT_TARGET_FRAME_RATE_HZ: i32 = 30;
const DEFAULT_PULL_TO_REFRESH_THRESHOLD_PX: f32 = 72.0;
const DEFAULT_PULL_TO_REFRESH_MAX_REVEAL_PX: f32 = 132.0;
const DEFAULT_PULL_TO_REFRESH_CANCEL_SNAP_PX: f32 = 18.0;
const DEFAULT_PULL_TO_REFRESH_TOUCH_SLOP_PX: f32 = 8.0;
const DEFAULT_PULL_TO_REFRESH_SETTLE_SPEED_PX_PER_SEC: f32 = 480.0;
const DEFAULT_PULL_TO_REFRESH_TEXT_PULL: &str = "Pull to refresh";
const DEFAULT_PULL_TO_REFRESH_TEXT_RELEASE: &str = "Release to refresh";

/// Minimum allowed row count.
const MIN_ROWS: i32 = 1;

/// Minimum allowed column count.
const MIN_COLS: i32 = 1;

// Keep build metadata in the final binary even when version APIs are not called.
#[used]
static VOLVOXGRID_BUILD_METADATA: &str = concat!(
    "VOLVOXGRID_VERSION=",
    env!("VOLVOXGRID_VERSION"),
    ";VOLVOXGRID_GIT_COMMIT=",
    env!("VOLVOXGRID_GIT_COMMIT"),
    ";VOLVOXGRID_BUILD_DATE=",
    env!("VOLVOXGRID_BUILD_DATE")
);

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum PullToRefreshState {
    Idle,
    Pulling,
    Armed,
    Settling,
}

#[inline]
fn heap_hash_map_bytes<K, V>(map: &HashMap<K, V>) -> usize {
    map.capacity() * (std::mem::size_of::<K>() + std::mem::size_of::<V>() + 8)
}

#[inline]
fn heap_hash_set_bytes<T>(set: &HashSet<T>) -> usize {
    set.capacity() * (std::mem::size_of::<T>() + 8)
}

#[inline]
fn heap_vec_bytes<T>(vec: &Vec<T>) -> usize {
    vec.capacity() * std::mem::size_of::<T>()
}

#[inline]
fn usize_to_i64_saturating(value: usize) -> i64 {
    if value > i64::MAX as usize {
        i64::MAX
    } else {
        value as i64
    }
}

#[inline]
fn usize_to_i32_saturating(value: usize) -> i32 {
    if value > i32::MAX as usize {
        i32::MAX
    } else {
        value as i32
    }
}

fn grow_span_heights_to_fit(
    heights: &mut [i32],
    row1: usize,
    row2: usize,
    needed_total: i32,
) -> bool {
    if row1 > row2 || row2 >= heights.len() {
        return false;
    }
    let current_total: i32 = heights[row1..=row2].iter().sum();
    if needed_total <= current_total {
        return false;
    }

    let extra = needed_total - current_total;
    let span_len = row2 - row1 + 1;
    let base = extra / span_len as i32;
    let remainder = extra % span_len as i32;
    for offset in 0..span_len {
        let add = base + if (offset as i32) < remainder { 1 } else { 0 };
        heights[row1 + offset] = heights[row1 + offset].saturating_add(add);
    }
    true
}

#[derive(Debug)]
pub(crate) struct TextCellStaticMeta {
    pub display_text: Arc<str>,
    pub style_override: Arc<CellStylePatch>,
    pub padding: Padding,
    pub alignment: i32,
    pub has_dropdown_list: bool,
    pub suppress_text: bool,
    pub shrink_to_fit: bool,
}

/// The main VolvoxGrid struct holding all grid state for a single grid instance.
///
/// This is the central data structure of the pixel-rendering datagrid engine.
/// It owns all cell data, layout state, style information, selection tracking,
/// scroll position, edit state, merge/outline/sort configuration, drag state,
/// the event queue, and layout caches. A `TextEngine` is stored as an `Option`
/// and initialized lazily on first render.
pub struct VolvoxGrid {
    // ── Identity ──────────────────────────────────────────────────────────
    /// Unique identifier assigned by `GridManager`.
    pub id: i64,

    // ── Grid Dimensions ───────────────────────────────────────────────────
    /// Total number of rows (including fixed rows).
    pub rows: i32,
    /// Total number of columns (including fixed columns).
    pub cols: i32,
    /// Number of non-scrollable header rows at the top.
    pub fixed_rows: i32,
    /// Number of non-scrollable header columns on the left.
    pub fixed_cols: i32,
    /// Number of frozen (non-scrollable data) rows below the fixed rows.
    pub frozen_rows: i32,
    /// Number of frozen (non-scrollable data) columns to the right of fixed columns.
    pub frozen_cols: i32,

    // ── Viewport ──────────────────────────────────────────────────────────
    /// Width of the visible viewport in pixels.
    pub viewport_width: i32,
    /// Height of the visible viewport in pixels.
    pub viewport_height: i32,

    // ── Default Sizes ─────────────────────────────────────────────────────
    /// Default height for rows that have no per-row override (pixels).
    pub default_row_height: i32,
    /// Default width for columns that have no per-column override (pixels).
    pub default_col_width: i32,

    // ── Per-Row/Col Sizes ─────────────────────────────────────────────────
    /// Custom row heights. Only rows with non-default heights are stored.
    pub row_heights: HashMap<i32, i32>,
    /// Custom column widths. Only columns with non-default widths are stored.
    pub col_widths: HashMap<i32, i32>,

    // ── Row/Col Min/Max ───────────────────────────────────────────────────
    /// Global minimum row height in pixels. 0 means no minimum enforced.
    pub row_height_min: i32,
    /// Global maximum row height in pixels. 0 means no maximum enforced.
    pub row_height_max: i32,
    /// Per-column minimum widths. Only columns with explicit minimums are stored.
    pub col_width_min: HashMap<i32, i32>,
    /// Per-column maximum widths. Only columns with explicit maximums are stored.
    pub col_width_max: HashMap<i32, i32>,

    // ── Hidden Rows/Cols ──────────────────────────────────────────────────
    /// Set of row indices that are hidden (zero visual height).
    pub rows_hidden: HashSet<i32>,
    /// Set of column indices that are hidden (zero visual width).
    pub cols_hidden: HashSet<i32>,

    // ── Position Mapping (logical → physical) ─────────────────────────────
    /// Maps display position to logical row index. `row_positions[display_pos] = logical_row`.
    pub row_positions: Vec<i32>,
    /// Maps display position to logical column index. `col_positions[display_pos] = logical_col`.
    pub col_positions: Vec<i32>,

    // ── Cell Storage ──────────────────────────────────────────────────────
    /// Sparse cell data store holding text, values, and per-cell properties.
    pub cells: CellStore,

    // ── Column Properties ─────────────────────────────────────────────────
    /// Per-column properties (alignment, format, data type, key, dropdown list, etc.).
    pub columns: Vec<ColumnProps>,

    // ── Row Properties ────────────────────────────────────────────────────
    /// Per-row properties (subtotal flag, outline level, collapsed state, etc.).
    /// Only rows with non-default properties are stored.
    pub row_props: HashMap<i32, RowProps>,

    // ── Styling ───────────────────────────────────────────────────────────
    /// Grid-level style (colors, grid lines, fonts, appearance, background image).
    pub style: GridStyleState,
    /// Per-cell style overrides keyed by `(row, col)`.
    pub cell_styles: HashMap<(i32, i32), CellStylePatch>,
    /// Indicator bands around the data viewport.
    pub indicator_bands: IndicatorBandsState,

    // ── Selection ─────────────────────────────────────────────────────────
    /// Current cursor position, selection extent, selection mode, focus border, and selection visibility.
    pub selection: SelectionState,

    // ── Scroll ────────────────────────────────────────────────────────────
    /// Current scroll offsets (pixel-level sub-row/col precision).
    pub scroll: ScrollState,

    // ── Edit ──────────────────────────────────────────────────────────────
    /// Active cell-edit state (editing flag, row/col being edited, original text).
    pub edit: EditState,

    // ── Span ──────────────────────────────────────────────────────────────
    /// Span mode, per-row/col span flags, fixed-area span mode.
    pub span: SpanState,

    // ── Explicit Merge ───────────────────────────────────────────────────
    /// Registry of explicit user-initiated merge ranges (spreadsheet-style).
    pub merged_regions: crate::merge_registry::MergeRegistry,

    // ── Outline ───────────────────────────────────────────────────────────
    /// Outline bar style, outline column, tree color, node pictures.
    pub outline: OutlineState,

    // ── Sort ──────────────────────────────────────────────────────────────
    /// Current sort column, sort order, explorer bar mode.
    pub sort_state: SortState,

    // ── Drag ──────────────────────────────────────────────────────────────
    /// Drag mode, drop mode, and in-progress drag tracking.
    pub drag: DragState,

    // ── Animation ────────────────────────────────────────────────────────
    /// Layout animation state: smooth position transitions on structural changes.
    pub animation: AnimationState,

    // ── Events ────────────────────────────────────────────────────────────
    /// Queue of pending grid events to be delivered via `EventStream`.
    pub events: EventQueue,

    // ── Layout Cache ──────────────────────────────────────────────────────
    /// Cached cumulative row/col pixel offsets for fast hit-testing and rendering.
    pub layout: LayoutCache,

    // ── Text Engine ───────────────────────────────────────────────────────
    /// Text shaping and measurement engine, lazily initialized on first render.
    pub text_engine: Option<TextEngine>,
    /// Configured text layout cache capacity, applied to `text_engine` on init.
    pub text_layout_cache_cap: usize,
    // ── Compatibility Properties ────────────────────────────────────
    /// Whether bulk bind/load writes auto-fit row heights / column widths.
    ///
    /// This also gates the per-cell auto-resize helper when callers opt into
    /// it. Disable for very large datasets because auto-fit may scan many or
    /// all cells.
    pub auto_resize: bool,
    /// Whether type-ahead is currently active.
    pub is_type_ahead_active: bool,
    /// Keystroke buffer for type-ahead buffering across multiple keystrokes.
    pub type_ahead_buffer: String,
    /// Timestamp of the last type-ahead keystroke.
    pub type_ahead_last_input: Option<Instant>,
    /// Custom text for scroll tips (overrides default row number).
    pub scroll_tooltip_text: String,
    /// Consolidated bitfield for minor boolean options (Flags property).
    pub flags: u32,
    /// Host-managed `DataMode` compatibility flag (host-managed mode integer).
    pub data_source_mode: i32,
    /// `VirtualData` compatibility flag.
    pub virtual_mode: bool,

    // ── Misc Properties ───────────────────────────────────────────────────
    /// Edit trigger mode: 0 = none, 1 = keyboard, 2 = keyboard+mouse.
    pub edit_trigger_mode: i32,
    /// Apply scope: 0 = single cell, 1 = repeat across selection.
    pub apply_scope: i32,
    /// Whether cell selection is allowed.
    pub allow_selection: bool,
    /// Whether selecting entire rows/columns by clicking headers is allowed.
    pub header_click_select: bool,
    /// User resizing mode: 0=none, 1=cols, 2=rows, 3=both, 4-6=uniform variants.
    pub allow_user_resizing: i32,
    /// User freezing mode: 0=none, 1=cols, 2=rows, 3=both.
    pub allow_user_freezing: i32,
    /// Type-ahead mode: 0=none, 1=from top, 2=from cursor.
    pub type_ahead_mode: i32,
    /// Delay in milliseconds before type-ahead kicks in.
    pub type_ahead_delay: i32,
    /// Auto-size mode: 0=both, 1=col width only, 2=row height only.
    pub auto_size_mode: i32,
    /// Whether double-clicking a column border auto-sizes the column.
    pub auto_size_mouse: bool,
    /// Horizontal scrollbar visibility mode.
    pub scrollbar_show_h: i32,
    /// Vertical scrollbar visibility mode.
    pub scrollbar_show_v: i32,
    /// Scrollbar appearance preset.
    pub scrollbar_appearance: i32,
    /// Scrollbar thickness in pixels.
    pub scrollbar_size: i32,
    /// Minimum scrollbar thumb length in pixels.
    pub scrollbar_min_thumb: i32,
    /// Thumb corner radius in pixels.
    pub scrollbar_corner_radius: i32,
    /// Resolved scrollbar colors.
    pub scrollbar_colors: ScrollBarColors,
    /// Overlay scrollbar fade delay in milliseconds.
    pub scrollbar_fade_delay_ms: i32,
    /// Overlay scrollbar fade duration in milliseconds.
    pub scrollbar_fade_duration_ms: i32,
    /// Overlay scrollbar edge inset in pixels.
    pub scrollbar_margin: i32,
    /// Overlay scrollbar opacity in the 0.0..=1.0 range.
    pub scrollbar_fade_opacity: f32,
    /// Overlay scrollbar fade countdown in seconds.
    pub scrollbar_fade_timer: f32,
    /// Timestamp of the last engine-side overlay scrollbar fade tick.
    pub scrollbar_fade_last_tick: Option<Instant>,
    /// Whether the pointer is currently over a scrollbar hit area.
    pub scrollbar_hover: bool,
    /// Whether scroll position updates live while dragging the thumb.
    pub scroll_track: bool,
    /// Whether scroll tips are shown while dragging the scroll thumb.
    pub scroll_tips: bool,
    /// Whether wheel/touch scroll can continue with inertial fling physics.
    pub fling_enabled: bool,
    /// Whether pinch zoom gestures are accepted by the engine/plugin.
    pub pinch_zoom_enabled: bool,
    /// Multiplier used to convert wheel/touch delta into fling velocity.
    pub fling_impulse_gain: f32,
    /// Exponential damping coefficient used by fling physics (higher = stops faster).
    pub fling_friction: f32,
    /// Whether built-in pull-to-refresh is enabled.
    pub pull_to_refresh_enabled: bool,
    /// Pull-to-refresh theme selection.
    pub pull_to_refresh_theme: i32,
    /// Optional override for the pull-state label shown before arming.
    pub pull_to_refresh_text_pull: Option<String>,
    /// Optional override for the armed-state label shown before release.
    pub pull_to_refresh_text_release: Option<String>,
    /// Tab key behavior: 0=move to next control, 1=move to next cell.
    pub tab_behavior: i32,
    /// Header features mode: controls sort glyphs and column drag in headers.
    pub header_features: i32,
    /// Custom render mode: 0=never, 1=cell level, 2=complete.
    pub custom_render: i32,
    /// Whether cell text wraps within the cell boundaries.
    pub word_wrap: bool,
    /// Ellipsis mode: 0 = none, 1 = end, 2 = path/middle.
    pub ellipsis_mode: i32,
    /// Whether cell text spills into empty adjacent cells.
    pub text_overflow: bool,
    /// Whether the grid layout is right-to-left.
    pub right_to_left: bool,
    /// Whether the last column extends to fill the remaining viewport width.
    pub extend_last_col: bool,
    /// Whether the grid should repaint on data changes. Set to false to batch updates.
    pub redraw: bool,
    /// Whether typing in a dropdown cell searches the dropdown list.
    pub dropdown_search: bool,
    /// When to show dropdown button: 0=never, 1=always, 2=when editing.
    pub dropdown_trigger: i32,
    /// Host integration provides dropdown UI; renderer suppresses built-in popup list.
    pub host_dropdown_overlay: bool,
    /// Global edit mask string (e.g. "(999) 999-9999").
    pub edit_mask: String,
    /// Maximum number of characters allowed in an edit cell. 0 = unlimited.
    pub edit_max_length: i32,
    /// When true, the engine stops handling edit-action keys (Enter, Escape, F2,
    /// typing-to-start-edit) — the host adapter dispatches those via Edit RPC.
    /// In-edit text manipulation (character insert, backspace, delete, cursor,
    /// dropdown nav) remains engine-handled.
    pub host_key_dispatch: bool,
    /// When true, the engine stops handling pointer-driven selection changes
    /// and edit triggers — the host adapter drives those via Select / Edit RPC.
    /// Engine-rendered UI (resize, scrollbar, fast-scroll, freeze drag) remains
    /// engine-handled.
    pub host_pointer_dispatch: bool,
    /// When true, keypresses in edit mode route through the engine-side compose layer.
    pub engine_compose: bool,
    /// Tracks whether `engine_compose` was explicitly configured.
    pub engine_compose_configured: bool,
    /// Selected engine-side compose method.
    pub compose_method: i32,
    /// Tracks whether `compose_method` was explicitly configured.
    pub compose_method_configured: bool,
    /// Column separator for clipboard operations (default: "\t").
    pub clip_col_separator: String,
    /// Row separator for clipboard operations (default: "\n").
    pub clip_row_separator: String,
    /// Pipe-delimited format string for quick column setup.
    pub format_string: String,
    /// Output mode used by `Picture` property.
    /// 0=color, 1=monochrome, 2=enhanced metafile (compatibility maps to PNG).
    pub picture_type: i32,

    // ── Renderer Mode ──────────────────────────────────────────────────
    /// Whether grid geometry should be interpreted in character cells.
    pub tui_mode: bool,
    /// 0 = AUTO, 1 = CPU, 2 = GPU, 3 = Vulkan, 4 = GLES, 5 = TUI.
    pub renderer_mode: i32,
    /// 0 = Auto (Fifo), 1 = Fifo, 2 = Mailbox, 3 = Immediate.
    pub present_mode: i32,
    /// 0 = AUTO, 1 = PLATFORM, 2 = UNLIMITED, 3 = FIXED.
    pub frame_pacing_mode: i32,
    /// Target frame rate in Hz used when frame_pacing_mode = FIXED.
    pub target_frame_rate_hz: i32,

    // ── Debug Overlay ────────────────────────────────────────────────
    /// Whether the debug overlay is visible.
    pub debug_overlay: bool,
    /// Last frame render time in milliseconds (set by plugin/wasm before render).
    pub debug_frame_time_ms: f32,
    /// Smoothed FPS (exponential moving average).
    pub debug_fps: f32,
    /// Current zoom level (1.0 = 100%), synced from plugin zoom_levels.
    pub debug_zoom_level: f64,
    /// Actual renderer in use: 0 = CPU, 1 = GPU (set by plugin at render time).
    pub debug_renderer_actual: i32,
    /// Name of the GPU backend in use (e.g. "Vulkan", "OpenGL", "WebGPU").
    pub debug_gpu_backend: String,
    /// Name of the active GPU present mode (e.g. "Fifo", "Mailbox").
    pub debug_gpu_present_mode: String,
    /// Total number of draw calls/instances in the last frame.
    pub debug_instance_count: i32,
    /// Current number of entries in the text layout cache.
    pub debug_text_cache_len: i32,
    /// Estimated total heap memory usage of the grid in bytes.
    pub debug_total_mem_bytes: i64,

    // ── Render Layer Profiling ───────────────────────────────────────────
    /// Bitmask controlling which render layers are enabled (default: all on).
    pub render_layer_mask: u64,
    /// Whether per-layer timing is active.
    pub layer_profiling: bool,
    /// Enables CPU scroll-blit reuse during scroll-only frames.
    pub scroll_blit_enabled: bool,
    /// Per-layer execution time in microseconds from the last frame.
    pub layer_times_us: [f32; crate::canvas::layer::COUNT],
    /// Time spent building `RenderContext` (us) — not included in layer times.
    pub debug_ctx_time_us: Cell<f32>,
    /// Time spent clearing/blitting the canvas (us) — not included in layer times.
    pub debug_clear_time_us: Cell<f32>,
    /// Cell counts per zone: [scrollable, sticky, pinned, fixed].
    pub zone_cell_counts: [u32; 4],

    // ── Dirty Flag ────────────────────────────────────────────────────────
    /// Whether the grid has pending changes that require a re-render.
    pub dirty: bool,
    /// Generation counter for text cell metadata invalidation.
    pub(crate) text_meta_generation: u64,
    /// Cache of `(generation, map)` for `build_text_cell_static_meta`.
    text_meta_cache: RefCell<(u64, HashMap<(i32, i32), Arc<TextCellStaticMeta>>)>,
    /// Cached render context for frame-to-frame reuse (type-erased).
    pub(crate) render_ctx_cache: RefCell<Option<Box<dyn std::any::Any + Send>>>,
    /// Cached signature for lazy row-indicator auto-size updates.
    row_indicator_start_auto_size_sig: u64,

    // ── Mouse Tracking ────────────────────────────────────────────────────
    /// Row index currently under the mouse pointer (-1 if none).
    pub mouse_row: i32,
    /// Column index currently under the mouse pointer (-1 if none).
    pub mouse_col: i32,
    /// Cursor style the host should display.
    /// 0 = default, 1 = col-resize, 2 = row-resize, 3 = move/grab,
    /// 4 = pointer/hand, 5 = pointer/hand (interactive cell content)
    pub cursor_style: i32,

    // ── Resize Tracking ──────────────────────────────────────────────────
    /// Whether a column/row resize drag is in progress.
    pub resize_active: bool,
    /// True = resizing a column, false = resizing a row.
    pub resize_is_col: bool,
    /// Index of the column or row being resized.
    pub resize_index: i32,
    /// Mouse position (X for col, Y for row) at drag start.
    pub resize_start_pos: f32,
    /// Original column width or row height at drag start.
    pub resize_start_size: i32,

    // ── Column Drag/Reorder Tracking ─────────────────────────────────────
    /// Whether a column drag/reorder is in progress.
    pub col_drag_active: bool,
    /// Source column index being dragged.
    pub col_drag_source: i32,
    /// Logical column key currently hovered while dragging.
    pub col_drag_target: i32,
    /// Insertion gap index while dragging (0..=cols), `-1` when invalid/canceled.
    ///
    /// Value means "insert before display position N"; `cols` means append to end.
    pub col_drag_insert_pos: i32,
    /// True once the drag changed insertion target at least once.
    /// Used to avoid treating a canceled drag as a sort click.
    pub col_drag_moved: bool,
    /// True while waiting for a long-press before activating column drag.
    pub col_drag_pending: bool,
    /// Source column index held for pending long-press drag.
    pub col_drag_pending_source: i32,
    /// Whether short release should sort for this pending header interaction.
    pub col_drag_pending_can_sort: bool,
    /// Timestamp when pending header long-press started.
    pub col_drag_pending_since: Option<Instant>,

    // ── User Freeze Tracking ─────────────────────────────────────────────
    /// Whether a freeze drag is in progress.
    pub freeze_drag_active: bool,
    /// True = freezing rows, false = freezing cols.
    pub freeze_drag_is_row: bool,

    // ── Outline Button Click ─────────────────────────────────────────────
    /// Set during an outline +/- button click to suppress selection extension.
    pub outline_click_active: bool,
    /// Set after a dropdown item click commits, to consume the rest of the
    /// same pointer gesture so it does not leak into grid selection.
    pub dropdown_click_active: bool,
    /// Whether a dropdown button is currently shown pressed.
    pub dropdown_button_pressed: bool,
    /// Cell row for the active dropdown button press.
    pub dropdown_button_pressed_row: i32,
    /// Cell column for the active dropdown button press.
    pub dropdown_button_pressed_col: i32,

    // ── Fast Scroll Tracking ──────────────────────────────────────────────
    /// Whether the fast-scroll touch overlay is enabled (mobile).
    pub fast_scroll_enabled: bool,
    /// Whether a fast-scroll gesture is currently active.
    pub fast_scroll_active: bool,
    /// Current target row during a fast-scroll gesture (-1 = none).
    pub fast_scroll_target_row: i32,
    /// Column preserved during fast-scroll (anchor from selection).
    pub fast_scroll_anchor_col: i32,

    // ── Scrollbar Drag Tracking ─────────────────────────────────────────
    /// Whether a scrollbar thumb drag is in progress.
    pub scrollbar_drag_active: bool,
    /// True = dragging horizontal scrollbar, false = vertical.
    pub scrollbar_drag_horizontal: bool,
    /// Mouse pixel position at drag start.
    pub scrollbar_drag_start_pos: f32,
    /// scroll_x or scroll_y value at drag start.
    pub scrollbar_drag_start_scroll: f32,

    // ── Scrollbar Auto-Repeat ────────────────────────────────────────────
    /// Whether a scrollbar arrow/track auto-repeat is active.
    pub scrollbar_repeat_active: bool,
    /// True = repeating horizontal scroll, false = vertical.
    pub scrollbar_repeat_horizontal: bool,
    /// Signed scroll delta applied per repeat tick.
    pub scrollbar_repeat_delta: f32,
    /// Countdown timer: initial delay before repeating starts, then interval between repeats.
    pub scrollbar_repeat_delay: f32,
    /// True when the repeat originated from a track click (should stop when thumb reaches mouse).
    pub scrollbar_repeat_is_track: bool,
    /// Mouse pixel position of the track click (x for horizontal, y for vertical).
    pub scrollbar_repeat_mouse_pos: f32,

    // ── Pull-to-Refresh Tracking ─────────────────────────────────────────
    /// Current engine-owned pull-to-refresh state.
    pub pull_to_refresh_state: PullToRefreshState,
    /// Current reveal amount in pixels.
    pub pull_to_refresh_reveal_px: f32,
    /// Target reveal amount used by settle/refresh animations.
    pub pull_to_refresh_target_reveal_px: f32,
    /// Whether a touch-like pointer contact is currently active.
    pub pull_to_refresh_contact_active: bool,
    /// Accumulated horizontal gesture distance during the current contact.
    pub pull_to_refresh_drag_accum_x_px: f32,
    /// Accumulated vertical gesture distance during the current contact.
    pub pull_to_refresh_drag_accum_y_px: f32,
    /// Tracks whether the current contact ever revealed the affordance.
    pub pull_to_refresh_had_reveal: bool,

    // ── Virtual Data Generation ─────────────────────────────────────────
    /// Optional function to generate cell text for rows that haven't been
    /// materialized (e.g. stress test with lazy loading).
    /// Used by the sort system to compare unmaterialized rows.
    /// Signature: fn(source_row: i32, col: i32) -> String
    pub sort_value_generator: Option<fn(i32, i32) -> String>,

    // ── Focus State ──────────────────────────────────────────────────────
    /// Whether the grid currently has keyboard/input focus.
    /// Used by "selection visible when focused" mode to decide whether to draw selection highlight.
    pub has_focus: bool,

    // ── DPI Scale ────────────────────────────────────────────────────────
    /// DPI scale factor set at grid creation. 1.0 = no scaling.
    pub scale: f32,

    // ── Background Loading ───────────────────────────────────────────────
    /// True while a background thread is generating data (e.g. stress demo).
    pub background_loading: bool,
    /// Monotonically increasing counter for cancelling superseded background tasks.
    pub background_generation: u64,

    // ── Pin & Sticky ────────────────────────────────────────────────────
    /// Sorted row indices pinned to the top (below fixed/frozen rows).
    pub pinned_rows_top: Vec<i32>,
    /// Sorted row indices pinned to the bottom (footer area).
    pub pinned_rows_bottom: Vec<i32>,
    /// Sorted column indices pinned to the left (after fixed/frozen columns).
    pub pinned_cols_left: Vec<i32>,
    /// Sorted column indices pinned to the right (right-edge section).
    pub pinned_cols_right: Vec<i32>,
    /// Row-level sticky edges: row → StickyEdge (TOP or BOTTOM).
    pub sticky_rows: HashMap<i32, i32>,
    /// Column-level sticky edges: col → StickyEdge (LEFT or RIGHT).
    pub sticky_cols: HashMap<i32, i32>,
    /// Cell-level sticky overrides: (row, col) → (sticky_row_edge, sticky_col_edge).
    pub sticky_cells: HashMap<(i32, i32), (i32, i32)>,
}

impl VolvoxGrid {
    /// Creates a new `VolvoxGrid` with the given dimensions and sensible defaults.
    ///
    /// - `fixed_rows` is clamped to at least 0.
    /// - `fixed_cols` is passed through as-is (0 is a common default).
    /// - Row and column position mappings are initialized as identity (0..n).
    /// - Column properties are initialized with default `ColumnProps` for each column.
    pub fn new(
        id: i64,
        viewport_width: i32,
        viewport_height: i32,
        rows: i32,
        cols: i32,
        fixed_rows: i32,
        fixed_cols: i32,
    ) -> Self {
        let rows = rows.max(MIN_ROWS);
        let cols = cols.max(MIN_COLS);
        let fixed_rows = fixed_rows.max(0).min(rows);
        let fixed_cols = fixed_cols.max(0).min(cols);

        let row_positions: Vec<i32> = (0..rows).collect();
        let col_positions: Vec<i32> = (0..cols).collect();
        let columns: Vec<ColumnProps> = (0..cols).map(|_| ColumnProps::default()).collect();

        VolvoxGrid {
            id,

            // Grid dimensions
            rows,
            cols,
            fixed_rows,
            fixed_cols,
            frozen_rows: 0,
            frozen_cols: 0,

            // Viewport
            viewport_width,
            viewport_height,

            // Default sizes
            default_row_height: DEFAULT_ROW_HEIGHT,
            default_col_width: DEFAULT_COL_WIDTH,

            // Per-row/col sizes
            row_heights: HashMap::new(),
            col_widths: HashMap::new(),

            // Min/max
            row_height_min: 0,
            row_height_max: 0,
            col_width_min: HashMap::new(),
            col_width_max: HashMap::new(),

            // Hidden
            rows_hidden: HashSet::new(),
            cols_hidden: HashSet::new(),

            // Position mapping
            row_positions,
            col_positions,

            // Cell storage
            cells: CellStore::new(),

            // Column and row properties
            columns,
            row_props: HashMap::new(),

            // Styling
            style: GridStyleState::default(),
            cell_styles: HashMap::new(),
            indicator_bands: IndicatorBandsState::default(),

            // Selection
            selection: SelectionState::with_initial(fixed_rows, fixed_cols),

            // Scroll
            scroll: ScrollState::default(),

            // Edit
            edit: EditState::default(),

            // Span
            span: SpanState::default(),

            // Explicit merge
            merged_regions: crate::merge_registry::MergeRegistry::new(),

            // Outline
            outline: OutlineState::default(),

            // Sort
            sort_state: SortState::default(),

            // Drag
            drag: DragState::default(),

            // Animation
            animation: AnimationState::new(),

            // Events
            events: EventQueue::new(),

            // Layout cache
            layout: LayoutCache::new(),

            // Text engine (lazily initialized)
            text_engine: None,
            text_layout_cache_cap: DEFAULT_LAYOUT_CACHE_CAP,

            // Compatibility defaults
            auto_resize: true,
            is_type_ahead_active: false,
            type_ahead_buffer: String::new(),
            type_ahead_last_input: None,
            scroll_tooltip_text: String::new(),
            flags: 0,
            data_source_mode: 0,
            virtual_mode: false,

            // Misc properties
            edit_trigger_mode: 0,
            apply_scope: 0,
            allow_selection: true,
            header_click_select: true,
            allow_user_resizing: 0,
            allow_user_freezing: 0,
            type_ahead_mode: 0,
            type_ahead_delay: 2000,
            auto_size_mode: 0,
            auto_size_mouse: false,
            scrollbar_show_h: pb::ScrollBarMode::ScrollbarModeNever as i32,
            scrollbar_show_v: pb::ScrollBarMode::ScrollbarModeNever as i32,
            scrollbar_appearance: pb::ScrollBarAppearance::ScrollbarAppearanceClassic as i32,
            scrollbar_size: 16,
            scrollbar_min_thumb: DEFAULT_SCROLLBAR_MIN_THUMB,
            scrollbar_corner_radius: 0,
            scrollbar_colors: crate::scrollbar::default_scrollbar_colors(
                pb::ScrollBarAppearance::ScrollbarAppearanceClassic as i32,
            ),
            scrollbar_fade_delay_ms: DEFAULT_SCROLLBAR_FADE_DELAY_MS,
            scrollbar_fade_duration_ms: DEFAULT_SCROLLBAR_FADE_DURATION_MS,
            scrollbar_margin: DEFAULT_SCROLLBAR_MARGIN,
            scrollbar_fade_opacity: 1.0,
            scrollbar_fade_timer: 0.0,
            scrollbar_fade_last_tick: None,
            scrollbar_hover: false,
            scroll_track: true,
            scroll_tips: false,
            fling_enabled: true,
            pinch_zoom_enabled: true,
            fling_impulse_gain: 30.0,
            fling_friction: 2.0,
            pull_to_refresh_enabled: false,
            pull_to_refresh_theme: pb::PullToRefreshTheme::TopBand as i32,
            pull_to_refresh_text_pull: None,
            pull_to_refresh_text_release: None,
            tab_behavior: pb::TabBehavior::TabCells as i32,
            header_features: 0,
            custom_render: 0,
            word_wrap: false,
            ellipsis_mode: 0,
            text_overflow: false,
            right_to_left: false,
            extend_last_col: false,
            redraw: true,
            dropdown_search: false,
            dropdown_trigger: 0,
            host_dropdown_overlay: false,
            edit_mask: String::new(),
            edit_max_length: 0,
            host_key_dispatch: false,
            host_pointer_dispatch: false,
            engine_compose: false,
            engine_compose_configured: false,
            compose_method: pb::ComposeMethod::None as i32,
            compose_method_configured: false,
            clip_col_separator: "\t".to_string(),
            clip_row_separator: "\n".to_string(),
            format_string: String::new(),
            picture_type: 0,

            // Renderer mode (0=AUTO, 1=CPU, 2=GPU, 3=Vulkan, 4=GLES, 5=TUI)
            tui_mode: false,
            renderer_mode: 0,
            // Present mode (0=Auto, 1=Fifo, 2=Mailbox, 3=Immediate)
            present_mode: 0,
            // Frame pacing (0=AUTO, 1=PLATFORM, 2=UNLIMITED, 3=FIXED)
            frame_pacing_mode: 0,
            target_frame_rate_hz: DEFAULT_TARGET_FRAME_RATE_HZ,

            // Debug overlay
            debug_overlay: false,
            debug_frame_time_ms: 0.0,
            debug_fps: 0.0,
            debug_zoom_level: 1.0,
            debug_renderer_actual: 0,
            debug_gpu_backend: String::new(),
            debug_gpu_present_mode: String::new(),
            debug_instance_count: 0,
            debug_text_cache_len: 0,
            debug_total_mem_bytes: 0,

            // Render layer profiling
            render_layer_mask: u64::MAX,
            layer_profiling: false,
            scroll_blit_enabled: false,
            layer_times_us: [0.0; crate::canvas::layer::COUNT],
            debug_ctx_time_us: Cell::new(0.0),
            debug_clear_time_us: Cell::new(0.0),
            zone_cell_counts: [0; 4],

            // Dirty
            dirty: true,
            text_meta_generation: 0,
            text_meta_cache: RefCell::new((0, HashMap::new())),
            render_ctx_cache: RefCell::new(None),
            row_indicator_start_auto_size_sig: 0,

            // Mouse tracking
            mouse_row: -1,
            mouse_col: -1,
            cursor_style: 0,

            // Resize tracking
            resize_active: false,
            resize_is_col: true,
            resize_index: -1,
            resize_start_pos: 0.0,
            resize_start_size: 0,

            // Column drag/reorder tracking
            col_drag_active: false,
            col_drag_source: -1,
            col_drag_target: -1,
            col_drag_insert_pos: -1,
            col_drag_moved: false,
            col_drag_pending: false,
            col_drag_pending_source: -1,
            col_drag_pending_can_sort: false,
            col_drag_pending_since: None,

            // User freeze tracking
            freeze_drag_active: false,
            freeze_drag_is_row: true,

            // Outline button click
            outline_click_active: false,
            dropdown_click_active: false,
            dropdown_button_pressed: false,
            dropdown_button_pressed_row: -1,
            dropdown_button_pressed_col: -1,

            // Fast scroll tracking
            fast_scroll_enabled: false,
            fast_scroll_active: false,
            fast_scroll_target_row: -1,
            fast_scroll_anchor_col: 0,

            // Scrollbar drag tracking
            scrollbar_drag_active: false,
            scrollbar_drag_horizontal: false,
            scrollbar_drag_start_pos: 0.0,
            scrollbar_drag_start_scroll: 0.0,

            // Scrollbar auto-repeat
            scrollbar_repeat_active: false,
            scrollbar_repeat_horizontal: false,
            scrollbar_repeat_delta: 0.0,
            scrollbar_repeat_delay: 0.0,
            scrollbar_repeat_is_track: false,
            scrollbar_repeat_mouse_pos: 0.0,

            // Pull-to-refresh tracking
            pull_to_refresh_state: PullToRefreshState::Idle,
            pull_to_refresh_reveal_px: 0.0,
            pull_to_refresh_target_reveal_px: 0.0,
            pull_to_refresh_contact_active: false,
            pull_to_refresh_drag_accum_x_px: 0.0,
            pull_to_refresh_drag_accum_y_px: 0.0,
            pull_to_refresh_had_reveal: false,

            // Virtual data generation
            sort_value_generator: None,

            // Focus state
            has_focus: false,

            // DPI scale
            scale: 1.0,

            // Background loading
            background_loading: false,
            background_generation: 0,

            // Pin & sticky
            pinned_rows_top: Vec::new(),
            pinned_rows_bottom: Vec::new(),
            pinned_cols_left: Vec::new(),
            pinned_cols_right: Vec::new(),
            sticky_rows: HashMap::new(),
            sticky_cols: HashMap::new(),
            sticky_cells: HashMap::new(),
        }
    }

    fn style_heap_size_bytes(&self) -> usize {
        let mut bytes = 0usize;
        bytes += self.style.heap_size_bytes();
        bytes += heap_hash_map_bytes(&self.cell_styles);
        for style in self.cell_styles.values() {
            bytes += style.heap_size_bytes();
        }
        bytes
    }

    fn column_heap_size_bytes(&self) -> usize {
        let mut bytes = 0usize;
        bytes += heap_vec_bytes(&self.columns);
        for col in &self.columns {
            bytes += col.heap_size_bytes();
        }
        bytes
    }

    fn row_heap_size_bytes(&self) -> usize {
        let mut bytes = 0usize;
        bytes += heap_hash_map_bytes(&self.row_heights);
        bytes += heap_hash_map_bytes(&self.row_props);
        for props in self.row_props.values() {
            bytes += props.heap_size_bytes();
        }
        bytes += heap_hash_set_bytes(&self.rows_hidden);
        bytes += heap_hash_set_bytes(&self.cols_hidden);
        bytes
    }

    fn misc_heap_size_bytes(&self) -> usize {
        let mut bytes = 0usize;
        bytes += heap_hash_map_bytes(&self.col_widths);
        bytes += heap_hash_map_bytes(&self.col_width_min);
        bytes += heap_hash_map_bytes(&self.col_width_max);

        bytes += heap_vec_bytes(&self.row_positions);
        bytes += heap_vec_bytes(&self.col_positions);

        bytes += heap_vec_bytes(&self.pinned_rows_top);
        bytes += heap_vec_bytes(&self.pinned_rows_bottom);
        bytes += heap_vec_bytes(&self.pinned_cols_left);
        bytes += heap_vec_bytes(&self.pinned_cols_right);
        bytes += heap_hash_map_bytes(&self.sticky_rows);
        bytes += heap_hash_map_bytes(&self.sticky_cols);
        bytes += heap_hash_map_bytes(&self.sticky_cells);

        bytes += self.span.heap_size_bytes();
        bytes += self.merged_regions.heap_size_bytes();
        bytes += self.edit.heap_size_bytes();
        bytes += self.outline.heap_size_bytes();
        bytes += self.sort_state.heap_size_bytes();

        bytes += self.type_ahead_buffer.capacity();
        bytes += self.scroll_tooltip_text.capacity();
        bytes += self.edit_mask.capacity();
        bytes += self.clip_col_separator.capacity();
        bytes += self.clip_row_separator.capacity();
        bytes += self.format_string.capacity();
        bytes += self
            .pull_to_refresh_text_pull
            .as_ref()
            .map_or(0, |v| v.capacity());
        bytes += self
            .pull_to_refresh_text_release
            .as_ref()
            .map_or(0, |v| v.capacity());

        bytes
    }

    pub fn heap_size_bytes(&self) -> usize {
        let cell_data_bytes = self.cells.heap_size_bytes();
        let style_bytes = self.style_heap_size_bytes();
        let layout_bytes = self.layout.heap_size_bytes();
        let column_bytes = self.column_heap_size_bytes();
        let row_bytes = self.row_heap_size_bytes();
        let selection_bytes = self.selection.heap_size_bytes();
        let animation_bytes = self.animation.heap_size_bytes();
        let text_engine_bytes = self
            .text_engine
            .as_ref()
            .map_or(0, TextEngine::heap_size_bytes);
        let event_bytes = self.events.heap_size_bytes();
        let misc_bytes = self.misc_heap_size_bytes();

        cell_data_bytes
            + style_bytes
            + layout_bytes
            + column_bytes
            + row_bytes
            + selection_bytes
            + animation_bytes
            + text_engine_bytes
            + event_bytes
            + misc_bytes
    }

    pub fn memory_usage(&self) -> pb::MemoryUsageResponse {
        let cell_data_bytes = self.cells.heap_size_bytes();
        let style_bytes = self.style_heap_size_bytes();
        let layout_bytes = self.layout.heap_size_bytes();
        let column_bytes = self.column_heap_size_bytes();
        let row_bytes = self.row_heap_size_bytes();
        let selection_bytes = self.selection.heap_size_bytes();
        let animation_bytes = self.animation.heap_size_bytes();
        let text_engine_bytes = self
            .text_engine
            .as_ref()
            .map_or(0, TextEngine::heap_size_bytes);
        let event_bytes = self.events.heap_size_bytes();
        let misc_bytes = self.misc_heap_size_bytes();
        let total_bytes = cell_data_bytes
            + style_bytes
            + layout_bytes
            + column_bytes
            + row_bytes
            + selection_bytes
            + animation_bytes
            + text_engine_bytes
            + event_bytes
            + misc_bytes;

        pb::MemoryUsageResponse {
            total_bytes: usize_to_i64_saturating(total_bytes),
            cell_data_bytes: usize_to_i64_saturating(cell_data_bytes),
            style_bytes: usize_to_i64_saturating(style_bytes),
            layout_bytes: usize_to_i64_saturating(layout_bytes),
            column_bytes: usize_to_i64_saturating(column_bytes),
            row_bytes: usize_to_i64_saturating(row_bytes),
            selection_bytes: usize_to_i64_saturating(selection_bytes),
            animation_bytes: usize_to_i64_saturating(animation_bytes),
            text_engine_bytes: usize_to_i64_saturating(text_engine_bytes),
            event_bytes: usize_to_i64_saturating(event_bytes),
            misc_bytes: usize_to_i64_saturating(misc_bytes),
            cell_count: usize_to_i32_saturating(self.cells.len()),
            rows: self.rows,
            cols: self.cols,
        }
    }

    // ── Row/Col Count ─────────────────────────────────────────────────────

    /// Sets the total number of rows. Adjusts the position mapping to match.
    ///
    /// If the new row count is larger, new rows are appended to the position
    /// mapping with identity indices. If smaller, excess entries are removed
    /// and any custom row heights, hidden flags, row props, and cell data for
    /// removed rows remain in their maps (they become orphaned but harmless).
    /// Fixed rows are clamped if they would exceed the new count.
    pub fn set_rows(&mut self, rows: i32) {
        let rows = rows.max(MIN_ROWS);
        let old_rows = self.rows;
        if rows == old_rows {
            return;
        }
        // Notify animation before changing state
        let h = self.default_row_height;
        if rows > old_rows {
            self.animation
                .notify_rows_inserted(old_rows, rows - old_rows, h);
        } else {
            self.animation.notify_rows_removed(rows, old_rows - rows, h);
        }

        self.rows = rows;

        // Clamp fixed/frozen rows to not exceed total
        if self.fixed_rows > self.rows {
            self.fixed_rows = self.rows;
        }
        if self.fixed_rows + self.frozen_rows > self.rows {
            self.frozen_rows = (self.rows - self.fixed_rows).max(0);
        }

        // Adjust position mapping
        if rows > old_rows {
            // Append new rows with identity mapping
            for i in old_rows..rows {
                self.row_positions.push(i);
            }
        } else if rows < old_rows {
            // Truncate position mapping. Remove entries that reference rows >= new count,
            // and also trim to length.
            self.row_positions.retain(|&r| r < rows);
            // Ensure we have exactly `rows` entries; pad if retain removed too many
            while (self.row_positions.len() as i32) < rows {
                // Find an index not yet in the vec
                let existing: HashSet<i32> = self.row_positions.iter().cloned().collect();
                for i in 0..rows {
                    if !existing.contains(&i) {
                        self.row_positions.push(i);
                        break;
                    }
                }
            }
            self.row_positions.truncate(rows as usize);
        }

        // Clamp selection
        self.selection
            .clamp(self.rows, self.cols, self.fixed_rows, self.fixed_cols);

        // Remove pinned columns that are no longer in range.
        self.pinned_cols_left.retain(|&c| c >= 0 && c < self.cols);
        self.pinned_cols_right.retain(|&c| c >= 0 && c < self.cols);

        self.scroll.stop_fling();
        self.layout.invalidate();
        self.text_meta_generation = self.text_meta_generation.wrapping_add(1);
        self.dirty = true;
    }

    /// Sets the total number of columns. Adjusts the position mapping and
    /// column properties vec to match.
    ///
    /// If the new column count is larger, new columns are appended with identity
    /// position indices and default `ColumnProps`. If smaller, excess entries
    /// are removed.
    pub fn set_cols(&mut self, cols: i32) {
        let cols = cols.max(MIN_COLS);
        let old_cols = self.cols;
        if cols == old_cols {
            return;
        }
        // Notify animation before changing state
        let w = self.default_col_width;
        if cols > old_cols {
            self.animation
                .notify_cols_inserted(old_cols, cols - old_cols, w);
        } else {
            self.animation.notify_cols_removed(cols, old_cols - cols, w);
        }

        self.cols = cols;

        // Clamp fixed/frozen cols
        if self.fixed_cols > self.cols {
            self.fixed_cols = self.cols;
        }
        if self.fixed_cols + self.frozen_cols > self.cols {
            self.frozen_cols = (self.cols - self.fixed_cols).max(0);
        }

        // Adjust position mapping
        if cols > old_cols {
            for i in old_cols..cols {
                self.col_positions.push(i);
            }
        } else if cols < old_cols {
            self.col_positions.retain(|&c| c < cols);
            while (self.col_positions.len() as i32) < cols {
                let existing: HashSet<i32> = self.col_positions.iter().cloned().collect();
                for i in 0..cols {
                    if !existing.contains(&i) {
                        self.col_positions.push(i);
                        break;
                    }
                }
            }
            self.col_positions.truncate(cols as usize);
        }

        // Adjust columns vec
        if cols > old_cols {
            for _ in old_cols..cols {
                self.columns.push(ColumnProps::default());
            }
        } else if cols < old_cols {
            self.columns.truncate(cols as usize);
        }

        // Clamp selection
        self.selection
            .clamp(self.rows, self.cols, self.fixed_rows, self.fixed_cols);

        self.scroll.stop_fling();
        self.layout.invalidate();
        self.text_meta_generation = self.text_meta_generation.wrapping_add(1);
        self.dirty = true;
    }

    // ── Row Height ────────────────────────────────────────────────────────

    /// Returns the height of the given row in pixels.
    ///
    /// If the row is hidden, returns 0. If the row has a custom height, returns
    /// that. Otherwise returns `default_row_height`.
    pub fn get_row_height(&self, row: i32) -> i32 {
        if row < 0 || row >= self.rows {
            return 0;
        }
        if self.rows_hidden.contains(&row) {
            return 0;
        }
        match self.row_heights.get(&row) {
            Some(&h) => self.clamp_row_height(h),
            None => self.clamp_row_height(self.default_row_height),
        }
    }

    /// Sets the height of a row in pixels.
    ///
    /// - `row = -1`: sets all rows to the given height.
    /// - `height = -1`: resets the row to the default height (removes custom override).
    /// - Otherwise stores a custom height for the given row.
    pub fn set_row_height(&mut self, row: i32, height: i32) {
        let height = if self.is_tui_mode() && height != -1 {
            DEFAULT_TUI_ROW_HEIGHT
        } else {
            height
        };
        if row == -1 {
            // Set all rows
            if height == -1 {
                // Reset all to default
                self.row_heights.clear();
            } else {
                let h = self.clamp_row_height(height);
                for r in 0..self.rows {
                    self.row_heights.insert(r, h);
                }
            }
        } else if row >= 0 && row < self.rows {
            if height == -1 {
                // Reset to default
                self.row_heights.remove(&row);
            } else {
                let h = self.clamp_row_height(height);
                self.row_heights.insert(row, h);
            }
        }
        self.layout.invalidate();
        self.dirty = true;
    }

    /// Clamps a row height to the configured min/max range.
    fn clamp_row_height(&self, height: i32) -> i32 {
        if self.is_tui_mode() {
            return if height <= 0 {
                0
            } else {
                DEFAULT_TUI_ROW_HEIGHT
            };
        }
        let mut h = height;
        if self.row_height_min > 0 && h < self.row_height_min {
            h = self.row_height_min;
        }
        if self.row_height_max > 0 && h > self.row_height_max {
            h = self.row_height_max;
        }
        h.max(0)
    }

    // ── Col Width ─────────────────────────────────────────────────────────

    /// Returns the width of the given column in pixels.
    ///
    /// If the column is hidden, returns 0. If the column has a custom width,
    /// returns that. Otherwise returns `default_col_width`.
    pub fn get_col_width(&self, col: i32) -> i32 {
        if col < 0 || col >= self.cols {
            return 0;
        }
        if self.cols_hidden.contains(&col) {
            return 0;
        }
        match self.col_widths.get(&col) {
            Some(&w) => self.clamp_col_width(col, w),
            None => self.clamp_col_width(col, self.default_col_width),
        }
    }

    /// Sets the width of a column in pixels.
    ///
    /// - `col = -1`: sets all columns to the given width.
    /// - `width = -1`: resets the column to the default width (removes custom override).
    /// - Otherwise stores a custom width for the given column.
    pub fn set_col_width(&mut self, col: i32, width: i32) {
        if col == -1 {
            // Set all columns
            if width == -1 {
                // Reset all to default
                self.col_widths.clear();
            } else {
                for c in 0..self.cols {
                    let w = self.clamp_col_width(c, width);
                    self.col_widths.insert(c, w);
                }
            }
        } else if col >= 0 && col < self.cols {
            if width == -1 {
                // Reset to default
                self.col_widths.remove(&col);
            } else {
                let w = self.clamp_col_width(col, width);
                self.col_widths.insert(col, w);
            }
        }
        self.layout.invalidate();
        self.dirty = true;
    }

    /// Clamps a column width to the configured per-column min/max range.
    pub fn clamp_col_width(&self, col: i32, width: i32) -> i32 {
        let mut w = width;
        if let Some(&min_w) = self.col_width_min.get(&col) {
            if min_w > 0 && w < min_w {
                w = min_w;
            }
        }
        if let Some(&max_w) = self.col_width_max.get(&col) {
            if max_w > 0 && w > max_w {
                w = max_w;
            }
        }
        w.max(0)
    }

    // ── Visibility ────────────────────────────────────────────────────────

    /// Returns `true` if the given row is visible (not hidden).
    pub fn is_row_visible(&self, row: i32) -> bool {
        if row < 0 || row >= self.rows {
            return false;
        }
        !self.rows_hidden.contains(&row)
    }

    /// Returns `true` if the given column is visible (not hidden).
    pub fn is_col_visible(&self, col: i32) -> bool {
        if col < 0 || col >= self.cols {
            return false;
        }
        !self.cols_hidden.contains(&col)
    }

    // ── Dirty / Redraw ────────────────────────────────────────────────────

    /// Marks the grid as dirty, requiring a re-render on the next frame.
    pub fn mark_dirty(&mut self) {
        self.dirty = true;
        self.text_meta_generation = self.text_meta_generation.wrapping_add(1);
    }

    /// Marks the grid as dirty without invalidating text/layout-derived caches.
    pub fn mark_dirty_visual(&mut self) {
        self.dirty = true;
    }

    pub fn tick_scrollbar_fade(&mut self, dt_seconds: f32) -> bool {
        if !self.animation.enabled {
            let visible_timer = if scrollbar_overlays_content(self.scrollbar_appearance) {
                (self.scrollbar_fade_delay_ms.max(0) as f32) / 1000.0
            } else {
                0.0
            };
            let changed = (self.scrollbar_fade_opacity - 1.0).abs() > f32::EPSILON
                || (self.scrollbar_fade_timer - visible_timer).abs() > f32::EPSILON
                || self.scrollbar_fade_last_tick.is_some();
            self.scrollbar_fade_opacity = 1.0;
            self.scrollbar_fade_timer = visible_timer;
            self.scrollbar_fade_last_tick = None;
            return changed;
        }

        let now = Instant::now();
        let changed = crate::input::tick_scrollbar_fade(self, dt_seconds);
        self.scrollbar_fade_last_tick = if scrollbar_fade_animating(self) {
            Some(now)
        } else {
            None
        };
        changed
    }

    fn tick_scrollbar_fade_animation(&mut self) -> bool {
        if !self.animation.enabled {
            let _ = self.tick_scrollbar_fade(0.0);
            return false;
        }
        if !scrollbar_fade_animating(self) {
            self.scrollbar_fade_last_tick = None;
            return false;
        }

        let now = Instant::now();
        let dt_seconds = self
            .scrollbar_fade_last_tick
            .map(|prev| now.duration_since(prev).as_secs_f32().min(1.0 / 20.0))
            .unwrap_or(0.0);

        self.tick_scrollbar_fade(dt_seconds)
    }

    /// Clear the dirty flag after rendering.
    /// Keeps dirty=true if an engine-driven visual animation is still in-flight
    /// so the host continues to re-render until the animation settles.
    pub fn clear_dirty(&mut self) {
        if (!self.is_tui_mode() && self.animation.active)
            || self.background_loading
            || (!self.is_tui_mode() && scrollbar_fade_animating(self))
            || self.pull_to_refresh_needs_frame()
        {
            self.dirty = true;
        } else {
            self.dirty = false;
        }
    }

    pub fn normalize_pull_to_refresh_theme(theme: i32) -> i32 {
        match theme {
            x if x == pb::PullToRefreshTheme::TopBand as i32 => x,
            x if x == pb::PullToRefreshTheme::Material as i32 => x,
            _ => pb::PullToRefreshTheme::TopBand as i32,
        }
    }

    pub fn pull_to_refresh_theme(&self) -> i32 {
        Self::normalize_pull_to_refresh_theme(self.pull_to_refresh_theme)
    }

    pub fn pull_to_refresh_threshold_px(&self) -> f32 {
        DEFAULT_PULL_TO_REFRESH_THRESHOLD_PX * self.scale.max(0.01)
    }

    pub fn pull_to_refresh_max_reveal_px(&self) -> f32 {
        DEFAULT_PULL_TO_REFRESH_MAX_REVEAL_PX * self.scale.max(0.01)
    }

    pub fn pull_to_refresh_touch_slop_px(&self) -> f32 {
        DEFAULT_PULL_TO_REFRESH_TOUCH_SLOP_PX * self.scale.max(0.01)
    }

    pub fn pull_to_refresh_cancel_snap_px(&self) -> f32 {
        DEFAULT_PULL_TO_REFRESH_CANCEL_SNAP_PX * self.scale.max(0.01)
    }

    pub fn pull_to_refresh_progress(&self) -> f32 {
        (self.pull_to_refresh_reveal_px / self.pull_to_refresh_threshold_px()).clamp(0.0, 1.0)
    }

    pub fn pull_to_refresh_label_pull(&self) -> &str {
        self.pull_to_refresh_text_pull
            .as_deref()
            .unwrap_or(DEFAULT_PULL_TO_REFRESH_TEXT_PULL)
    }

    pub fn pull_to_refresh_label_release(&self) -> &str {
        self.pull_to_refresh_text_release
            .as_deref()
            .unwrap_or(DEFAULT_PULL_TO_REFRESH_TEXT_RELEASE)
    }

    pub fn pull_to_refresh_is_visible(&self) -> bool {
        self.pull_to_refresh_reveal_px > f32::EPSILON
            || matches!(self.pull_to_refresh_state, PullToRefreshState::Settling)
    }

    pub fn pull_to_refresh_needs_frame(&self) -> bool {
        (self.pull_to_refresh_reveal_px - self.pull_to_refresh_target_reveal_px).abs() > 0.5
            || matches!(self.pull_to_refresh_state, PullToRefreshState::Settling)
    }

    fn reset_pull_to_refresh_contact_tracking(&mut self) {
        self.pull_to_refresh_contact_active = false;
        self.pull_to_refresh_drag_accum_x_px = 0.0;
        self.pull_to_refresh_drag_accum_y_px = 0.0;
        self.pull_to_refresh_had_reveal = false;
    }

    fn settle_pull_to_refresh_to(&mut self, target_px: f32, next_state: PullToRefreshState) {
        self.pull_to_refresh_target_reveal_px =
            target_px.clamp(0.0, self.pull_to_refresh_max_reveal_px());
        self.pull_to_refresh_state = next_state;
        self.mark_dirty_visual();
    }

    fn update_pull_to_refresh_visual_state(&mut self) {
        if self.pull_to_refresh_reveal_px <= f32::EPSILON {
            self.pull_to_refresh_reveal_px = 0.0;
            if !self.pull_to_refresh_contact_active {
                self.pull_to_refresh_target_reveal_px = 0.0;
                self.pull_to_refresh_state = PullToRefreshState::Idle;
            } else {
                self.pull_to_refresh_state = PullToRefreshState::Pulling;
            }
            return;
        }
        self.pull_to_refresh_state =
            if self.pull_to_refresh_reveal_px >= self.pull_to_refresh_threshold_px() {
                PullToRefreshState::Armed
            } else {
                PullToRefreshState::Pulling
            };
    }

    pub fn begin_pull_to_refresh_contact(&mut self) {
        if !self.pull_to_refresh_enabled {
            return;
        }
        self.pull_to_refresh_contact_active = true;
        self.pull_to_refresh_drag_accum_x_px = 0.0;
        self.pull_to_refresh_drag_accum_y_px = 0.0;
        self.pull_to_refresh_had_reveal = false;
    }

    pub fn cancel_pull_to_refresh_contact(&mut self, emit_cancel_event: bool) {
        let should_emit = emit_cancel_event && self.pull_to_refresh_had_reveal;
        self.reset_pull_to_refresh_contact_tracking();
        if should_emit {
            self.events
                .push(crate::event::GridEventData::PullToRefreshCanceled);
        }
        self.pull_to_refresh_target_reveal_px = 0.0;
        if self.pull_to_refresh_reveal_px <= self.pull_to_refresh_cancel_snap_px() {
            self.pull_to_refresh_reveal_px = 0.0;
            self.pull_to_refresh_target_reveal_px = 0.0;
            self.pull_to_refresh_state = PullToRefreshState::Idle;
        } else {
            self.pull_to_refresh_state = PullToRefreshState::Settling;
        }
        self.mark_dirty_visual();
    }

    pub fn end_pull_to_refresh_contact(&mut self) {
        if !self.pull_to_refresh_enabled {
            return;
        }
        self.pull_to_refresh_contact_active = false;
        self.pull_to_refresh_drag_accum_x_px = 0.0;
        self.pull_to_refresh_drag_accum_y_px = 0.0;
        match self.pull_to_refresh_state {
            PullToRefreshState::Armed => {
                self.pull_to_refresh_had_reveal = false;
                self.events
                    .push(crate::event::GridEventData::PullToRefreshTriggered);
                self.settle_pull_to_refresh_to(0.0, PullToRefreshState::Settling);
            }
            PullToRefreshState::Pulling => {
                let should_emit = self.pull_to_refresh_had_reveal;
                self.pull_to_refresh_had_reveal = false;
                if should_emit {
                    self.events
                        .push(crate::event::GridEventData::PullToRefreshCanceled);
                }
                // Not armed — snap to invisible immediately (no settle animation).
                self.pull_to_refresh_reveal_px = 0.0;
                self.pull_to_refresh_target_reveal_px = 0.0;
                self.pull_to_refresh_state = PullToRefreshState::Idle;
            }
            PullToRefreshState::Settling => {
                self.pull_to_refresh_had_reveal = false;
            }
            PullToRefreshState::Idle => {
                self.pull_to_refresh_had_reveal = false;
            }
        }
        self.mark_dirty_visual();
    }

    pub fn handle_pull_to_refresh_scroll(&mut self, dx_px: f32, dy_px: f32) -> bool {
        if !self.pull_to_refresh_enabled
            || !self.pull_to_refresh_contact_active
            || self.fast_scroll_active
            || self.scrollbar_drag_active
        {
            return false;
        }
        if matches!(self.pull_to_refresh_state, PullToRefreshState::Settling)
            && self.pull_to_refresh_reveal_px > f32::EPSILON
        {
            return true;
        }

        let was_revealed = self.pull_to_refresh_reveal_px > f32::EPSILON;
        self.pull_to_refresh_drag_accum_x_px += dx_px.abs();
        self.pull_to_refresh_drag_accum_y_px += dy_px.abs();

        if !was_revealed {
            let slop = self.pull_to_refresh_touch_slop_px();
            if self.pull_to_refresh_drag_accum_y_px < slop
                && self.pull_to_refresh_drag_accum_x_px < slop
            {
                return false;
            }
            let vertical_dominant =
                self.pull_to_refresh_drag_accum_y_px >= self.pull_to_refresh_drag_accum_x_px * 1.15;
            if !vertical_dominant || self.scroll.scroll_y > 0.5 || dy_px >= 0.0 {
                return false;
            }
        }

        let mut next_reveal = self.pull_to_refresh_reveal_px;
        if dy_px < 0.0 {
            let pull_delta = -dy_px;
            let resistance =
                (1.0 - (next_reveal / self.pull_to_refresh_max_reveal_px()) * 0.7).clamp(0.2, 1.0);
            next_reveal = (next_reveal + pull_delta * resistance)
                .clamp(0.0, self.pull_to_refresh_max_reveal_px());
        } else if dy_px > 0.0 && next_reveal > 0.0 {
            next_reveal = (next_reveal - dy_px).max(0.0);
        }

        let changed = (next_reveal - self.pull_to_refresh_reveal_px).abs() > f32::EPSILON;
        self.pull_to_refresh_reveal_px = next_reveal;
        self.pull_to_refresh_target_reveal_px = next_reveal;
        if self.pull_to_refresh_reveal_px > f32::EPSILON {
            self.pull_to_refresh_had_reveal = true;
        }
        self.update_pull_to_refresh_visual_state();
        if changed {
            self.mark_dirty_visual();
        }
        changed || was_revealed || self.pull_to_refresh_reveal_px > f32::EPSILON
    }

    pub fn tick_pull_to_refresh(&mut self, dt_seconds: f32) -> bool {
        if !dt_seconds.is_finite() || dt_seconds <= 0.0 {
            return false;
        }
        let prev_reveal = self.pull_to_refresh_reveal_px;
        let target = self.pull_to_refresh_target_reveal_px;
        let delta = target - self.pull_to_refresh_reveal_px;
        if delta.abs() > 0.5 {
            let step =
                DEFAULT_PULL_TO_REFRESH_SETTLE_SPEED_PX_PER_SEC * self.scale.max(0.01) * dt_seconds;
            if delta.abs() <= step {
                self.pull_to_refresh_reveal_px = target;
            } else {
                self.pull_to_refresh_reveal_px += step.copysign(delta);
            }
        } else if self.pull_to_refresh_reveal_px != target {
            self.pull_to_refresh_reveal_px = target;
        }

        if matches!(self.pull_to_refresh_state, PullToRefreshState::Settling)
            && self.pull_to_refresh_reveal_px <= 0.5
            && !self.pull_to_refresh_contact_active
        {
            self.pull_to_refresh_reveal_px = 0.0;
            self.pull_to_refresh_target_reveal_px = 0.0;
            self.pull_to_refresh_state = PullToRefreshState::Idle;
        } else if matches!(
            self.pull_to_refresh_state,
            PullToRefreshState::Pulling | PullToRefreshState::Armed
        ) {
            self.update_pull_to_refresh_visual_state();
        }

        (self.pull_to_refresh_reveal_px - prev_reveal).abs() > f32::EPSILON
    }

    // ── Viewport ──────────────────────────────────────────────────────────

    /// Resizes the viewport to the given pixel dimensions and invalidates
    /// the layout cache.
    pub fn resize_viewport(&mut self, width: i32, height: i32) {
        self.viewport_width = width.max(0);
        self.viewport_height = height.max(0);
        // No layout.invalidate() — row/col positions haven't changed.
        // Only scroll bounds depend on viewport size; they are recomputed
        // on the next ensure_layout call (which is cheap when layout is
        // already valid — it just calls update_bounds).
        self.dirty = true;
    }

    pub fn is_tui_mode(&self) -> bool {
        self.tui_mode || self.renderer_mode == pb::RendererMode::RendererTui as i32
    }

    pub fn effective_engine_compose_enabled(&self) -> bool {
        if self.engine_compose_configured {
            self.engine_compose
        } else {
            self.is_tui_mode()
        }
    }

    pub fn effective_compose_method(&self) -> i32 {
        if self.compose_method_configured {
            self.compose_method
        } else if self.is_tui_mode() {
            pb::ComposeMethod::DeadKey as i32
        } else {
            self.compose_method
        }
    }

    fn apply_tui_mode_defaults(&mut self) {
        self.default_row_height = DEFAULT_TUI_ROW_HEIGHT;
        if self.default_col_width <= 0 || self.default_col_width == DEFAULT_COL_WIDTH {
            self.default_col_width = DEFAULT_TUI_COL_WIDTH;
        }
        self.animation.clear();
        self.animation.enabled = false;
        self.fling_enabled = false;
        self.scroll.stop_fling();
        self.pinch_zoom_enabled = false;
        self.scrollbar_show_h = pb::ScrollBarMode::ScrollbarModeNever as i32;
        if self.scrollbar_show_v == pb::ScrollBarMode::ScrollbarModeNever as i32 {
            self.scrollbar_show_v = pb::ScrollBarMode::ScrollbarModeAuto as i32;
        }
        self.normalize_scroll_for_mode();
    }

    pub fn set_renderer_mode(&mut self, mode: i32) {
        self.renderer_mode = mode;
        let enable_tui = mode == pb::RendererMode::RendererTui as i32;
        if self.tui_mode == enable_tui {
            if enable_tui {
                self.apply_tui_mode_defaults();
            }
            return;
        }

        self.tui_mode = enable_tui;
        if enable_tui {
            self.apply_tui_mode_defaults();
        }
        reset_scrollbar_fade_state(self);
        self.layout.invalidate();
        self.mark_dirty();
    }

    pub fn normalize_scroll_for_mode(&mut self) {
        if self.is_tui_mode() {
            self.scroll.quantize_to_cells();
        }
    }

    fn tui_text_width(text: &str) -> i32 {
        let width = UnicodeWidthStr::width(text);
        if width > i32::MAX as usize {
            i32::MAX
        } else {
            width as i32
        }
    }

    // ── Computed Helpers ──────────────────────────────────────────────────

    /// Returns the total content height in pixels (sum of all visible row heights).
    pub fn total_height(&self) -> i32 {
        let mut h = 0i32;
        for r in 0..self.rows {
            h = h.saturating_add(self.get_row_height(r));
        }
        h
    }

    /// Returns the total content width in pixels (sum of all visible column widths).
    pub fn total_width(&self) -> i32 {
        let mut w = 0i32;
        for c in 0..self.cols {
            w = w.saturating_add(self.get_col_width(c));
        }
        w
    }

    /// Returns the combined pixel height of all fixed rows.
    pub fn fixed_height(&self) -> i32 {
        let mut h = 0i32;
        for r in 0..self.fixed_rows {
            h = h.saturating_add(self.get_row_height(r));
        }
        h
    }

    /// Returns the combined pixel width of all fixed columns.
    pub fn fixed_width(&self) -> i32 {
        let mut w = 0i32;
        for c in 0..self.fixed_cols {
            w = w.saturating_add(self.get_col_width(c));
        }
        w
    }

    /// Returns the combined pixel height of all frozen rows (below fixed rows).
    pub fn frozen_height(&self) -> i32 {
        let mut h = 0i32;
        for r in self.fixed_rows..(self.fixed_rows + self.frozen_rows).min(self.rows) {
            h = h.saturating_add(self.get_row_height(r));
        }
        h
    }

    /// Returns the combined pixel width of all frozen columns (right of fixed columns).
    pub fn frozen_width(&self) -> i32 {
        let mut w = 0i32;
        for c in self.fixed_cols..(self.fixed_cols + self.frozen_cols).min(self.cols) {
            w = w.saturating_add(self.get_col_width(c));
        }
        w
    }

    /// Returns the logical row index at the given display position.
    /// Returns -1 if the position is out of range.
    pub fn row_at_position(&self, display_pos: i32) -> i32 {
        if display_pos < 0 || display_pos >= self.rows {
            return -1;
        }
        self.row_positions
            .get(display_pos as usize)
            .copied()
            .unwrap_or(-1)
    }

    /// Returns the logical column index at the given display position.
    /// Returns -1 if the position is out of range.
    pub fn col_at_position(&self, display_pos: i32) -> i32 {
        if display_pos < 0 || display_pos >= self.cols {
            return -1;
        }
        self.col_positions
            .get(display_pos as usize)
            .copied()
            .unwrap_or(-1)
    }

    /// Returns the display position for the given logical row index.
    /// Returns -1 if the row is not found in the position mapping.
    pub fn row_display_position(&self, logical_row: i32) -> i32 {
        self.row_positions
            .iter()
            .position(|&r| r == logical_row)
            .map(|p| p as i32)
            .unwrap_or(-1)
    }

    /// Returns the display position for the given logical column index.
    /// Returns -1 if the column is not found in the position mapping.
    pub fn col_display_position(&self, logical_col: i32) -> i32 {
        self.col_positions
            .iter()
            .position(|&c| c == logical_col)
            .map(|p| p as i32)
            .unwrap_or(-1)
    }

    /// Remap a display-position indexed column key after a remove+insert move.
    ///
    /// `source_pos` and `insert_pos` are display positions in the same index
    /// space used by `Vec::remove` + `Vec::insert`.
    pub fn remap_col_index_for_move(index: i32, source_pos: i32, insert_pos: i32) -> i32 {
        if index < 0 || source_pos == insert_pos {
            return index;
        }
        if index == source_pos {
            return insert_pos;
        }
        if source_pos < insert_pos {
            if index > source_pos && index <= insert_pos {
                return index - 1;
            }
            return index;
        }
        if index >= insert_pos && index < source_pos {
            return index + 1;
        }
        index
    }

    /// Re-map span column flags after a display-position column move.
    ///
    /// This keeps `span.span_cols` aligned with user-visible column order,
    /// so merged ranges are recalculated against the moved layout.
    pub fn remap_span_cols_after_move(&mut self, source_pos: i32, insert_pos: i32) {
        if source_pos == insert_pos {
            return;
        }
        let old = std::mem::take(&mut self.span.span_cols);
        let mut remapped = std::collections::HashMap::new();
        for (col, enabled) in old {
            if col < 0 {
                remapped.insert(col, enabled);
            } else {
                let mapped = Self::remap_col_index_for_move(col, source_pos, insert_pos);
                remapped.insert(mapped, enabled);
            }
        }
        self.span.span_cols = remapped;
    }

    fn remap_i32_key_map_after_col_move<V>(
        map: &mut std::collections::HashMap<i32, V>,
        source_pos: i32,
        insert_pos: i32,
    ) {
        if source_pos == insert_pos {
            return;
        }
        let old = std::mem::take(map);
        let mut remapped = std::collections::HashMap::with_capacity(old.len());
        for (k, v) in old {
            remapped.insert(Self::remap_col_index_for_move(k, source_pos, insert_pos), v);
        }
        *map = remapped;
    }

    fn remap_i32_key_set_after_col_move(
        set: &mut std::collections::HashSet<i32>,
        source_pos: i32,
        insert_pos: i32,
    ) {
        if source_pos == insert_pos {
            return;
        }
        let old = std::mem::take(set);
        let mut remapped = std::collections::HashSet::with_capacity(old.len());
        for k in old {
            remapped.insert(Self::remap_col_index_for_move(k, source_pos, insert_pos));
        }
        *set = remapped;
    }

    /// Apply a visual column move by physically reordering column-indexed state.
    ///
    /// `source_pos` and `insert_pos` are display positions in the same index
    /// space used by `Vec::remove` + `Vec::insert`.
    pub fn move_col_by_positions(&mut self, source_pos: i32, insert_pos: i32) -> bool {
        if self.cols <= 0 || source_pos < 0 || source_pos >= self.cols {
            return false;
        }
        if insert_pos < 0 || insert_pos >= self.cols {
            return false;
        }
        if source_pos == insert_pos {
            return false;
        }

        let sp = source_pos as usize;
        let ip = insert_pos as usize;

        // Column metadata vec.
        if sp < self.columns.len() && ip <= self.columns.len() {
            let col_meta = self.columns.remove(sp);
            self.columns.insert(ip, col_meta);
        }

        // O(cols) col_map update instead of O(cells) physical remap.
        let num_cols = self.cols.max(0) as usize;
        if self.cells.col_map_is_empty() {
            self.cells.set_col_map((0..num_cols as i32).collect());
        }
        let val = self.cells.col_map_remove(sp);
        self.cells.col_map_insert(ip, val);
        Self::remap_i32_key_map_after_col_move(&mut self.col_widths, source_pos, insert_pos);
        Self::remap_i32_key_map_after_col_move(&mut self.col_width_min, source_pos, insert_pos);
        Self::remap_i32_key_map_after_col_move(&mut self.col_width_max, source_pos, insert_pos);
        Self::remap_i32_key_set_after_col_move(&mut self.cols_hidden, source_pos, insert_pos);
        self.remap_span_cols_after_move(source_pos, insert_pos);

        let old_styles = std::mem::take(&mut self.cell_styles);
        let mut remapped_styles = std::collections::HashMap::with_capacity(old_styles.len());
        for ((row, col), style) in old_styles {
            let mapped_col = Self::remap_col_index_for_move(col, source_pos, insert_pos);
            remapped_styles.insert((row, mapped_col), style);
        }
        self.cell_styles = remapped_styles;

        // Remap active cursor/editor/sort references.
        self.selection.col =
            Self::remap_col_index_for_move(self.selection.col, source_pos, insert_pos);
        self.selection.col_end =
            Self::remap_col_index_for_move(self.selection.col_end, source_pos, insert_pos);
        for range in &mut self.selection.extra_ranges {
            range.1 = Self::remap_col_index_for_move(range.1, source_pos, insert_pos);
            range.3 = Self::remap_col_index_for_move(range.3, source_pos, insert_pos);
            if range.1 > range.3 {
                std::mem::swap(&mut range.1, &mut range.3);
            }
        }
        self.mouse_col = Self::remap_col_index_for_move(self.mouse_col, source_pos, insert_pos);
        if self.resize_active && self.resize_is_col {
            self.resize_index =
                Self::remap_col_index_for_move(self.resize_index, source_pos, insert_pos);
        }
        if self.edit.is_active() {
            self.edit.edit_col =
                Self::remap_col_index_for_move(self.edit.edit_col, source_pos, insert_pos);
        }
        for key in self.sort_state.sort_keys.iter_mut() {
            key.0 = Self::remap_col_index_for_move(key.0, source_pos, insert_pos);
        }

        // Keep display mapping canonical after physical reorder.
        self.col_positions.clear();
        self.col_positions.extend(0..self.cols);

        self.layout.invalidate();
        self.mark_dirty();
        true
    }

    /// Returns the pixel Y-offset of the top edge of the given row,
    /// computed by summing the heights of all preceding rows in display order.
    pub fn row_pixel_offset(&self, row: i32) -> i32 {
        let mut y = 0i32;
        for pos in 0..row.min(self.rows) {
            let logical = self.row_at_position(pos);
            if logical >= 0 {
                y = y.saturating_add(self.get_row_height(logical));
            }
        }
        y
    }

    /// Returns the pixel X-offset of the left edge of the given column,
    /// computed by summing the widths of all preceding columns in display order.
    pub fn col_pixel_offset(&self, col: i32) -> i32 {
        let mut x = 0i32;
        for pos in 0..col.min(self.cols) {
            let logical = self.col_at_position(pos);
            if logical >= 0 {
                x = x.saturating_add(self.get_col_width(logical));
            }
        }
        x
    }

    /// Returns the first scrollable row index (fixed_rows + frozen_rows).
    pub fn first_scrollable_row(&self) -> i32 {
        (self.fixed_rows + self.frozen_rows).min(self.rows)
    }

    /// Returns the first scrollable column index (fixed_cols + frozen_cols).
    pub fn first_scrollable_col(&self) -> i32 {
        (self.fixed_cols + self.frozen_cols).min(self.cols)
    }

    /// Returns true if the grid is currently being edited.
    pub fn is_editing(&self) -> bool {
        self.edit.is_active()
    }

    /// Returns true when editing may begin at the given cell.
    ///
    /// Header rows and subtotal/grandtotal rows are always read-only.
    /// `force=true` bypasses only the global `edit_trigger_mode` gate.
    pub fn resolved_cell_interaction(&self, row: i32, col: i32) -> i32 {
        if row < 0 || row >= self.rows || col < 0 || col >= self.cols {
            return pb::CellInteraction::None as i32;
        }
        if let Some(cell) = self.cells.get(row, col) {
            if let Some(interaction) = cell.interaction_override() {
                return interaction;
            }
        }
        match self.get_col_props(col).map_or(0, |cp| cp.interaction) {
            x if x <= pb::CellInteraction::Unspecified as i32 => pb::CellInteraction::None as i32,
            x => x,
        }
    }

    pub fn resolved_cell_control(&self, row: i32, col: i32) -> CellControl {
        if row < 0 || row >= self.rows || col < 0 || col >= self.cols {
            return CellControl::None;
        }
        if let Some(cell) = self.cells.get(row, col) {
            if let Some(control) = cell.control_override() {
                return control;
            }
        }
        if let Some(control) = self.get_col_props(col).map(|cp| cp.control) {
            if control != CellControl::None {
                return control;
            }
        }
        if !self.active_dropdown_list(row, col).is_empty() {
            return CellControl::DropdownButton;
        }
        CellControl::None
    }

    pub fn can_begin_edit(&self, row: i32, col: i32, force: bool) -> bool {
        if row < 0 || row >= self.rows || col < 0 || col >= self.cols {
            return false;
        }
        if row < self.fixed_rows {
            return false;
        }
        if self.row_props.get(&row).map_or(false, |rp| rp.is_subtotal) {
            return false;
        }
        if self.resolved_cell_interaction(row, col) != pb::CellInteraction::None as i32 {
            return false;
        }
        if !force && self.edit_trigger_mode <= 0 {
            return false;
        }
        true
    }

    /// Ensures the text engine is initialized and returns a mutable reference to it.
    pub fn ensure_text_engine(&mut self) -> &mut TextEngine {
        if self.text_engine.is_none() {
            let mut te = TextEngine::new();
            te.set_layout_cache_cap(self.text_layout_cache_cap);
            self.text_engine = Some(te);
        }
        self.text_engine.as_mut().unwrap()
    }

    pub fn set_text_layout_cache_cap(&mut self, cap: i32) {
        let cap = cap.max(0) as usize;
        self.text_layout_cache_cap = cap;
        if let Some(te) = &mut self.text_engine {
            te.set_layout_cache_cap(cap);
        }
    }

    pub(crate) fn build_text_cell_static_meta(
        &self,
        row: i32,
        col: i32,
    ) -> Arc<TextCellStaticMeta> {
        {
            let mut cache = self.text_meta_cache.borrow_mut();
            if cache.0 != self.text_meta_generation {
                cache.1.clear();
                cache.0 = self.text_meta_generation;
            }
            if let Some(cached) = cache.1.get(&(row, col)) {
                return cached.clone();
            }
        }

        let display_text = self.get_display_text(row, col);
        let style_override = Arc::new(self.get_cell_style(row, col));
        let padding = self.resolve_cell_padding(row, col, style_override.as_ref());
        let alignment = crate::canvas::resolve_alignment(
            self,
            row,
            col,
            style_override.as_ref(),
            &display_text,
        );
        let has_dropdown_list = matches!(
            self.resolved_cell_control(row, col),
            CellControl::DropdownButton | CellControl::EllipsisButton
        );
        let suppress_text = self.get_col_props(col).map_or(false, |cp| {
            cp.data_type == pb::ColumnDataType::ColumnDataBoolean as i32 && row >= self.fixed_rows
        });

        let result = Arc::new(TextCellStaticMeta {
            display_text: Arc::<str>::from(display_text),
            style_override: style_override.clone(),
            padding,
            alignment,
            has_dropdown_list,
            suppress_text,
            shrink_to_fit: style_override.shrink_to_fit.unwrap_or(false),
        });
        self.text_meta_cache
            .borrow_mut()
            .1
            .insert((row, col), result.clone());
        result
    }

    // ── Convenience Accessors (used by render, input, etc.) ─────────────

    /// Pixel Y-offset of a row from the layout cache.
    pub fn row_pos(&self, row: i32) -> i32 {
        self.layout.row_pos(row)
    }

    /// Pixel X-offset of a column from the layout cache.
    pub fn col_pos(&self, col: i32) -> i32 {
        self.layout.col_pos(col)
    }

    /// Alias for `get_row_height` — used extensively by the renderer.
    pub fn row_height(&self, row: i32) -> i32 {
        self.get_row_height(row)
    }

    /// Alias for `get_col_width` — used extensively by the renderer.
    pub fn col_width(&self, col: i32) -> i32 {
        self.get_col_width(col)
    }

    pub fn indicator_start_width(&self) -> i32 {
        self.indicator_bands.start_width()
    }

    pub fn indicator_end_width(&self) -> i32 {
        self.indicator_bands.end_width()
    }

    pub fn indicator_top_height(&self) -> i32 {
        self.indicator_bands.top_height()
    }

    pub fn indicator_bottom_height(&self) -> i32 {
        self.indicator_bands.bottom_height()
    }

    pub fn data_viewport_width(&self) -> i32 {
        (self.viewport_width - self.indicator_start_width() - self.indicator_end_width()).max(1)
    }

    pub fn data_viewport_height(&self) -> i32 {
        (self.viewport_height - self.indicator_top_height() - self.indicator_bottom_height()).max(1)
    }

    /// Returns true if the row is hidden.
    pub fn is_row_hidden(&self, row: i32) -> bool {
        self.rows_hidden.contains(&row)
    }

    /// Returns true if the column is hidden.
    pub fn is_col_hidden(&self, col: i32) -> bool {
        self.cols_hidden.contains(&col)
    }

    /// Returns the last visible column index, if any.
    pub fn last_visible_col_index(&self) -> Option<i32> {
        (0..self.cols).rev().find(|&col| !self.is_col_hidden(col))
    }

    /// Returns the nearest visible column at or before `col`, if any.
    pub fn visible_col_at_or_before(&self, col: i32) -> Option<i32> {
        let upper = col.min(self.cols - 1);
        (0..=upper).rev().find(|&idx| !self.is_col_hidden(idx))
    }

    /// Returns the column properties for a column, if it exists.
    pub fn get_col_props(&self, col: i32) -> Option<&ColumnProps> {
        if col < 0 || col >= self.cols {
            return None;
        }
        self.columns.get(col as usize)
    }

    /// Returns the row properties for a row, if it exists.
    pub fn get_row_props(&self, row: i32) -> Option<&RowProps> {
        self.row_props.get(&row)
    }

    /// Returns mutable row properties for a row, creating defaults as needed.
    pub fn row_props_mut(&mut self, row: i32) -> Option<&mut RowProps> {
        if row < 0 || row >= self.rows {
            return None;
        }
        Some(self.row_props.entry(row).or_default())
    }

    /// Returns user-defined row data (`RowData`), if present.
    pub fn get_row_data(&self, row: i32) -> Option<Vec<u8>> {
        self.get_row_props(row).and_then(|rp| rp.user_data.clone())
    }

    /// Sets user-defined row data (`RowData`).
    ///
    /// Passing `None` clears the row data.
    pub fn set_row_data(&mut self, row: i32, data: Option<Vec<u8>>) {
        let Some(props) = self.row_props_mut(row) else {
            return;
        };
        props.user_data = data;
    }

    /// Returns row status (`RowStatus`), defaulting to 0.
    pub fn get_row_status(&self, row: i32) -> i32 {
        self.get_row_props(row).map_or(0, |rp| rp.status)
    }

    /// Sets row status (`RowStatus`).
    pub fn set_row_status(&mut self, row: i32, status: i32) {
        let Some(props) = self.row_props_mut(row) else {
            return;
        };
        props.status = status;
    }

    // ── Pin & Sticky Helpers ─────────────────────────────────────────────

    /// Pin a row to the top or bottom section, or unpin it.
    ///
    /// Pinned rows are removed from the scrollable area and always visible.
    /// `pin` values: 0=none, 1=top, 2=bottom (matches PinPosition enum).
    pub fn pin_row(&mut self, row: i32, pin: i32) {
        if row < 0 || row >= self.rows {
            return;
        }
        // Remove from both lists first
        self.pinned_rows_top.retain(|&r| r != row);
        self.pinned_rows_bottom.retain(|&r| r != row);
        // Insert into appropriate sorted list
        match pin {
            1 => {
                let pos = self.pinned_rows_top.partition_point(|&r| r < row);
                self.pinned_rows_top.insert(pos, row);
            }
            2 => {
                let pos = self.pinned_rows_bottom.partition_point(|&r| r < row);
                self.pinned_rows_bottom.insert(pos, row);
            }
            _ => {} // 0 = unpin, already removed
        }
        // Persist in row props
        let rp = self.row_props.entry(row).or_default();
        rp.pin = pin;
        self.layout.invalidate();
        self.mark_dirty();
    }

    /// Check if a row is pinned and return its position.
    pub fn is_row_pinned(&self, row: i32) -> i32 {
        self.get_row_props(row).map_or(0, |rp| rp.pin)
    }

    /// Pin a column to the left or right section, or unpin it.
    ///
    /// Pinned columns are removed from the horizontal scrollable layout and
    /// always rendered in edge sections.
    /// `pin` values: 0=none, 1=left, 2=right.
    pub fn pin_col(&mut self, col: i32, pin: i32) {
        if col < 0 || col >= self.cols {
            return;
        }
        self.pinned_cols_left.retain(|&c| c != col);
        self.pinned_cols_right.retain(|&c| c != col);
        match pin {
            1 => {
                let pos = self.pinned_cols_left.partition_point(|&c| c < col);
                self.pinned_cols_left.insert(pos, col);
            }
            2 => {
                let pos = self.pinned_cols_right.partition_point(|&c| c < col);
                self.pinned_cols_right.insert(pos, col);
            }
            _ => {}
        }
        self.layout.invalidate();
        self.mark_dirty();
    }

    /// Check if a column is pinned and return its position.
    pub fn is_col_pinned(&self, col: i32) -> i32 {
        if self.pinned_cols_left.binary_search(&col).is_ok() {
            1
        } else if self.pinned_cols_right.binary_search(&col).is_ok() {
            2
        } else {
            0
        }
    }

    /// Set the sticky edge for a row (0=none, 1=TOP, 2=BOTTOM, 5=BOTH).
    pub fn set_row_sticky(&mut self, row: i32, edge: i32) {
        if edge == 0 {
            self.sticky_rows.remove(&row);
        } else {
            self.sticky_rows.insert(row, edge);
        }
        self.mark_dirty();
    }

    /// Set the sticky edge for a column (0=none, 3=LEFT, 4=RIGHT, 5=BOTH).
    pub fn set_col_sticky(&mut self, col: i32, edge: i32) {
        if edge == 0 {
            self.sticky_cols.remove(&col);
        } else {
            self.sticky_cols.insert(col, edge);
        }
        self.mark_dirty();
    }

    /// Set cell-level sticky overrides. Both edges 0 removes the override.
    pub fn set_cell_sticky(&mut self, row: i32, col: i32, sticky_row: i32, sticky_col: i32) {
        if sticky_row == 0 && sticky_col == 0 {
            self.sticky_cells.remove(&(row, col));
        } else {
            self.sticky_cells
                .insert((row, col), (sticky_row, sticky_col));
        }
        self.mark_dirty();
    }

    /// Effective sticky edge for a row at a given column.
    /// Cell override → row default → 0 (none).
    pub fn effective_sticky_row(&self, row: i32, col: i32) -> i32 {
        if let Some(&(sr, _)) = self.sticky_cells.get(&(row, col)) {
            if sr != 0 {
                return sr;
            }
        }
        self.sticky_rows.get(&row).copied().unwrap_or(0)
    }

    /// Effective sticky edge for a column at a given row.
    /// Cell override → column default → 0 (none).
    pub fn effective_sticky_col(&self, row: i32, col: i32) -> i32 {
        if let Some(&(_, sc)) = self.sticky_cells.get(&(row, col)) {
            if sc != 0 {
                return sc;
            }
        }
        self.sticky_cols.get(&col).copied().unwrap_or(0)
    }

    /// Total pixel height of top-pinned rows.
    pub fn pinned_top_height(&self) -> i32 {
        self.pinned_rows_top
            .iter()
            .map(|&r| self.row_height(r))
            .sum()
    }

    /// Total pixel height of bottom-pinned rows.
    pub fn pinned_bottom_height(&self) -> i32 {
        self.pinned_rows_bottom
            .iter()
            .map(|&r| self.row_height(r))
            .sum()
    }

    /// Total pixel width of left-pinned columns.
    pub fn pinned_left_width(&self) -> i32 {
        self.pinned_cols_left
            .iter()
            .map(|&c| self.col_width(c))
            .sum()
    }

    /// Total pixel width of right-pinned columns.
    pub fn pinned_right_width(&self) -> i32 {
        self.pinned_cols_right
            .iter()
            .map(|&c| self.col_width(c))
            .sum()
    }

    /// Resolve `TextArray` linear index into `(row, col)`.
    pub fn text_array_index_to_row_col(&self, index: i32) -> Option<(i32, i32)> {
        if index < 0 || self.cols <= 0 {
            return None;
        }
        let row = index / self.cols;
        let col = index % self.cols;
        if row < 0 || row >= self.rows || col < 0 || col >= self.cols {
            None
        } else {
            Some((row, col))
        }
    }

    /// Returns cell text via `TextArray` linear index.
    pub fn get_text_array(&self, index: i32) -> String {
        self.text_array_index_to_row_col(index)
            .map(|(row, col)| self.cells.get_text(row, col).to_string())
            .unwrap_or_default()
    }

    /// Sets cell text via `TextArray` linear index.
    pub fn set_text_array(&mut self, index: i32, text: String) {
        let Some((row, col)) = self.text_array_index_to_row_col(index) else {
            return;
        };
        self.cells.set_text(row, col, text);
        self.mark_dirty();
    }

    /// Returns the cell style override for a cell, or a default if none.
    pub fn get_cell_style(&self, row: i32, col: i32) -> CellStylePatch {
        self.cell_styles
            .get(&(row, col))
            .cloned()
            .unwrap_or_default()
    }

    /// Resolve effective insets for a cell.
    ///
    /// Priority: cell style override > column override > grid style default.
    pub fn resolve_cell_padding(
        &self,
        row: i32,
        col: i32,
        style_override: &CellStylePatch,
    ) -> Padding {
        if let Some(p) = style_override.padding {
            return p.clamped_non_negative();
        }
        let is_fixed = row < self.fixed_rows || col < self.fixed_cols;
        self.resolve_column_padding(col, is_fixed)
    }

    /// Resolve column/grid padding defaults, without per-cell overrides.
    pub fn resolve_column_padding(&self, col: i32, is_fixed: bool) -> Padding {
        let mut padding = if is_fixed {
            self.style.fixed_cell_padding
        } else {
            self.style.cell_padding
        };
        if col >= 0 && (col as usize) < self.columns.len() {
            let cp = &self.columns[col as usize];
            if is_fixed {
                if let Some(v) = cp.fixed_cell_padding {
                    padding = v;
                } else if let Some(v) = cp.cell_padding {
                    padding = v;
                }
            } else if let Some(v) = cp.cell_padding {
                padding = v;
            }
        }
        padding.clamped_non_negative()
    }

    /// Resolve the configured dropdown list for a cell without applying editability rules.
    ///
    /// Cell-level dropdown list has priority over the column-level list.
    pub fn configured_dropdown_list(&self, row: i32, col: i32) -> String {
        if let Some(cell) = self.cells.get(row, col) {
            let cl = cell.dropdown_items();
            if !cl.is_empty() {
                return cl.to_string();
            }
        }
        if col >= 0 && (col as usize) < self.columns.len() {
            return self.columns[col as usize].dropdown_items.clone();
        }
        String::new()
    }

    fn resolve_text_measure_style<'a>(&'a self, row: i32, col: i32) -> (&'a str, f32, bool, bool) {
        let style_override = self.cell_styles.get(&(row, col));
        let font_name = style_override
            .and_then(|style| style.font_name.as_deref())
            .unwrap_or(&self.style.font_name);
        let font_size = style_override
            .and_then(|style| style.font_size)
            .unwrap_or(self.style.font_size);
        let font_bold = style_override
            .and_then(|style| style.font_bold)
            .unwrap_or(self.style.font_bold);
        let font_italic = style_override
            .and_then(|style| style.font_italic)
            .unwrap_or(self.style.font_italic);
        let font_size = if font_size > 0.0 { font_size } else { 13.0 };
        (font_name, font_size, font_bold, font_italic)
    }

    fn resolve_header_text_measure_style<'a>(&'a self, col: i32) -> (&'a str, f32, bool, bool) {
        if self.fixed_rows > 0 {
            self.resolve_text_measure_style(0, col)
        } else {
            let font_size = if self.style.font_size > 0.0 {
                self.style.font_size
            } else {
                13.0
            };
            (
                &self.style.font_name,
                font_size,
                self.style.font_bold,
                self.style.font_italic,
            )
        }
    }

    fn subtotal_caption_horizontal_merge(
        &self,
        row: i32,
        col: i32,
    ) -> Option<(i32, i32, i32, i32)> {
        let props = self.row_props.get(&row)?;
        if !props.is_subtotal || props.subtotal_caption_col != col {
            return None;
        }
        let (r1, c1, r2, c2) = self.merged_regions.find_merge(row, col)?;
        if r1 == row && r2 == row && c1 == col && c2 > c1 {
            Some((r1, c1, r2, c2))
        } else {
            None
        }
    }

    fn should_skip_cell_for_column_autosize(&self, row: i32, col: i32) -> bool {
        self.subtotal_caption_horizontal_merge(row, col).is_some()
    }

    fn auto_resize_col_button_reserve(&self, row: i32, col: i32) -> f32 {
        if !crate::canvas::show_dropdown_button_for_cell(self, row, col) {
            return 0.0;
        }
        let row_height = self.get_row_height(row);
        // Measure with an unconstrained cell width so autosize always reserves
        // the full button width instead of whatever the current column width is.
        crate::canvas::dropdown_button_rect(0, 0, i32::MAX, row_height)
            .map_or(0, |(_, _, bw, _)| bw + 2) as f32
    }

    fn auto_resize_row_measure_width(&self, row: i32, col: i32, word_wrap: bool) -> Option<f32> {
        if !word_wrap {
            return None;
        }
        if let Some((_, c1, _, c2)) = self.subtotal_caption_horizontal_merge(row, col) {
            let span_width: i32 = (c1..=c2).map(|span_col| self.get_col_width(span_col)).sum();
            return Some(span_width.max(1) as f32);
        }
        Some(self.get_col_width(col).max(1) as f32)
    }

    fn row_indicator_start_auto_size_signature(&self) -> u64 {
        let band = &self.indicator_bands.row_start;
        let mut hasher = std::collections::hash_map::DefaultHasher::new();
        band.visible.hash(&mut hasher);
        band.auto_size.hash(&mut hasher);
        band.width_px.hash(&mut hasher);
        band.mode_bits.hash(&mut hasher);
        self.rows.hash(&mut hasher);
        self.fixed_rows.hash(&mut hasher);
        self.default_row_height.hash(&mut hasher);
        self.style.font_name.hash(&mut hasher);
        self.style.font_size.to_bits().hash(&mut hasher);
        for slot in &band.slots {
            slot.kind.hash(&mut hasher);
            slot.width_px.hash(&mut hasher);
            slot.visible.hash(&mut hasher);
            slot.custom_key.hash(&mut hasher);
            slot.data.len().hash(&mut hasher);
        }
        hasher.finish()
    }

    fn sync_row_indicator_start_auto_width(&mut self) {
        let sig = self.row_indicator_start_auto_size_signature();
        if self.row_indicator_start_auto_size_sig == sig {
            return;
        }

        let band = self.indicator_bands.row_start.clone();
        if !band.visible || !band.auto_size || !band.slots.is_empty() {
            self.row_indicator_start_auto_size_sig = sig;
            return;
        }

        let font_name = self.style.font_name.clone();
        let font_size = if self.style.font_size > 0.0 {
            self.style.font_size
        } else {
            13.0
        };
        let mut labels: Vec<String> = Vec::new();

        if band.has_mode(pb::RowIndicatorMode::RowIndicatorNumbers) {
            labels.push((self.rows - self.fixed_rows).max(1).to_string());
        } else {
            if band.has_mode(pb::RowIndicatorMode::RowIndicatorCurrent) {
                labels.push("▶".to_string());
            }
            if band.has_mode(pb::RowIndicatorMode::RowIndicatorSelection) {
                labels.push("•".to_string());
            }
        }
        if band.has_mode(pb::RowIndicatorMode::RowIndicatorHandle) {
            labels.push("≡".to_string());
        }
        if band.has_mode(pb::RowIndicatorMode::RowIndicatorEditing) {
            labels.push("✎".to_string());
        }
        if band.has_mode(pb::RowIndicatorMode::RowIndicatorExpander) {
            labels.push("+".to_string());
            labels.push("-".to_string());
        }

        if labels.is_empty() {
            self.row_indicator_start_auto_size_sig = sig;
            return;
        }

        self.ensure_text_engine();
        let mut te = self.text_engine.take().unwrap();
        let mut max_w = 0.0f32;
        for label in &labels {
            let (w, _) = te.measure_text(label, &font_name, font_size, false, false, None);
            max_w = max_w.max(w);
        }
        self.text_engine = Some(te);

        let needed_width =
            (max_w.ceil() as i32 + 8).max(crate::indicator::DEFAULT_ROW_INDICATOR_WIDTH);
        if self.indicator_bands.row_start.width_px != needed_width {
            self.indicator_bands.row_start.width_px = needed_width;
            self.dirty = true;
        }

        self.row_indicator_start_auto_size_sig = self.row_indicator_start_auto_size_signature();
    }

    /// Resolve the active dropdown list for a cell.
    ///
    /// Cell-level dropdown list has priority over the column-level list.
    pub fn active_dropdown_list(&self, row: i32, col: i32) -> String {
        // Dropdown behavior follows the same row-level editability rule.
        if !self.can_begin_edit(row, col, true) {
            return String::new();
        }
        self.configured_dropdown_list(row, col)
    }

    /// Returns display text for a cell, applying dropdown list value translation
    /// and column format strings.
    ///
    /// The grid stores translated IDs for `dropdown_items` entries (`#id;text`)
    /// and displays the associated text.
    pub fn get_display_text(&self, row: i32, col: i32) -> String {
        let raw = self.cells.get_text(row, col);
        if raw.is_empty() {
            return String::new();
        }

        // Dropdown list translation
        if col >= 0 && (col as usize) < self.columns.len() {
            let list = &self.columns[col as usize].dropdown_items;
            if !list.is_empty() {
                if let Some(display) = crate::edit::translate_dropdown_value_to_display(list, raw) {
                    return display;
                }
            }
        }

        // Column format application
        if col >= 0 && (col as usize) < self.columns.len() {
            let fmt = &self.columns[col as usize].format;
            if !fmt.is_empty() {
                if let Some(formatted) = apply_col_format(raw, fmt) {
                    return formatted;
                }
            }
        }

        // Cell-level custom format
        if let Some(cell) = self.cells.get(row, col) {
            let cf = cell.custom_format();
            if !cf.is_empty() {
                if let Some(formatted) = apply_col_format(raw, cf) {
                    return formatted;
                }
            }
        }

        if col >= 0 && (col as usize) < self.columns.len() {
            let col_props = &self.columns[col as usize];
            if col_props.data_type == pb::ColumnDataType::ColumnDataDate as i32 {
                if let Some(formatted) = format_as_iso_date(raw) {
                    return formatted;
                }
            }
        }

        raw.to_string()
    }

    /// Returns true if the cell is within the current selection.
    pub fn is_cell_selected(&self, row: i32, col: i32) -> bool {
        self.selection.is_selected(row, col, self.cols)
    }

    /// Returns the merged range for a cell as `Some((r1, c1, r2, c2))`,
    /// or `None` if the cell is not merged (range equals the cell itself).
    ///
    /// Explicit merges (from `merged_regions`) take priority over
    /// content-based spans (from `span`).
    pub fn get_merged_range(&self, row: i32, col: i32) -> Option<(i32, i32, i32, i32)> {
        // Explicit merges take priority.
        if let Some(range) = self.merged_regions.find_merge(row, col) {
            return Some(range);
        }
        // Fall back to content-based span.
        let (r1, c1, r2, c2) = self.span.get_merged_range(self, row, col);
        if r1 == row && c1 == col && r2 == row && c2 == col {
            None
        } else {
            Some((r1, c1, r2, c2))
        }
    }

    // ── Auto-Resize ─────────────────────────

    pub(crate) fn column_header_text(&self, col: i32) -> String {
        if col < 0 || (col as usize) >= self.columns.len() {
            return String::new();
        }
        let cp = &self.columns[col as usize];
        if !cp.caption.trim().is_empty() {
            return cp.caption.clone();
        }
        if !cp.key.trim().is_empty() {
            return cp.key.clone();
        }
        if self.fixed_rows > 0 {
            let legacy = self.get_display_text(0, col);
            if !legacy.trim().is_empty() {
                return legacy;
            }
        }
        String::new()
    }

    /// Auto-resize a column width to fit its content.
    ///
    /// Measures text in all rows for the given column using the text engine
    /// and sets the column width to accommodate the widest cell plus padding.
    pub fn auto_resize_col(&mut self, col: i32) {
        if col < 0 || col >= self.cols {
            return;
        }
        if self.is_tui_mode() {
            let mut max_w = 0i32;
            for row in 0..self.rows {
                if self.should_skip_cell_for_column_autosize(row, col) {
                    continue;
                }
                let text = self.get_display_text(row, col);
                if !text.is_empty() {
                    max_w = max_w.max(Self::tui_text_width(&text));
                }
            }
            let header_text = self.column_header_text(col);
            if !header_text.is_empty() {
                max_w = max_w.max(Self::tui_text_width(&header_text));
            }
            let new_width = max_w.max(self.default_col_width.min(20)).saturating_add(1);
            self.set_col_width(col, new_width);
            return;
        }
        let body_padding = self.resolve_column_padding(col, false).horizontal();
        let fixed_padding = self.resolve_column_padding(col, true).horizontal();
        let padding = body_padding.max(fixed_padding);

        self.ensure_text_engine();
        let mut te = self.text_engine.take().unwrap();
        let mut max_w: f32 = 0.0;
        for row in 0..self.rows {
            if self.should_skip_cell_for_column_autosize(row, col) {
                continue;
            }
            let text = self.get_display_text(row, col);
            let mut cell_w = self.auto_resize_col_button_reserve(row, col);
            if !text.is_empty() {
                let (font_name, font_size, bold, italic) =
                    self.resolve_text_measure_style(row, col);
                let (w, _) = te.measure_text(&text, font_name, font_size, bold, italic, None);
                cell_w += w;
            }
            max_w = max_w.max(cell_w);
        }
        let header_text = self.column_header_text(col);
        if !header_text.is_empty() {
            let (font_name, font_size, bold, italic) = self.resolve_header_text_measure_style(col);
            let (w, _) = te.measure_text(&header_text, font_name, font_size, bold, italic, None);
            max_w = max_w.max(w);
        }
        self.text_engine = Some(te);

        let new_width = (max_w.ceil() as i32 + padding).max(self.default_col_width.min(20));
        self.set_col_width(col, new_width);
    }

    /// Auto-resize a row height to fit its content.
    ///
    /// Measures text in all columns for the given row using the text engine
    /// and sets the row height to accommodate the tallest cell plus padding.
    pub fn auto_resize_row(&mut self, row: i32) {
        if row < 0 || row >= self.rows {
            return;
        }
        if self.is_tui_mode() {
            self.set_row_height(row, DEFAULT_TUI_ROW_HEIGHT);
            return;
        }
        let word_wrap = self.word_wrap;
        let body_padding = self.style.cell_padding.vertical();
        let fixed_padding = self.style.fixed_cell_padding.vertical();
        let padding = body_padding.max(fixed_padding);

        self.ensure_text_engine();
        let mut te = self.text_engine.take().unwrap();
        let mut max_h: f32 = 0.0;
        for col in 0..self.cols {
            let text = self.get_display_text(row, col);
            if !text.is_empty() {
                let max_width = self.auto_resize_row_measure_width(row, col, word_wrap);
                let (font_name, font_size, bold, italic) =
                    self.resolve_text_measure_style(row, col);
                let (_, h) = te.measure_text(&text, font_name, font_size, bold, italic, max_width);
                max_h = max_h.max(h);
            }
        }
        self.text_engine = Some(te);

        let new_height = (max_h.ceil() as i32 + padding).max(self.default_row_height.min(10));
        self.set_row_height(row, new_height);
    }

    fn auto_resize_col_top_header_rows(
        &mut self,
        te: &mut TextEngine,
        font_name: &str,
        font_size: f32,
    ) {
        if self.is_tui_mode() {
            let row_count = self.indicator_bands.col_top.row_count();
            if row_count <= 0 {
                return;
            }
            let changed =
                (0..row_count).any(|row| self.indicator_bands.col_top.row_height_px(row) != 1);
            if !changed {
                return;
            }
            self.indicator_bands.col_top.row_defs = (0..row_count)
                .map(|index| ColIndicatorRowDefState {
                    index,
                    height_px: 1,
                })
                .collect();
            self.layout.invalidate();
            self.dirty = true;
            return;
        }

        let band = self.indicator_bands.col_top.clone();
        if !band.visible {
            return;
        }

        let row_count = band.row_count();
        if row_count <= 0 {
            return;
        }

        let mut heights: Vec<i32> = (0..row_count).map(|row| band.row_height_px(row)).collect();
        let padding = self.style.fixed_cell_padding.vertical().max(2);
        let header_mode = pb::ColIndicatorCellMode::ColIndicatorCellHeaderText as u32;
        let mut changed = false;

        if band.cells.is_empty()
            && band.has_mode(pb::ColIndicatorCellMode::ColIndicatorCellHeaderText)
        {
            for col in 0..self.cols {
                let text = self.column_header_text(col);
                if text.is_empty() {
                    continue;
                }
                let (_, h) = te.measure_text(&text, font_name, font_size, false, false, None);
                let needed = h.ceil() as i32 + padding;
                if needed > heights[0] {
                    heights[0] = needed;
                    changed = true;
                }
            }
        }

        for cell in &band.cells {
            let row1 = cell.row1.max(0) as usize;
            let row2 = cell.row2.max(cell.row1).max(0) as usize;
            if row1 >= heights.len() || row2 >= heights.len() {
                continue;
            }
            let mode_bits = if cell.mode_bits != 0 {
                cell.mode_bits
            } else {
                band.mode_bits
            };
            let text = if !cell.text.trim().is_empty() {
                cell.text.clone()
            } else if cell.col1 == cell.col2 && (mode_bits & header_mode != 0) {
                self.column_header_text(cell.col1)
            } else {
                String::new()
            };
            if text.is_empty() {
                continue;
            }

            let (_, h) = te.measure_text(&text, font_name, font_size, false, false, None);
            let needed = h.ceil() as i32 + padding;
            if grow_span_heights_to_fit(&mut heights, row1, row2, needed) {
                changed = true;
            }
        }

        if !changed {
            return;
        }

        self.indicator_bands.col_top.row_defs = heights
            .into_iter()
            .enumerate()
            .map(|(index, height_px)| ColIndicatorRowDefState {
                index: index as i32,
                height_px: height_px.max(1),
            })
            .collect();
        self.layout.invalidate();
        self.dirty = true;
    }

    /// Auto-resize the full grid using the current `auto_size_mode`.
    ///
    /// Column auto-fit runs before row auto-fit so wrapped row-height
    /// measurement can use the final column widths.
    pub fn auto_resize_all(&mut self) {
        if !self.auto_resize || self.rows <= 0 || self.cols <= 0 {
            return;
        }

        let resize_cols = self.auto_size_mode == 0 || self.auto_size_mode == 1;
        let resize_rows = self.auto_size_mode == 0 || self.auto_size_mode == 2;
        if !resize_cols && !resize_rows {
            return;
        }

        let grid_font_name = self.style.font_name.clone();
        let grid_font_size = if self.style.font_size > 0.0 {
            self.style.font_size
        } else {
            13.0
        };
        let word_wrap = self.word_wrap;
        let default_col_min = self.default_col_width.min(20);
        let default_row_min = self.default_row_height.min(10);
        let row_padding = self
            .style
            .cell_padding
            .vertical()
            .max(self.style.fixed_cell_padding.vertical());

        if self.is_tui_mode() {
            if resize_cols {
                let mut max_widths = vec![0i32; self.cols as usize];

                for row in 0..self.rows {
                    for col in 0..self.cols {
                        if self.should_skip_cell_for_column_autosize(row, col) {
                            continue;
                        }
                        let text = self.get_display_text(row, col);
                        if text.is_empty() {
                            continue;
                        }
                        let idx = col as usize;
                        max_widths[idx] = max_widths[idx].max(Self::tui_text_width(&text));
                    }
                }

                for col in 0..self.cols {
                    let header_text = self.column_header_text(col);
                    if header_text.is_empty() {
                        continue;
                    }
                    let idx = col as usize;
                    max_widths[idx] = max_widths[idx].max(Self::tui_text_width(&header_text));
                }

                for col in 0..self.cols {
                    let idx = col as usize;
                    let new_width = max_widths[idx].max(default_col_min).saturating_add(1);
                    self.set_col_width(col, new_width);
                }
            }

            if resize_rows {
                for row in 0..self.rows {
                    let new_height =
                        DEFAULT_TUI_ROW_HEIGHT.max(default_row_min.min(DEFAULT_TUI_ROW_HEIGHT));
                    self.set_row_height(row, new_height);
                }
                self.auto_resize_col_top_header_rows(
                    &mut TextEngine::new(),
                    &grid_font_name,
                    grid_font_size,
                );
            }
            return;
        }

        self.ensure_text_engine();
        let mut te = self.text_engine.take().unwrap();

        if resize_cols {
            let col_padding: Vec<i32> = (0..self.cols)
                .map(|col| {
                    let body_padding = self.resolve_column_padding(col, false).horizontal();
                    let fixed_padding = self.resolve_column_padding(col, true).horizontal();
                    body_padding.max(fixed_padding)
                })
                .collect();
            let mut max_widths = vec![0.0f32; self.cols as usize];

            for row in 0..self.rows {
                for col in 0..self.cols {
                    if self.should_skip_cell_for_column_autosize(row, col) {
                        continue;
                    }
                    let text = self.get_display_text(row, col);
                    let idx = col as usize;
                    let mut cell_w = self.auto_resize_col_button_reserve(row, col);
                    if !text.is_empty() {
                        let (font_name, font_size, bold, italic) =
                            self.resolve_text_measure_style(row, col);
                        let (w, _) =
                            te.measure_text(&text, font_name, font_size, bold, italic, None);
                        cell_w += w;
                    }
                    max_widths[idx] = max_widths[idx].max(cell_w);
                }
            }

            for col in 0..self.cols {
                let header_text = self.column_header_text(col);
                if header_text.is_empty() {
                    continue;
                }
                let (font_name, font_size, bold, italic) =
                    self.resolve_header_text_measure_style(col);
                let (w, _) =
                    te.measure_text(&header_text, font_name, font_size, bold, italic, None);
                let idx = col as usize;
                max_widths[idx] = max_widths[idx].max(w);
            }

            for col in 0..self.cols {
                let idx = col as usize;
                let new_width =
                    (max_widths[idx].ceil() as i32 + col_padding[idx]).max(default_col_min);
                self.set_col_width(col, new_width);
            }
        }

        if resize_rows {
            let mut max_heights = vec![0.0f32; self.rows as usize];

            for row in 0..self.rows {
                for col in 0..self.cols {
                    let text = self.get_display_text(row, col);
                    if text.is_empty() {
                        continue;
                    }
                    let (font_name, font_size, bold, italic) =
                        self.resolve_text_measure_style(row, col);
                    let max_width = self.auto_resize_row_measure_width(row, col, word_wrap);
                    let (_, h) =
                        te.measure_text(&text, font_name, font_size, bold, italic, max_width);
                    let idx = row as usize;
                    max_heights[idx] = max_heights[idx].max(h);
                }
            }

            for row in 0..self.rows {
                let idx = row as usize;
                let new_height =
                    (max_heights[idx].ceil() as i32 + row_padding).max(default_row_min);
                self.set_row_height(row, new_height);
            }

            self.auto_resize_col_top_header_rows(&mut te, &grid_font_name, grid_font_size);
        }

        self.text_engine = Some(te);
    }

    /// Trigger auto-resize for the given cell's row and column if `auto_resize` is enabled.
    pub fn auto_resize_cell(&mut self, row: i32, col: i32) {
        if !self.auto_resize {
            return;
        }
        self.auto_resize_col(col);
        self.auto_resize_row(row);
    }

    fn clear_region_bounds(&self, region: i32) -> (i32, i32, i32, i32) {
        match region {
            0 => (
                self.fixed_rows,
                self.fixed_cols,
                self.rows - 1,
                self.cols - 1,
            ),
            1 => (0, 0, self.fixed_rows - 1, self.cols - 1),
            2 => (0, 0, self.rows - 1, self.fixed_cols - 1),
            3 => (0, 0, self.fixed_rows - 1, self.fixed_cols - 1),
            4..=6 => (0, 0, self.rows - 1, self.cols - 1),
            _ => (
                self.fixed_rows,
                self.fixed_cols,
                self.rows - 1,
                self.cols - 1,
            ),
        }
    }

    fn clear_cell_styles_in_bounds(&mut self, r1: i32, c1: i32, r2: i32, c2: i32) {
        if r1 > r2 || c1 > c2 {
            return;
        }
        for row in r1..=r2 {
            for col in c1..=c2 {
                self.cell_styles.remove(&(row, col));
            }
        }
    }

    fn clear_everything_in_bounds(&mut self, r1: i32, c1: i32, r2: i32, c2: i32) {
        if r1 > r2 || c1 > c2 {
            return;
        }

        self.cells.clear_range(r1, c1, r2, c2);
        self.clear_cell_styles_in_bounds(r1, c1, r2, c2);
        self.merged_regions.remove_overlapping(r1, c1, r2, c2);
        self.row_props.retain(|row, _| *row < r1 || *row > r2);
        self.rows_hidden.retain(|row| *row < r1 || *row > r2);
        self.cols_hidden.retain(|col| *col < c1 || *col > c2);
        self.pinned_rows_top.retain(|&row| row < r1 || row > r2);
        self.pinned_rows_bottom.retain(|&row| row < r1 || row > r2);
        self.pinned_cols_left.retain(|&col| col < c1 || col > c2);
        self.pinned_cols_right.retain(|&col| col < c1 || col > c2);
        self.sticky_rows.retain(|row, _| *row < r1 || *row > r2);
        self.sticky_cols.retain(|col, _| *col < c1 || *col > c2);
        self.sticky_cells
            .retain(|&(row, col), _| row < r1 || row > r2 || col < c1 || col > c2);
        self.layout.invalidate();
    }

    pub fn clear_region(&mut self, scope: i32, region: i32) {
        let (r1, c1, r2, c2) = self.clear_region_bounds(region);

        match scope {
            0 => self.clear_everything_in_bounds(r1, c1, r2, c2),
            1 => self.clear_cell_styles_in_bounds(r1, c1, r2, c2),
            2 => {
                if r1 <= r2 && c1 <= c2 {
                    self.cells.clear_range(r1, c1, r2, c2);
                }
            }
            3 => {
                for (sr1, sc1, sr2, sc2) in self.selection.all_ranges(self.rows, self.cols) {
                    self.cells.clear_range(sr1, sc1, sr2, sc2);
                    self.clear_cell_styles_in_bounds(sr1, sc1, sr2, sc2);
                }
            }
            _ => {}
        }

        self.mark_dirty();
    }

    fn auto_resize_for_merge_change(&mut self, r1: i32, c1: i32, r2: i32, c2: i32) {
        if !self.auto_resize || self.rows <= 0 || self.cols <= 0 {
            return;
        }

        let row_lo = r1.min(r2).clamp(0, self.rows - 1);
        let row_hi = r1.max(r2).clamp(0, self.rows - 1);
        let col_lo = c1.min(c2).clamp(0, self.cols - 1);
        let col_hi = c1.max(c2).clamp(0, self.cols - 1);

        let resize_cols = self.auto_size_mode == 0 || self.auto_size_mode == 1;
        let resize_rows = self.auto_size_mode == 0 || self.auto_size_mode == 2;

        if resize_cols {
            for col in col_lo..=col_hi {
                self.auto_resize_col(col);
            }
        }

        if resize_rows {
            for row in row_lo..=row_hi {
                self.auto_resize_row(row);
            }
        }
    }

    pub fn merge_cells(&mut self, r1: i32, c1: i32, r2: i32, c2: i32) {
        let (row_lo, row_hi) = (r1.min(r2), r1.max(r2));
        let (col_lo, col_hi) = (c1.min(c2), c1.max(c2));
        self.merged_regions
            .add_merge(row_lo, col_lo, row_hi, col_hi);
        self.layout.invalidate();
        self.auto_resize_for_merge_change(row_lo, col_lo, row_hi, col_hi);
        self.mark_dirty();
    }

    pub fn unmerge_cells(&mut self, r1: i32, c1: i32, r2: i32, c2: i32) {
        let (row_lo, row_hi) = (r1.min(r2), r1.max(r2));
        let (col_lo, col_hi) = (c1.min(c2), c1.max(c2));
        self.merged_regions
            .remove_overlapping(row_lo, col_lo, row_hi, col_hi);
        self.layout.invalidate();
        self.auto_resize_for_merge_change(row_lo, col_lo, row_hi, col_hi);
        self.mark_dirty();
    }

    // ── Data Refresh ───────────────────────

    /// Trigger a data refresh cycle.
    ///
    /// Fires `DataRefreshing` and `DataRefreshed` events, invalidates
    /// layout, and marks the grid dirty for re-render.
    pub fn data_refresh(&mut self) {
        self.cancel_pull_to_refresh_contact(false);
        self.pull_to_refresh_state = crate::grid::PullToRefreshState::Idle;
        self.pull_to_refresh_reveal_px = 0.0;
        self.pull_to_refresh_target_reveal_px = 0.0;

        self.events
            .push(crate::event::GridEventData::DataRefreshing);
        self.layout.invalidate();
        self.text_meta_generation = self.text_meta_generation.wrapping_add(1);
        self.dirty = true;
        self.events.push(crate::event::GridEventData::DataRefreshed);
    }

    // ── FormatString ─────────────────────

    /// Apply the `format_string` property to configure columns.
    ///
    /// The format string is pipe-delimited: `"<Name|>Amount|^Status"`.
    /// - Prefix `<` = left align, `>` = right align, `^` = center align.
    /// - Suffix `;width` sets column width in pixels.
    /// - The number of segments sets `cols`, and header text is placed in
    ///   fixed row 0 for each column.
    pub fn apply_format_string(&mut self) {
        if self.format_string.is_empty() {
            return;
        }

        // Clone to avoid borrow conflict with &mut self
        let fmt = self.format_string.clone();
        let segments: Vec<&str> = fmt.split('|').collect();
        if segments.is_empty() {
            return;
        }

        let new_cols = segments.len() as i32;
        self.set_cols(new_cols);

        for (i, segment) in segments.iter().enumerate() {
            let col = i as i32;
            let mut s = *segment;
            let mut alignment = pb::Align::General as i32;

            // Parse alignment prefix
            if s.starts_with('<') {
                alignment = pb::Align::LeftCenter as i32;
                s = &s[1..];
            } else if s.starts_with('>') {
                alignment = pb::Align::RightCenter as i32;
                s = &s[1..];
            } else if s.starts_with('^') {
                alignment = pb::Align::CenterCenter as i32;
                s = &s[1..];
            }

            // Parse width suffix
            let (header_text, width) = if let Some(semi_pos) = s.rfind(';') {
                let width_str = &s[semi_pos + 1..];
                let w = width_str.trim().parse::<i32>().unwrap_or(-1);
                (&s[..semi_pos], w)
            } else {
                (s, -1)
            };

            // Apply caption/alignment
            if col < self.cols && (col as usize) < self.columns.len() {
                self.columns[col as usize].caption = header_text.to_string();
                self.columns[col as usize].alignment = alignment;
            }

            // Apply width
            if width > 0 {
                let w = self.clamp_col_width(col, width);
                self.col_widths.insert(col, w);
            }

            // Preserve legacy fixed-row header text when fixed rows are in use.
            if self.fixed_rows > 0 {
                self.cells.set_text(0, col, header_text.to_string());
            }
        }

        self.layout.invalidate();
        self.text_meta_generation = self.text_meta_generation.wrapping_add(1);
        self.dirty = true;
    }

    // ── Version ────────────────────────────────

    /// Returns the engine version string.
    pub fn version() -> &'static str {
        env!("VOLVOXGRID_VERSION")
    }

    /// Returns the build git commit.
    pub fn git_commit() -> &'static str {
        env!("VOLVOXGRID_GIT_COMMIT")
    }

    /// Returns the build timestamp string.
    pub fn build_date() -> &'static str {
        env!("VOLVOXGRID_BUILD_DATE")
    }

    // ── Client dimensions (ClientWidth/ClientHeight) ─────

    /// Returns the usable client width (viewport minus fixed column area).
    pub fn client_width(&self) -> i32 {
        (self.data_viewport_width() - self.fixed_width()).max(0)
    }

    /// Returns the usable client height (viewport minus fixed row area).
    pub fn client_height(&self) -> i32 {
        (self.data_viewport_height() - self.fixed_height()).max(0)
    }

    // ── AddItem / RemoveItem ──────────────────────────────────────────

    /// Insert a new row at `at_row` with tab-delimited text spread across columns.
    ///
    /// If `at_row < 0` or `at_row >= rows`, the row is appended at the end.
    pub fn add_item(&mut self, text: &str, at_row: i32) {
        let insert_at = if at_row < 0 || at_row >= self.rows {
            self.rows
        } else {
            at_row
        };

        // Shift existing cell data down
        self.cells.insert_row(insert_at);

        // Increment row count
        self.rows += 1;

        // Preserve existing display-to-logical mapping:
        // 1. Bump all logical indices >= insert_at by 1
        for pos in self.row_positions.iter_mut() {
            if *pos >= insert_at {
                *pos += 1;
            }
        }
        // 2. Insert the new row's logical index at the appropriate display position.
        //    Find the display position where insert_at was (or would be) shown.
        let display_pos = self
            .row_positions
            .iter()
            .position(|&r| r == insert_at + 1) // the row that was at insert_at (now bumped to insert_at+1)
            .unwrap_or(self.row_positions.len());
        self.row_positions.insert(display_pos, insert_at);

        // Shift row heights, row_props, cell_styles for rows >= insert_at
        let old_heights = std::mem::take(&mut self.row_heights);
        for (r, h) in old_heights {
            if r >= insert_at {
                self.row_heights.insert(r + 1, h);
            } else {
                self.row_heights.insert(r, h);
            }
        }

        let old_props = std::mem::take(&mut self.row_props);
        for (r, props) in old_props {
            if r >= insert_at {
                self.row_props.insert(r + 1, props);
            } else {
                self.row_props.insert(r, props);
            }
        }

        let old_styles = std::mem::take(&mut self.cell_styles);
        for ((r, c), style) in old_styles {
            if r >= insert_at {
                self.cell_styles.insert((r + 1, c), style);
            } else {
                self.cell_styles.insert((r, c), style);
            }
        }

        self.merged_regions.shift_rows_down(insert_at);

        // Set tab-delimited text across columns
        let parts: Vec<&str> = text.split('\t').collect();
        for (i, part) in parts.iter().enumerate() {
            let col = i as i32;
            if col < self.cols {
                self.cells.set_text(insert_at, col, part.to_string());
            }
        }

        let h = self.get_row_height(insert_at);
        self.animation.notify_rows_inserted(insert_at, 1, h);
        self.layout.invalidate();
        self.text_meta_generation = self.text_meta_generation.wrapping_add(1);
        self.dirty = true;
    }

    /// Remove the row at `row`, shifting subsequent rows up.
    ///
    /// Does nothing if `row` is out of range or is a fixed row.
    pub fn remove_item(&mut self, row: i32) {
        if row < self.fixed_rows || row >= self.rows {
            return;
        }

        let h = self.get_row_height(row);
        self.animation.notify_rows_removed(row, 1, h);
        self.cells.remove_row(row);
        self.rows -= 1;

        // Preserve existing display-to-logical mapping:
        // 1. Remove the entry for this logical row from position mapping
        self.row_positions.retain(|&r| r != row);
        // 2. Decrement all logical indices > row by 1
        for pos in self.row_positions.iter_mut() {
            if *pos > row {
                *pos -= 1;
            }
        }

        // Shift row heights and row_props for rows > row
        let old_heights = std::mem::take(&mut self.row_heights);
        for (r, h) in old_heights {
            if r == row {
                continue; // remove the deleted row's height
            } else if r > row {
                self.row_heights.insert(r - 1, h);
            } else {
                self.row_heights.insert(r, h);
            }
        }

        let old_props = std::mem::take(&mut self.row_props);
        for (r, props) in old_props {
            if r == row {
                continue;
            } else if r > row {
                self.row_props.insert(r - 1, props);
            } else {
                self.row_props.insert(r, props);
            }
        }

        let old_styles = std::mem::take(&mut self.cell_styles);
        for ((r, c), style) in old_styles {
            if r == row {
                continue;
            } else if r > row {
                self.cell_styles.insert((r - 1, c), style);
            } else {
                self.cell_styles.insert((r, c), style);
            }
        }

        self.merged_regions.shift_rows_up(row);

        // Clamp frozen rows, selection
        if self.fixed_rows + self.frozen_rows > self.rows {
            self.frozen_rows = (self.rows - self.fixed_rows).max(0);
        }
        self.selection
            .clamp(self.rows, self.cols, self.fixed_rows, self.fixed_cols);

        self.layout.invalidate();
        self.text_meta_generation = self.text_meta_generation.wrapping_add(1);
        self.dirty = true;
    }
}

/// Public wrapper for `apply_col_format` used by other modules (e.g. outline subtotals).
pub fn apply_col_format_public(raw: &str, fmt: &str) -> Option<String> {
    apply_col_format(raw, fmt)
}

/// Apply a column format string to a raw cell value.
///
/// Supports common spreadsheet-style format codes:
/// - `#,##0` / `#,##0.00` — thousands separator, fixed decimals
/// - `$#,##0.00` — currency prefix
/// - `0.0%` / `0%` — percentage (multiplies by 100)
/// - Fixed decimal: `0.0`, `0.00`, `0.000` etc.
/// - Literal prefix/suffix around `#` or `0` patterns
fn apply_col_format(raw: &str, fmt: &str) -> Option<String> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return None;
    }

    // Handle named formats
    let fmt_lower = fmt.to_lowercase();
    match fmt_lower.as_str() {
        "currency" => return apply_col_format(raw, "$#,##0.00"),
        "fixed" => return apply_col_format(raw, "0.00"),
        "standard" => return apply_col_format(raw, "#,##0.00"),
        "percent" => return apply_col_format(raw, "0.00%"),
        "scientific" => {
            let cleaned = trimmed.replace([',', '$', ' '], "");
            if let Ok(val) = cleaned.parse::<f64>() {
                return Some(format!("{:.2E}", val));
            }
            return None;
        }
        "short date" => {
            // Format as MM/DD/YYYY if parseable
            if let Some(formatted) = format_as_short_date(trimmed) {
                return Some(formatted);
            }
            return None;
        }
        "long date" => {
            if let Some(formatted) = format_as_long_date(trimmed) {
                return Some(formatted);
            }
            return None;
        }
        "true/false" => {
            return Some(format_bool_string(trimmed, "True", "False"));
        }
        "yes/no" => {
            return Some(format_bool_string(trimmed, "Yes", "No"));
        }
        "on/off" => {
            return Some(format_bool_string(trimmed, "On", "Off"));
        }
        _ => {}
    }

    // Try to parse as a number for numeric formats
    let cleaned = trimmed.replace([',', '$', ' '], "");
    let num = cleaned.parse::<f64>().ok();

    if let Some(val) = num {
        let is_percent = fmt.contains('%');
        let display_val = if is_percent { val * 100.0 } else { val };

        // Count decimal places from format
        let decimals = if let Some(dot_pos) = fmt.rfind('.') {
            let after_dot: usize = fmt[dot_pos + 1..]
                .chars()
                .take_while(|c| *c == '0' || *c == '#')
                .count();
            after_dot
        } else {
            0
        };

        // Format the number
        let formatted_num = format!("{:.prec$}", display_val, prec = decimals);

        // Add thousands separator if format contains ','
        let with_sep = if fmt.contains(',') {
            add_thousands_separator(&formatted_num)
        } else {
            formatted_num
        };

        // Build final string with prefix/suffix from format
        let mut prefix = String::new();
        let mut suffix = String::new();

        // Extract prefix (chars before first # or 0)
        for ch in fmt.chars() {
            if ch == '#' || ch == '0' || ch == '.' || ch == ',' {
                break;
            }
            prefix.push(ch);
        }

        // Extract suffix (chars after last # or 0 or %)
        let last_fmt_char = fmt
            .rfind(|c: char| c == '#' || c == '0' || c == '%')
            .unwrap_or(0);
        if last_fmt_char + 1 < fmt.len() {
            let remaining = &fmt[last_fmt_char + 1..];
            // Skip the first char if it was already consumed
            for ch in remaining.chars() {
                if ch != '#' && ch != '0' && ch != '.' && ch != ',' {
                    suffix.push(ch);
                }
            }
        }

        let pct_suffix = if is_percent { "%" } else { "" };

        Some(format!("{}{}{}{}", prefix, with_sep, pct_suffix, suffix))
    } else {
        // Not a number; return raw text unchanged
        None
    }
}

/// Map a cell value to a boolean display string.
///
/// Treats "0", "false", "no", "off", and empty as the false value;
/// everything else (including any non-zero number) as the true value.
fn format_bool_string(raw: &str, true_str: &str, false_str: &str) -> String {
    let lower = raw.trim().to_lowercase();
    if lower.is_empty()
        || lower == "0"
        || lower == "false"
        || lower == "no"
        || lower == "off"
        || lower == "0.0"
    {
        false_str.to_string()
    } else {
        true_str.to_string()
    }
}

/// Format a date string as MM/DD/YYYY (Short Date).
fn format_as_short_date(raw: &str) -> Option<String> {
    let (y, m, d) = parse_date_value(raw)?;
    Some(format!("{:02}/{:02}/{:04}", m, d, y))
}

/// Format a date string as "Month DD, YYYY" (Long Date).
fn format_as_long_date(raw: &str) -> Option<String> {
    let (y, m, d) = parse_date_value(raw)?;
    let month_name = match m {
        1 => "January",
        2 => "February",
        3 => "March",
        4 => "April",
        5 => "May",
        6 => "June",
        7 => "July",
        8 => "August",
        9 => "September",
        10 => "October",
        11 => "November",
        12 => "December",
        _ => return None,
    };
    Some(format!("{} {:02}, {:04}", month_name, d, y))
}

/// Format a date string as YYYY-MM-DD (ISO Date).
fn format_as_iso_date(raw: &str) -> Option<String> {
    let (y, m, d) = parse_date_value(raw)?;
    Some(format!("{:04}-{:02}-{:02}", y, m, d))
}

fn parse_date_value(raw: &str) -> Option<(i32, i32, i32)> {
    parse_date_parts(raw).or_else(|| {
        let millis = raw.trim().parse::<i64>().ok()?;
        let days = millis.div_euclid(86_400_000);
        Some(civil_from_days(days))
    })
}

/// Parse common date formats into (year, month, day).
/// Supports: YYYY-MM-DD, YYYY/MM/DD, MM/DD/YYYY, MM-DD-YYYY.
fn parse_date_parts(s: &str) -> Option<(i32, i32, i32)> {
    let s = s.trim();
    if s.is_empty() {
        return None;
    }
    let parts: Vec<&str> = s
        .split(|ch: char| !ch.is_ascii_digit())
        .filter(|p| !p.is_empty())
        .collect();
    if parts.len() < 3 {
        return None;
    }
    let p0 = parts[0].parse::<i32>().ok()?;
    let p1 = parts[1].parse::<i32>().ok()?;
    let p2 = parts[2].parse::<i32>().ok()?;

    let (y, m, d) = if parts[0].len() == 4 {
        (p0, p1, p2) // YYYY-MM-DD
    } else if parts[2].len() == 4 {
        (p2, p0, p1) // MM/DD/YYYY
    } else {
        return None;
    };
    if !(1..=12).contains(&m) || !(1..=31).contains(&d) {
        return None;
    }
    Some((y, m, d))
}

fn civil_from_days(days: i64) -> (i32, i32, i32) {
    let z = days + 719_468;
    let era = if z >= 0 { z } else { z - 146_096 } / 146_097;
    let doe = z - era * 146_097;
    let yoe = (doe - doe / 1_460 + doe / 36_524 - doe / 146_096) / 365;
    let y = yoe + era * 400;
    let doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    let mp = (5 * doy + 2) / 153;
    let d = doy - (153 * mp + 2) / 5 + 1;
    let m = mp + if mp < 10 { 3 } else { -9 };
    let year = y + if m <= 2 { 1 } else { 0 };
    (year as i32, m as i32, d as i32)
}

/// Insert thousands separators into a formatted number string.
fn add_thousands_separator(s: &str) -> String {
    let (integer_part, decimal_part) = match s.find('.') {
        Some(dot) => (&s[..dot], Some(&s[dot..])),
        None => (s, None),
    };

    let negative = integer_part.starts_with('-');
    let digits = if negative {
        &integer_part[1..]
    } else {
        integer_part
    };

    let mut result = String::new();
    let len = digits.len();
    for (i, ch) in digits.chars().enumerate() {
        if i > 0 && (len - i) % 3 == 0 {
            result.push(',');
        }
        result.push(ch);
    }

    let mut final_str = String::new();
    if negative {
        final_str.push('-');
    }
    final_str.push_str(&result);
    if let Some(dec) = decimal_part {
        final_str.push_str(dec);
    }
    final_str
}

// =========================================================================
// Public utility functions that hosts previously had to duplicate.
// =========================================================================

impl VolvoxGrid {
    /// Rebuild the layout cache from grid dimensions.
    ///
    /// This is the canonical entry point that avoids the self-referential
    /// borrow problem of calling `self.layout.rebuild(self)`.
    pub fn ensure_layout(&mut self) {
        self.sync_row_indicator_start_auto_width();
        if !self.layout.valid {
            // Snapshot previous positions for animation diffing
            self.animation.save_prev(&self.layout);

            let rows = self.rows;
            let cols = self.cols;
            self.layout.rows = rows;
            self.layout.cols = cols;

            self.layout.uniform_rows = self.row_heights.is_empty()
                && self.rows_hidden.is_empty()
                && self.pinned_rows_top.is_empty()
                && self.pinned_rows_bottom.is_empty();
            if self.layout.uniform_rows {
                self.layout.uniform_row_height = self.clamp_row_height(self.default_row_height);
                self.layout.row_positions.clear();
                self.layout.total_height = self
                    .layout
                    .uniform_row_height
                    .max(0)
                    .saturating_mul(rows.max(0));
            } else {
                self.layout.uniform_row_height = 0;
                self.layout.row_positions.clear();
                self.layout.row_positions.reserve((rows + 1) as usize);
                self.layout.row_positions.push(0);
                for r in 0..rows {
                    let prev = *self.layout.row_positions.last().unwrap();
                    // Pinned rows get 0 height in layout so they disappear
                    // from the scrollable area. Their actual height is still
                    // returned by row_height() for pinned-section rendering.
                    let h = if self.is_row_pinned(r) != 0 {
                        0
                    } else {
                        self.row_height(r)
                    };
                    self.layout.row_positions.push(prev + h);
                }
                self.layout.total_height = *self.layout.row_positions.last().unwrap_or(&0);
            }

            self.layout.uniform_cols = self.col_widths.is_empty()
                && self.cols_hidden.is_empty()
                && self.col_width_min.is_empty()
                && self.col_width_max.is_empty()
                && self.pinned_cols_left.is_empty()
                && self.pinned_cols_right.is_empty();
            if self.layout.uniform_cols {
                self.layout.uniform_col_width = self.clamp_col_width(0, self.default_col_width);
                self.layout.col_positions.clear();
                self.layout.total_width = self
                    .layout
                    .uniform_col_width
                    .max(0)
                    .saturating_mul(cols.max(0));
            } else {
                self.layout.uniform_col_width = 0;
                self.layout.col_positions.clear();
                self.layout.col_positions.reserve((cols + 1) as usize);
                self.layout.col_positions.push(0);
                for c in 0..cols {
                    let prev = *self.layout.col_positions.last().unwrap();
                    // Pinned columns get 0 width in layout so they disappear
                    // from the horizontal scrollable area.
                    let w = if self.is_col_pinned(c) != 0 {
                        0
                    } else {
                        self.col_width(c)
                    };
                    self.layout.col_positions.push(prev + w);
                }
                self.layout.total_width = *self.layout.col_positions.last().unwrap_or(&0);
            }

            self.layout.valid = true;

            // Compute animation offsets from layout diff
            self.animation.compute_offsets(&self.layout);
        }
        let pinned_h = self.pinned_top_height() + self.pinned_bottom_height();
        let pinned_w = self.pinned_left_width() + self.pinned_right_width();
        self.scroll.update_bounds(
            &self.layout,
            self.data_viewport_width(),
            self.data_viewport_height(),
            self.fixed_rows,
            self.fixed_cols,
            pinned_h,
            pinned_w,
        );
        self.normalize_scroll_for_mode();

        if self.is_tui_mode() {
            self.animation.clear();
            let _ = self.tick_scrollbar_fade(0.0);
            return;
        }

        // Tick animation offsets and keep dirty while animating
        if self.animation.tick() {
            self.dirty = true;
        }
        if self.tick_scrollbar_fade_animation() {
            self.dirty = true;
        }
    }

    /// Returns the topmost visible scrollable row (`TopRow`).
    pub fn top_row(&mut self) -> i32 {
        self.ensure_layout();
        let first_scrollable = self.first_scrollable_row().clamp(0, self.rows);
        if first_scrollable >= self.rows {
            return first_scrollable.saturating_sub(1).max(0);
        }
        let (first, _) = self.layout.visible_rows(
            self.scroll.scroll_y,
            self.data_viewport_height(),
            first_scrollable,
        );
        first.clamp(first_scrollable, self.rows - 1)
    }

    /// Sets the topmost visible scrollable row (`TopRow`).
    pub fn set_top_row(&mut self, row: i32) {
        self.ensure_layout();
        let first_scrollable = self.first_scrollable_row().clamp(0, self.rows);
        if first_scrollable >= self.rows {
            return;
        }
        let target_row = row.clamp(first_scrollable, self.rows - 1);
        let fixed_h = self.layout.row_pos(first_scrollable);
        let row_top = self.layout.row_pos(target_row);
        let target_scroll_y = (row_top - fixed_h).max(0) as f32;
        let viewport_w = self.data_viewport_width();
        let viewport_h = self.data_viewport_height();
        let pinned_h = self.pinned_top_height() + self.pinned_bottom_height();
        let pinned_w = self.pinned_left_width() + self.pinned_right_width();
        let (max_scroll_x, max_scroll_y) = ScrollState::compute_max_scroll(
            &self.layout,
            viewport_w,
            viewport_h,
            self.fixed_rows,
            self.fixed_cols,
            pinned_h,
            pinned_w,
        );
        // Programmatic jumps (e.g. host fast scroller) should cancel inertia so
        // the requested row stays stable instead of being overridden by fling.
        self.scroll.stop_fling();
        // Clamp to the real content extent so near-end jumps keep the last
        // rows visible instead of overscrolling into blank space.
        self.scroll.max_scroll_x = max_scroll_x;
        self.scroll.max_scroll_y = max_scroll_y;
        self.scroll.scroll_y = target_scroll_y.min(max_scroll_y);
        self.normalize_scroll_for_mode();
        self.mark_dirty_visual();
    }

    /// Returns the bottommost visible scrollable row (`BottomRow`).
    pub fn bottom_row(&mut self) -> i32 {
        self.ensure_layout();
        let first_scrollable = self.first_scrollable_row().clamp(0, self.rows);
        if first_scrollable >= self.rows {
            return first_scrollable.saturating_sub(1).max(0);
        }
        let (_, last) = self.layout.visible_rows(
            self.scroll.scroll_y,
            self.data_viewport_height(),
            first_scrollable,
        );
        last.clamp(first_scrollable, self.rows - 1)
    }

    /// Returns the leftmost visible scrollable column (`LeftCol`).
    pub fn left_col(&mut self) -> i32 {
        self.ensure_layout();
        let first_scrollable = self.first_scrollable_col().clamp(0, self.cols);
        if first_scrollable >= self.cols {
            return first_scrollable.saturating_sub(1).max(0);
        }
        let (first, _) = self.layout.visible_cols(
            self.scroll.scroll_x,
            self.data_viewport_width(),
            first_scrollable,
        );
        first.clamp(first_scrollable, self.cols - 1)
    }

    /// Sets the leftmost visible scrollable column (`LeftCol`).
    pub fn set_left_col(&mut self, col: i32) {
        self.ensure_layout();
        let first_scrollable = self.first_scrollable_col().clamp(0, self.cols);
        if first_scrollable >= self.cols {
            return;
        }
        let target_col = col.clamp(first_scrollable, self.cols - 1);
        let fixed_w = self.layout.col_pos(first_scrollable);
        let col_left = self.layout.col_pos(target_col);
        let target_scroll_x = (col_left - fixed_w).max(0) as f32;
        let viewport_w = self.data_viewport_width();
        let viewport_h = self.data_viewport_height();
        let pinned_h = self.pinned_top_height() + self.pinned_bottom_height();
        let pinned_w = self.pinned_left_width() + self.pinned_right_width();
        let (max_scroll_x, max_scroll_y) = ScrollState::compute_max_scroll(
            &self.layout,
            viewport_w,
            viewport_h,
            self.fixed_rows,
            self.fixed_cols,
            pinned_h,
            pinned_w,
        );
        self.scroll.stop_fling();
        self.scroll.max_scroll_x = max_scroll_x;
        self.scroll.max_scroll_y = max_scroll_y;
        self.scroll.scroll_x = target_scroll_x.min(max_scroll_x);
        self.normalize_scroll_for_mode();
        self.mark_dirty_visual();
    }

    /// Returns the rightmost visible scrollable column (`RightCol`).
    pub fn right_col(&mut self) -> i32 {
        self.ensure_layout();
        let first_scrollable = self.first_scrollable_col().clamp(0, self.cols);
        if first_scrollable >= self.cols {
            return first_scrollable.saturating_sub(1).max(0);
        }
        let (_, last) = self.layout.visible_cols(
            self.scroll.scroll_x,
            self.data_viewport_width(),
            first_scrollable,
        );
        last.clamp(first_scrollable, self.cols - 1)
    }

    /// Commit the active edit, applying dropdown translation, text truncation,
    /// and emitting all required events (CellEditValidate, AfterEdit, CellChanged,
    /// DropdownClosed).  Returns true if an edit was committed.
    pub fn commit_edit(&mut self) -> bool {
        let Some((row, col, old_text, new_text)) = self.edit.commit() else {
            return false;
        };

        // Normalize: truncate, translate dropdown display→value.
        let mut committed = truncate_chars(&new_text, self.edit_max_length);
        let cell_dropdown = self
            .cells
            .get(row, col)
            .map(|c| c.dropdown_items().to_string())
            .unwrap_or_default();
        if cell_dropdown.is_empty() && col >= 0 && (col as usize) < self.columns.len() {
            let col_list = &self.columns[col as usize].dropdown_items;
            if !col_list.is_empty() {
                if let Some(mapped) =
                    crate::edit::translate_dropdown_display_to_value(col_list, &committed)
                {
                    committed = mapped;
                }
            }
        }

        // Emit events and apply.
        self.events
            .push(crate::event::GridEventData::CellEditValidate {
                row,
                col,
                edit_text: committed.clone(),
            });
        self.cells.set_text(row, col, committed.clone());
        self.sync_explicit_progress_from_text(row, col);
        if old_text != committed {
            self.events.push(crate::event::GridEventData::AfterEdit {
                row,
                col,
                old_text: old_text.clone(),
                new_text: committed.clone(),
            });
            self.events.push(crate::event::GridEventData::CellChanged {
                row,
                col,
                old_text,
                new_text: committed,
            });
        }
        let active_dropdown = self.active_dropdown_list(row, col);
        if !active_dropdown.is_empty() {
            self.events
                .push(crate::event::GridEventData::DropdownClosed);
        }
        self.mark_dirty();
        true
    }

    /// If a cell already carries explicit progress metadata, keep the visual
    /// progress fill synchronized with the committed text users edit.
    pub fn sync_explicit_progress_from_text(&mut self, row: i32, col: i32) {
        let should_sync = self
            .cells
            .get(row, col)
            .is_some_and(|cell| cell.progress_percent() > 0.0 || cell.progress_color() != 0);
        if !should_sync {
            return;
        }

        let percent =
            crate::canvas::parse_progress_percent(self.cells.get_text(row, col)).clamp(0.0, 1.0);
        self.cells.get_mut(row, col).extra_mut().progress_percent = percent;
    }

    /// Cancel the active edit and emit DropdownClosed if applicable.
    /// Returns true if an edit was cancelled.
    pub fn cancel_edit(&mut self) -> bool {
        let Some((row, col)) = self.edit.cancel() else {
            return false;
        };
        let active_dropdown = self.active_dropdown_list(row, col);
        if !active_dropdown.is_empty() {
            self.events
                .push(crate::event::GridEventData::DropdownClosed);
        }
        self.mark_dirty();
        true
    }

    /// Begin editing a cell, handling dropdown list parsing and event emission.
    pub fn begin_edit(&mut self, row: i32, col: i32) {
        if !self.can_begin_edit(row, col, false) {
            return;
        }

        let dropdown_list = self.active_dropdown_list(row, col);
        self.events
            .push(crate::event::GridEventData::BeforeEdit { row, col });

        let stored_text = self.cells.get_text(row, col).to_string();
        let display_text = self.get_display_text(row, col);
        self.edit.start_edit(row, col, &display_text);
        self.edit.parse_dropdown_items(&dropdown_list);

        if !dropdown_list.is_empty() {
            for i in 0..self.edit.dropdown_count() {
                if (!stored_text.is_empty() && self.edit.get_dropdown_data(i) == stored_text)
                    || self.edit.get_dropdown_item(i) == display_text
                {
                    self.edit.set_dropdown_index(i);
                    break;
                }
            }
            self.events
                .push(crate::event::GridEventData::DropdownOpened);
        }

        self.events
            .push(crate::event::GridEventData::StartEdit { row, col });
        self.mark_dirty();
    }

    /// Get the screen-space rectangle for a cell, accounting for scroll
    /// offset, frozen rows/cols, and merged ranges.
    /// Returns `None` if the cell is hidden or off-screen.
    pub fn cell_screen_rect(&self, row: i32, col: i32) -> Option<(i32, i32, i32, i32)> {
        if row < 0 || row >= self.rows || col < 0 || col >= self.cols {
            return None;
        }
        if !self.layout.valid {
            return None;
        }
        if self.is_row_hidden(row) || self.is_col_hidden(col) {
            return None;
        }
        let vp =
            crate::canvas::VisibleRange::compute(self, self.viewport_width, self.viewport_height);
        crate::canvas::cell_rect(self, row, col, &vp)
    }

    /// Get the screen-space rectangle for an edit input box, extending into
    /// empty neighbor cells only when the edit text actually overflows the
    /// cell width.  Matches spreadsheet behavior: short text → normal cell
    /// rect, long text → extended rect (right border disappears visually).
    pub fn edit_cell_rect(&mut self, row: i32, col: i32) -> Option<(i32, i32, i32, i32)> {
        let (mut x, y, mut w, h) = self.cell_screen_rect(row, col)?;

        // Only extend for data rows, non-merged cells, when text_overflow is on.
        let is_merged = self
            .get_merged_range(row, col)
            .map_or(false, |(r1, c1, r2, c2)| r1 != r2 || c1 != c2);
        if !self.text_overflow || row < self.fixed_rows || is_merged {
            return Some((x, y, w, h));
        }

        // Use the current edit text if this cell is being edited, otherwise
        // the display text.
        let text =
            if self.edit.is_active() && self.edit.edit_row == row && self.edit.edit_col == col {
                self.edit.edit_text.clone()
            } else {
                self.get_display_text(row, col)
            };
        if text.is_empty() {
            return Some((x, y, w, h));
        }

        // Resolve font for measurement.
        let style_override = self.get_cell_style(row, col);
        let font_name = style_override
            .font_name
            .clone()
            .unwrap_or_else(|| self.style.font_name.clone());
        let font_size = style_override.font_size.unwrap_or(self.style.font_size);
        let font_bold = style_override.font_bold.unwrap_or(self.style.font_bold);
        let font_italic = style_override.font_italic.unwrap_or(self.style.font_italic);

        // Account for cell padding.
        let cell_padding = self.resolve_cell_padding(row, col, &style_override);
        let inner_w = (w - cell_padding.left - cell_padding.right).max(1);

        // Measure text width.  When the text engine has fonts we get an
        // accurate measurement; otherwise fall back to a character-count
        // heuristic (~0.6 × font_size per character for proportional fonts).
        let te = self.ensure_text_engine();
        let tw = if te.has_fonts() {
            te.measure_text(&text, &font_name, font_size, font_bold, font_italic, None)
                .0
        } else {
            text.chars().count() as f32 * font_size * 0.6
        };

        // Text fits within the cell — no extension needed.
        if tw <= inner_w as f32 {
            return Some((x, y, w, h));
        }

        // Resolve horizontal alignment to decide scan direction.
        let alignment = crate::canvas::resolve_alignment(self, row, col, &style_override, &text);
        let (halign, _) = crate::canvas::alignment_components(alignment);

        // Determine scan directions (flip for RTL).
        let scan_right = if self.right_to_left {
            halign == 2
        } else {
            halign == 0 || halign == 1
        };
        let scan_left = if self.right_to_left {
            halign == 0 || halign == 1
        } else {
            halign == 2 || halign == 1
        };

        let mut right_ext: i32 = 0;
        let mut left_ext: i32 = 0;

        // Scan rightward into empty neighbors.
        if scan_right {
            let mut c = col + 1;
            while c < self.cols {
                if self.is_col_hidden(c) {
                    c += 1;
                    continue;
                }
                if self
                    .get_merged_range(row, c)
                    .map_or(false, |(r1, c1, r2, c2)| r1 != r2 || c1 != c2)
                {
                    break;
                }
                if !self.get_display_text(row, c).is_empty() {
                    break;
                }
                right_ext += self.get_col_width(c);
                if (inner_w + left_ext + right_ext) as f32 >= tw {
                    break;
                }
                c += 1;
            }
        }

        // Scan leftward into empty neighbors.
        if scan_left {
            let mut c = col - 1;
            while c >= self.fixed_cols {
                if self.is_col_hidden(c) {
                    c -= 1;
                    continue;
                }
                if self
                    .get_merged_range(row, c)
                    .map_or(false, |(r1, c1, r2, c2)| r1 != r2 || c1 != c2)
                {
                    break;
                }
                if !self.get_display_text(row, c).is_empty() {
                    break;
                }
                left_ext += self.get_col_width(c);
                if (inner_w + left_ext + right_ext) as f32 >= tw {
                    break;
                }
                c -= 1;
            }
        }

        // cell_screen_rect() already applied the RTL x-flip, so we adjust
        // in screen coordinates: left_ext shrinks x, right_ext grows w.
        if self.right_to_left {
            x -= right_ext;
            w += left_ext + right_ext;
        } else {
            x -= left_ext;
            w += left_ext + right_ext;
        }

        Some((x, y, w, h))
    }

    /// Approximate the display-text caret index from a click inside the cell.
    ///
    /// Used for spreadsheet-style double-click editing: edit mode opens with
    /// the caret nearest the clicked glyph boundary rather than selecting all.
    pub fn caret_index_from_display_click(&mut self, row: i32, col: i32, x_in_cell: f32) -> i32 {
        if row < 0 || row >= self.rows || col < 0 || col >= self.cols || !self.layout.valid {
            return 0;
        }

        let meta = self.build_text_cell_static_meta(row, col);
        if meta.suppress_text || meta.display_text.is_empty() {
            return 0;
        }

        let text = meta.display_text.as_ref();
        let (_, _, cw, ch) = self.layout.cell_rect(row, col);
        let font_name = meta
            .style_override
            .font_name
            .clone()
            .unwrap_or_else(|| self.style.font_name.clone());
        let font_size = meta
            .style_override
            .font_size
            .unwrap_or(self.style.font_size);
        let font_bold = meta
            .style_override
            .font_bold
            .unwrap_or(self.style.font_bold);
        let font_italic = meta
            .style_override
            .font_italic
            .unwrap_or(self.style.font_italic);

        let button_reserve = if self.edit_trigger_mode > 0
            && meta.has_dropdown_list
            && match self.dropdown_trigger {
                b if b == pb::DropdownTrigger::DropdownAlways as i32 => true,
                3 => self.selection.row == row && self.selection.col == col,
                _ => false,
            } {
            crate::canvas::dropdown_button_rect(0, 0, cw, ch).map_or(0, |(_, _, bw, _)| bw + 2)
        } else {
            0
        };

        let inner_left = meta.padding.left;
        let inner_right = (cw - button_reserve - meta.padding.right).max(inner_left + 1);
        let inner_w = (inner_right - inner_left).max(1);
        let (halign, _) = crate::canvas::alignment_components(meta.alignment);

        let te = self.ensure_text_engine();
        let measure_width = |sample: &str, size: f32, te: &mut TextEngine| -> f32 {
            if te.has_fonts() {
                te.measure_text(sample, &font_name, size, font_bold, font_italic, None)
                    .0
            } else {
                sample.chars().count() as f32 * size * 0.6
            }
        };

        let mut effective_font_size = font_size;
        let mut text_w = measure_width(text, effective_font_size, te);
        if meta.shrink_to_fit && text_w > inner_w as f32 && inner_w > 0 {
            let scale = inner_w as f32 / text_w;
            effective_font_size = (font_size * scale).floor().max(6.0);
            text_w = measure_width(text, effective_font_size, te);
        }

        let text_x = match halign {
            0 => inner_left,
            1 => inner_left + (inner_w - text_w.ceil() as i32) / 2,
            _ => inner_right - text_w.ceil() as i32,
        };

        let relative_x = x_in_cell - text_x as f32;
        if relative_x <= 0.0 {
            return 0;
        }

        let char_count = text.chars().count() as i32;
        if relative_x >= text_w {
            return char_count;
        }

        let mut prefix = String::new();
        let mut prev_w = 0.0f32;
        let mut pos = 0i32;
        for ch in text.chars() {
            prefix.push(ch);
            let next_w = measure_width(&prefix, effective_font_size, te);
            if next_w >= relative_x {
                if pos > 0 && (relative_x - prev_w) < (next_w - relative_x) {
                    return pos;
                }
                return pos + 1;
            }
            prev_w = next_w;
            pos += 1;
        }

        char_count
    }

    /// Resolve the active editor's horizontal alignment.
    ///
    /// Returns 0 for left, 1 for center, 2 for right.
    pub fn edit_horizontal_alignment(&self) -> i32 {
        if !self.edit.is_active() {
            return 0;
        }

        let row = self.edit.edit_row;
        let col = self.edit.edit_col;
        if row < 0 || row >= self.rows || col < 0 || col >= self.cols {
            return 0;
        }

        let style_override = self.get_cell_style(row, col);
        let alignment =
            crate::canvas::resolve_alignment(self, row, col, &style_override, &self.edit.edit_text);
        let (halign, _) = crate::canvas::alignment_components(alignment);
        halign
    }

    /// Hit-test a pixel coordinate against the active dropdown.
    /// Returns the dropdown item index if the point is inside the dropdown,
    /// or `None` if outside or no dropdown is active.
    pub fn dropdown_hit_index(&self, px: f32, py: f32) -> Option<i32> {
        if self.is_tui_mode() {
            return None;
        }
        if !self.edit.is_active() {
            return None;
        }
        let row = self.edit.edit_row;
        let col = self.edit.edit_col;
        if row < 0 || row >= self.rows || col < 0 || col >= self.cols {
            return None;
        }

        let list = self.active_dropdown_list(row, col);
        if list.is_empty() {
            return None;
        }

        let drop = crate::canvas::active_dropdown_popup_geometry(
            self,
            self.cell_screen_rect(row, col)?,
            self.viewport_width,
            self.viewport_height,
        )?;

        let mx = px as i32;
        let my = py as i32;
        if mx < drop.x || mx >= drop.x + drop.w || my < drop.y || my >= drop.y + drop.h {
            return None;
        }

        let slot = ((my - drop.y) / drop.item_h).clamp(0, drop.visible_count - 1);
        let idx = drop.start + slot;
        let count = self.edit.dropdown_count();
        if idx >= 0 && idx < count {
            Some(idx)
        } else {
            None
        }
    }
}

/// Truncate a string to at most `max_chars` characters.
fn truncate_chars(input: &str, max_chars: i32) -> String {
    if max_chars <= 0 {
        return input.to_string();
    }
    input.chars().take(max_chars as usize).collect()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::event::GridEventData;
    use crate::proto::volvoxgrid::v1 as pb;
    use std::time::Duration;

    fn pull_to_refresh_test_grid() -> VolvoxGrid {
        let mut grid = VolvoxGrid::new(1, 320, 240, 20, 4, 1, 0);
        grid.pull_to_refresh_enabled = true;
        grid
    }

    fn drain_event_data(grid: &mut VolvoxGrid) -> Vec<GridEventData> {
        grid.events
            .drain()
            .into_iter()
            .map(|event| event.data)
            .collect()
    }

    #[test]
    fn format_string_sets_columns() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 5, 1, 1, 0);
        grid.format_string = "<Name|>Amount;120|^Status".to_string();
        grid.apply_format_string();

        assert_eq!(grid.cols, 3);
        assert_eq!(grid.cells.get_text(0, 0), "Name");
        assert_eq!(grid.cells.get_text(0, 1), "Amount");
        assert_eq!(grid.cells.get_text(0, 2), "Status");
        assert_eq!(grid.columns[0].alignment, 1); // LEFT_CENTER
        assert_eq!(grid.columns[1].alignment, 7); // RIGHT_CENTER
        assert_eq!(grid.columns[2].alignment, 4); // CENTER_CENTER
        assert_eq!(grid.get_col_width(1), 120);
    }

    #[test]
    fn edit_horizontal_alignment_tracks_effective_cell_alignment() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.edit_trigger_mode = 1;
        grid.columns[0].alignment = pb::Align::RightCenter as i32;
        grid.cells.set_text(1, 0, "123".to_string());

        grid.begin_edit(1, 0);

        assert!(grid.is_editing());
        assert_eq!(grid.edit_horizontal_alignment(), 2);
    }

    #[test]
    fn col_format_currency() {
        let result = apply_col_format("1234567.89", "$#,##0.00");
        assert_eq!(result, Some("$1,234,567.89".to_string()));
    }

    #[test]
    fn col_format_percentage() {
        let result = apply_col_format("0.75", "0.0%");
        assert_eq!(result, Some("75.0%".to_string()));
    }

    #[test]
    fn col_format_thousands() {
        let result = apply_col_format("1234", "#,##0");
        assert_eq!(result, Some("1,234".to_string()));
    }

    #[test]
    fn col_format_non_numeric_returns_none() {
        let result = apply_col_format("hello", "#,##0.00");
        assert_eq!(result, None);
    }

    #[test]
    fn col_format_display_text() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.columns[1].format = "$#,##0.00".to_string();
        grid.cells.set_text(1, 1, "1234.5".to_string());
        let display = grid.get_display_text(1, 1);
        assert_eq!(display, "$1,234.50");
    }

    #[test]
    fn col_format_short_date_accepts_timestamp_millis() {
        let result = apply_col_format("1764547200000", "short date");
        assert_eq!(result, Some("12/01/2025".to_string()));
    }

    #[test]
    fn date_columns_default_to_iso_display_for_timestamp_storage() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 2, 1, 0, 0);
        grid.columns[0].data_type = pb::ColumnDataType::ColumnDataDate as i32;
        grid.cells.set_text(0, 0, "1764547200000".to_string());

        assert_eq!(grid.get_display_text(0, 0), "2025-12-01");
    }

    #[test]
    fn auto_resize_col_uses_cell_font_style_overrides() {
        let mut grid = VolvoxGrid::new(1, 320, 200, 1, 1, 0, 0);
        grid.default_col_width = 10;
        grid.auto_resize = true;
        grid.cells.set_text(0, 0, "1234567".to_string());

        grid.auto_resize_col(0);
        let before = grid.get_col_width(0);

        grid.cell_styles.insert(
            (0, 0),
            crate::style::CellStylePatch {
                font_bold: Some(true),
                font_size: Some(24.0),
                ..Default::default()
            },
        );

        grid.auto_resize_col(0);

        assert!(grid.get_col_width(0) > before);
    }

    #[test]
    fn auto_resize_row_uses_cell_font_style_overrides() {
        let mut grid = VolvoxGrid::new(1, 320, 200, 1, 1, 0, 0);
        grid.default_col_width = 24;
        grid.default_row_height = 16;
        grid.word_wrap = true;
        grid.auto_resize = true;
        grid.cells
            .set_text(0, 0, "wrapped text wrapped text wrapped text".to_string());

        grid.auto_resize_row(0);
        let before = grid.get_row_height(0);

        grid.cell_styles.insert(
            (0, 0),
            crate::style::CellStylePatch {
                font_bold: Some(true),
                font_size: Some(24.0),
                ..Default::default()
            },
        );

        grid.auto_resize_row(0);

        assert!(grid.get_row_height(0) > before);
    }

    #[test]
    fn add_item_inserts_row() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 2, 3, 1, 0);
        grid.cells.set_text(1, 0, "original".to_string());
        grid.add_item("A\tB\tC", 1);

        assert_eq!(grid.rows, 3);
        assert_eq!(grid.cells.get_text(1, 0), "A");
        assert_eq!(grid.cells.get_text(1, 1), "B");
        assert_eq!(grid.cells.get_text(1, 2), "C");
        assert_eq!(grid.cells.get_text(2, 0), "original");
    }

    #[test]
    fn add_item_shifts_cell_styles() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 2, 3, 1, 0);
        grid.cell_styles.insert(
            (1, 1),
            crate::style::CellStylePatch {
                font_bold: Some(true),
                ..Default::default()
            },
        );

        grid.add_item("A\tB\tC", 1);
        assert!(grid.cell_styles.contains_key(&(2, 1)));
        assert!(!grid.cell_styles.contains_key(&(1, 1)));
    }

    #[test]
    fn remove_item_shifts_rows() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 4, 2, 1, 0);
        grid.cells.set_text(1, 0, "row1".to_string());
        grid.cells.set_text(2, 0, "row2".to_string());
        grid.cells.set_text(3, 0, "row3".to_string());
        grid.remove_item(2);

        assert_eq!(grid.rows, 3);
        assert_eq!(grid.cells.get_text(1, 0), "row1");
        assert_eq!(grid.cells.get_text(2, 0), "row3");
    }

    #[test]
    fn remove_item_shifts_cell_styles() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 4, 2, 1, 0);
        grid.cell_styles.insert(
            (3, 1),
            crate::style::CellStylePatch {
                font_italic: Some(true),
                ..Default::default()
            },
        );

        grid.remove_item(2);
        assert!(grid.cell_styles.contains_key(&(2, 1)));
        assert!(!grid.cell_styles.contains_key(&(3, 1)));
    }

    #[test]
    fn remove_item_rejects_fixed_row() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 2, 1, 0);
        grid.remove_item(0); // fixed row
        assert_eq!(grid.rows, 3); // unchanged
    }

    #[test]
    fn clear_everything_scrollable_removes_in_range_pin_and_sticky_state() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 4, 4, 1, 1);

        grid.set_row_sticky(0, 1);
        grid.set_col_sticky(0, 3);
        grid.pin_row(1, 1);
        grid.pin_row(2, 2);
        grid.pin_col(1, 1);
        grid.pin_col(2, 2);
        grid.set_row_sticky(1, 1);
        grid.set_row_sticky(2, 2);
        grid.set_col_sticky(1, 3);
        grid.set_col_sticky(2, 4);
        grid.set_cell_sticky(1, 1, 1, 3);
        grid.set_cell_sticky(2, 2, 2, 4);

        grid.clear_region(0, 0);

        assert_eq!(grid.effective_sticky_row(0, 0), 1);
        assert_eq!(grid.effective_sticky_col(0, 0), 3);

        assert_eq!(grid.is_row_pinned(1), 0);
        assert_eq!(grid.is_row_pinned(2), 0);
        assert_eq!(grid.is_col_pinned(1), 0);
        assert_eq!(grid.is_col_pinned(2), 0);
        assert_eq!(grid.effective_sticky_row(1, 1), 0);
        assert_eq!(grid.effective_sticky_row(2, 2), 0);
        assert_eq!(grid.effective_sticky_col(1, 1), 0);
        assert_eq!(grid.effective_sticky_col(2, 2), 0);
        assert!(!grid.sticky_cells.contains_key(&(1, 1)));
        assert!(!grid.sticky_cells.contains_key(&(2, 2)));
    }

    #[test]
    fn active_dropdown_list_hidden_for_header_and_subtotal_rows() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 4, 2, 1, 0);
        grid.columns[1].dropdown_items = "A|B|C".to_string();
        grid.row_props.entry(2).or_default().is_subtotal = true;

        // Header row: dropdown disabled.
        assert_eq!(grid.active_dropdown_list(0, 1), "");
        // Normal data row: dropdown enabled.
        assert_eq!(grid.active_dropdown_list(1, 1), "A|B|C");
        // Subtotal row: dropdown disabled.
        assert_eq!(grid.active_dropdown_list(2, 1), "");
    }

    #[test]
    fn dropdown_hit_index_is_disabled_in_tui_mode() {
        let mut grid = VolvoxGrid::new(1, 20, 6, 2, 1, 0, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.columns[0].dropdown_items = "A|B|C".to_string();
        grid.cells.set_text(0, 0, "A".to_string());
        grid.begin_edit(0, 0);

        assert_eq!(grid.dropdown_hit_index(5.0, 3.0), None);
    }

    #[test]
    fn resolved_cell_control_prefers_explicit_metadata_over_dropdown_inference() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 1, 1, 0);
        grid.columns[0].dropdown_items = "A|B|C".to_string();

        assert_eq!(
            grid.resolved_cell_control(1, 0),
            CellControl::DropdownButton
        );

        grid.columns[0].control = CellControl::EllipsisButton;
        assert_eq!(
            grid.resolved_cell_control(1, 0),
            CellControl::EllipsisButton
        );

        grid.cells.get_mut(1, 0).extra_mut().control = Some(CellControl::None);
        assert_eq!(grid.resolved_cell_control(1, 0), CellControl::None);
    }

    #[test]
    fn resolved_cell_control_hides_inferred_dropdown_for_header_and_subtotal_rows() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 4, 1, 1, 0);
        grid.columns[0].dropdown_items = "A|B|C".to_string();
        grid.row_props.entry(2).or_default().is_subtotal = true;

        assert_eq!(grid.resolved_cell_control(0, 0), CellControl::None);
        assert_eq!(
            grid.resolved_cell_control(1, 0),
            CellControl::DropdownButton
        );
        assert_eq!(grid.resolved_cell_control(2, 0), CellControl::None);
    }

    #[test]
    fn begin_edit_blocked_for_header_and_subtotal_rows() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 4, 2, 1, 0);
        grid.edit_trigger_mode = 2;
        grid.row_props.entry(2).or_default().is_subtotal = true;

        // Header row: must stay read-only.
        grid.begin_edit(0, 1);
        assert!(!grid.is_editing());

        // Subtotal/grandtotal row: must stay read-only.
        grid.begin_edit(2, 1);
        assert!(!grid.is_editing());

        // Normal data row: editable.
        grid.begin_edit(1, 1);
        assert!(grid.is_editing());
        assert_eq!(grid.edit.edit_row, 1);
        assert_eq!(grid.edit.edit_col, 1);
    }

    #[test]
    fn can_begin_edit_force_does_not_override_header_or_subtotal_lock() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 4, 2, 1, 0);
        grid.edit_trigger_mode = 0;
        grid.row_props.entry(2).or_default().is_subtotal = true;

        // Force bypasses edit_trigger_mode for normal data rows.
        assert!(grid.can_begin_edit(1, 1, true));
        assert!(!grid.can_begin_edit(1, 1, false));

        // But force must not bypass row-level read-only constraints.
        assert!(!grid.can_begin_edit(0, 1, true)); // header
        assert!(!grid.can_begin_edit(2, 1, true)); // subtotal/grandtotal
    }

    #[test]
    fn interactive_cells_do_not_begin_edit_even_with_force() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 4, 2, 1, 0);
        grid.edit_trigger_mode = 2;
        grid.columns[1].interaction = pb::CellInteraction::TextLink as i32;

        assert!(!grid.can_begin_edit(1, 1, false));
        assert!(!grid.can_begin_edit(1, 1, true));

        grid.begin_edit(1, 1);
        assert!(!grid.is_editing());
    }

    #[test]
    fn commit_edit_resyncs_explicit_progress_from_text() {
        let mut grid = VolvoxGrid::new(1, 320, 200, 2, 1, 1, 0);
        grid.edit_trigger_mode = 2;
        grid.cells.set_text(1, 0, "25".to_string());
        {
            let extra = grid.cells.get_mut(1, 0).extra_mut();
            extra.progress_percent = 0.25;
            extra.progress_color = 0xFF22C55E;
        }

        grid.begin_edit(1, 0);
        grid.edit.edit_text = "80".to_string();

        assert!(grid.commit_edit());
        let cell = grid.cells.get(1, 0).unwrap();
        assert_eq!(cell.text, "80");
        assert!((cell.progress_percent() - 0.8).abs() < 1e-6);
        assert_eq!(cell.progress_color(), 0xFF22C55E);
    }

    #[test]
    fn remap_col_index_for_move_handles_both_directions() {
        // Move source=1 to insert=3: [0,1,2,3] -> [0,2,3,1]
        assert_eq!(VolvoxGrid::remap_col_index_for_move(1, 1, 3), 3);
        assert_eq!(VolvoxGrid::remap_col_index_for_move(2, 1, 3), 1);
        assert_eq!(VolvoxGrid::remap_col_index_for_move(3, 1, 3), 2);
        assert_eq!(VolvoxGrid::remap_col_index_for_move(0, 1, 3), 0);

        // Move source=3 to insert=1: [0,1,2,3] -> [0,3,1,2]
        assert_eq!(VolvoxGrid::remap_col_index_for_move(3, 3, 1), 1);
        assert_eq!(VolvoxGrid::remap_col_index_for_move(1, 3, 1), 2);
        assert_eq!(VolvoxGrid::remap_col_index_for_move(2, 3, 1), 3);
        assert_eq!(VolvoxGrid::remap_col_index_for_move(0, 3, 1), 0);
    }

    #[test]
    fn remap_span_cols_after_move_follows_moved_column() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 3, 4, 1, 0);
        grid.span.span_cols.insert(1, true);
        grid.span.span_cols.insert(-1, true); // keep "all cols" sentinel untouched

        grid.remap_span_cols_after_move(1, 3);
        assert_eq!(grid.span.span_cols.get(&3), Some(&true));
        assert_eq!(grid.span.span_cols.get(&1), None);
        assert_eq!(grid.span.span_cols.get(&-1), Some(&true));
    }

    #[test]
    fn move_col_by_positions_reorders_physical_column_state() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 2, 4, 1, 0);
        grid.cells.set_text(0, 0, "A".to_string());
        grid.cells.set_text(0, 1, "B".to_string());
        grid.cells.set_text(0, 2, "C".to_string());
        grid.cells.set_text(0, 3, "D".to_string());
        grid.col_widths.insert(1, 99);
        grid.col_width_min.insert(2, 40);
        grid.cols_hidden.insert(3);

        assert!(grid.move_col_by_positions(1, 3)); // [A,B,C,D] -> [A,C,D,B]

        assert_eq!(grid.cells.get_text(0, 0), "A");
        assert_eq!(grid.cells.get_text(0, 1), "C");
        assert_eq!(grid.cells.get_text(0, 2), "D");
        assert_eq!(grid.cells.get_text(0, 3), "B");
        assert_eq!(grid.col_widths.get(&3), Some(&99));
        assert_eq!(grid.col_width_min.get(&1), Some(&40));
        assert!(grid.cols_hidden.contains(&2));
        assert_eq!(grid.col_positions, vec![0, 1, 2, 3]);
    }

    #[test]
    fn heap_size_bytes_tracks_cell_data_growth_and_clear() {
        let mut grid = VolvoxGrid::new(1, 640, 480, 4, 4, 1, 0);
        let base = grid.heap_size_bytes();
        assert!(base > 0);

        grid.cells.set_text(1, 1, "x".repeat(2048));
        grid.cells.set_text(2, 2, "y".repeat(4096));
        let grown = grid.heap_size_bytes();
        assert!(grown > base);

        grid.cells = CellStore::new();
        let reduced = grid.heap_size_bytes();
        assert!(reduced < grown);
    }

    #[test]
    fn cell_and_edit_rect_include_indicator_band_offsets() {
        let mut grid = VolvoxGrid::new(1, 320, 200, 4, 4, 0, 0);
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.width_px = 35;
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.default_row_height_px = 24;
        grid.ensure_layout();

        let cell = grid.cell_screen_rect(1, 1).expect("cell rect");
        assert_eq!(cell.0, grid.indicator_start_width() + grid.col_pos(1));
        assert_eq!(cell.1, grid.indicator_top_height() + grid.row_pos(1));

        let edit = grid.edit_cell_rect(1, 1).expect("edit rect");
        assert_eq!(edit.0, cell.0);
        assert_eq!(edit.1, cell.1);
    }

    #[test]
    fn cell_screen_rect_expands_horizontal_merge_for_pinned_bottom_row() {
        let mut grid = VolvoxGrid::new(1, 240, 120, 4, 4, 0, 0);
        for row in 0..grid.rows {
            grid.set_row_height(row, 20);
        }
        for col in 0..grid.cols {
            grid.set_col_width(col, 40);
        }
        grid.cells.set_text(3, 0, "Grand Total".to_string());
        grid.merge_cells(3, 0, 3, 2);
        grid.pin_row(3, 2);
        grid.ensure_layout();

        let anchor = grid.cell_screen_rect(3, 0).expect("anchor rect");
        let middle = grid.cell_screen_rect(3, 1).expect("middle rect");
        let tail = grid.cell_screen_rect(3, 2).expect("tail rect");

        assert_eq!(anchor, middle);
        assert_eq!(anchor, tail);
        assert!(anchor.2 > grid.col_width(0));
        assert!(anchor.3 > 0);
    }

    #[test]
    fn cell_screen_rect_extends_last_visible_column_when_trailing_column_is_hidden() {
        let mut grid = VolvoxGrid::new(1, 220, 120, 3, 4, 0, 0);
        grid.extend_last_col = true;
        for col in 0..grid.cols {
            grid.set_col_width(col, 40);
        }
        grid.cols_hidden.insert(3);
        grid.ensure_layout();

        let rect = grid.cell_screen_rect(1, 2).expect("cell rect");

        assert_eq!(rect.0, 80);
        assert_eq!(rect.2, 140);
    }

    #[test]
    fn set_top_row_clamps_to_last_valid_viewport() {
        let mut grid = VolvoxGrid::new(1, 120, 30, 10, 3, 0, 0);
        grid.default_row_height = 10;

        grid.set_top_row(9);

        assert_eq!(grid.scroll.scroll_y, 70.0);
        assert_eq!(grid.top_row(), 7);
        assert_eq!(grid.bottom_row(), 9);
    }

    #[test]
    fn set_left_col_clamps_to_last_valid_viewport() {
        let mut grid = VolvoxGrid::new(1, 30, 120, 3, 10, 0, 0);
        grid.default_col_width = 10;

        grid.set_left_col(9);

        assert_eq!(grid.scroll.scroll_x, 70.0);
        assert_eq!(grid.left_col(), 7);
        assert_eq!(grid.right_col(), 9);
    }

    #[test]
    fn clear_dirty_keeps_overlay_scrollbar_fade_animating() {
        let mut grid = VolvoxGrid::new(1, 200, 120, 50, 12, 1, 1);
        grid.animation.enabled = true;
        grid.scrollbar_appearance = pb::ScrollBarAppearance::ScrollbarAppearanceOverlay as i32;
        grid.scrollbar_show_h = pb::ScrollBarMode::ScrollbarModeAuto as i32;
        grid.scrollbar_fade_delay_ms = 0;
        grid.scrollbar_fade_duration_ms = 100;
        grid.scrollbar_fade_opacity = 1.0;
        grid.scrollbar_fade_timer = 0.0;
        grid.scrollbar_fade_last_tick = Some(Instant::now() - Duration::from_millis(16));

        grid.ensure_layout();
        grid.clear_dirty();

        assert!(grid.dirty);
        assert!(grid.scrollbar_fade_opacity < 1.0);
        assert!(grid.scrollbar_fade_last_tick.is_some());
    }

    #[test]
    fn clear_dirty_stops_once_overlay_scrollbar_fade_finishes() {
        let mut grid = VolvoxGrid::new(1, 200, 120, 50, 12, 1, 1);
        grid.animation.enabled = true;
        grid.scrollbar_appearance = pb::ScrollBarAppearance::ScrollbarAppearanceOverlay as i32;
        grid.scrollbar_show_h = pb::ScrollBarMode::ScrollbarModeAuto as i32;
        grid.scrollbar_fade_delay_ms = 0;
        grid.scrollbar_fade_duration_ms = 1;
        grid.scrollbar_fade_opacity = 0.1;
        grid.scrollbar_fade_timer = 0.0;
        grid.scrollbar_fade_last_tick = Some(Instant::now() - Duration::from_millis(16));

        grid.ensure_layout();
        grid.clear_dirty();

        assert!(!grid.dirty);
        assert_eq!(grid.scrollbar_fade_opacity, 0.0);
        assert!(grid.scrollbar_fade_last_tick.is_none());
    }

    #[test]
    fn clear_dirty_does_not_run_overlay_scrollbar_fade_when_animation_disabled() {
        let mut grid = VolvoxGrid::new(1, 200, 120, 50, 12, 1, 1);
        grid.animation.enabled = false;
        grid.scrollbar_appearance = pb::ScrollBarAppearance::ScrollbarAppearanceOverlay as i32;
        grid.scrollbar_show_h = pb::ScrollBarMode::ScrollbarModeAuto as i32;
        grid.scrollbar_fade_delay_ms = 0;
        grid.scrollbar_fade_duration_ms = 100;
        grid.scrollbar_fade_opacity = 0.4;
        grid.scrollbar_fade_timer = 0.0;
        grid.scrollbar_fade_last_tick = Some(Instant::now() - Duration::from_millis(16));

        grid.ensure_layout();
        grid.clear_dirty();

        assert!(!grid.dirty);
        assert_eq!(grid.scrollbar_fade_opacity, 1.0);
        assert_eq!(grid.scrollbar_fade_timer, 0.0);
        assert!(grid.scrollbar_fade_last_tick.is_none());
    }

    #[test]
    fn auto_resize_all_expands_columns_when_enabled() {
        let mut grid = VolvoxGrid::new(1, 320, 200, 1, 1, 0, 0);
        grid.default_col_width = 20;
        grid.auto_resize = true;
        grid.auto_size_mode = 1;
        grid.cells.set_text(0, 0, "A much longer value".to_string());

        let before = grid.get_col_width(0);
        grid.auto_resize_all();

        assert!(grid.get_col_width(0) > before);
    }

    #[test]
    fn auto_resize_col_expands_for_caption_header_text() {
        let mut grid = VolvoxGrid::new(1, 320, 200, 1, 1, 0, 0);
        grid.default_col_width = 20;
        grid.auto_resize = true;
        grid.columns[0].caption = "A much longer header".to_string();

        let before = grid.get_col_width(0);
        grid.auto_resize_col(0);

        assert!(grid.get_col_width(0) > before);
    }

    #[test]
    fn auto_resize_col_reserves_dropdown_button_width() {
        let mut plain = VolvoxGrid::new(1, 320, 200, 1, 1, 0, 0);
        plain.default_col_width = 10;
        plain.auto_resize = true;
        plain.auto_resize_col(0);

        let mut dropdown = VolvoxGrid::new(1, 320, 200, 1, 1, 0, 0);
        dropdown.default_col_width = 10;
        dropdown.auto_resize = true;
        dropdown.dropdown_trigger = pb::DropdownTrigger::DropdownAlways as i32;
        dropdown.columns[0].dropdown_items = "A|B|C".to_string();
        dropdown.auto_resize_col(0);

        assert!(dropdown.get_col_width(0) > plain.get_col_width(0));
    }

    #[test]
    fn auto_resize_all_reserves_dropdown_button_width() {
        let mut plain = VolvoxGrid::new(1, 320, 200, 1, 1, 0, 0);
        plain.default_col_width = 10;
        plain.auto_resize = true;
        plain.auto_size_mode = 1;
        plain.auto_resize_all();

        let mut dropdown = VolvoxGrid::new(1, 320, 200, 1, 1, 0, 0);
        dropdown.default_col_width = 10;
        dropdown.auto_resize = true;
        dropdown.auto_size_mode = 1;
        dropdown.dropdown_trigger = pb::DropdownTrigger::DropdownAlways as i32;
        dropdown.columns[0].dropdown_items = "A|B|C".to_string();
        dropdown.auto_resize_all();

        assert!(dropdown.get_col_width(0) > plain.get_col_width(0));
    }

    #[test]
    fn auto_resize_all_can_expand_rows_in_row_height_mode() {
        let mut grid = VolvoxGrid::new(1, 320, 200, 1, 1, 0, 0);
        grid.default_col_width = 24;
        grid.default_row_height = 16;
        grid.word_wrap = true;
        grid.auto_resize = true;
        grid.auto_size_mode = 2;
        grid.cells
            .set_text(0, 0, "wrapped text wrapped text wrapped text".to_string());

        let before = grid.get_row_height(0);
        grid.auto_resize_all();

        assert!(grid.get_row_height(0) > before);
    }

    #[test]
    fn auto_resize_all_skips_when_disabled() {
        let mut grid = VolvoxGrid::new(1, 320, 200, 1, 1, 0, 0);
        grid.default_col_width = 20;
        grid.auto_resize = false;
        grid.auto_size_mode = 1;
        grid.cells.set_text(0, 0, "A much longer value".to_string());

        let before = grid.get_col_width(0);
        grid.auto_resize_all();

        assert_eq!(grid.get_col_width(0), before);
    }

    #[test]
    fn auto_resize_all_expands_col_top_header_height_for_caption_headers() {
        let mut grid = VolvoxGrid::new(1, 320, 200, 1, 2, 0, 0);
        grid.auto_resize = true;
        grid.auto_size_mode = 2;
        grid.style.font_size = 40.0;
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.indicator_bands.col_top.mode_bits =
            pb::ColIndicatorCellMode::ColIndicatorCellHeaderText as u32;
        grid.columns[0].caption = "품명".to_string();
        grid.columns[1].caption = "고객명".to_string();

        let before = grid.indicator_bands.col_top.row_height_px(0);
        grid.auto_resize_all();

        assert!(grid.indicator_bands.col_top.row_height_px(0) > before);
    }

    #[test]
    fn ensure_layout_auto_sizes_row_indicator_width_by_default_for_row_numbers() {
        let mut grid = VolvoxGrid::new(1, 320, 200, 1200, 2, 0, 0);
        grid.style.font_size = 28.0;
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.mode_bits = pb::RowIndicatorMode::RowIndicatorNumbers as u32;

        let before = grid.indicator_bands.row_start.width_px;
        grid.ensure_layout();

        assert!(grid.indicator_bands.row_start.width_px > before);
    }

    #[test]
    fn ensure_layout_keeps_row_indicator_width_fixed_when_auto_size_is_disabled() {
        let mut grid = VolvoxGrid::new(1, 320, 200, 1200, 2, 0, 0);
        grid.style.font_size = 28.0;
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.auto_size = false;
        grid.indicator_bands.row_start.mode_bits = pb::RowIndicatorMode::RowIndicatorNumbers as u32;

        let before = grid.indicator_bands.row_start.width_px;
        grid.ensure_layout();

        assert_eq!(grid.indicator_bands.row_start.width_px, before);
    }

    #[test]
    fn merge_cells_shrinks_merged_subtotal_caption_anchor_column() {
        let mut grid = VolvoxGrid::new(1, 480, 240, 4, 3, 1, 0);
        grid.default_col_width = 20;
        grid.auto_resize = true;
        grid.auto_size_mode = 1;
        grid.cells.set_text(0, 0, "ID".to_string());
        grid.cells.set_text(0, 1, "Name".to_string());
        grid.cells.set_text(0, 2, "Qty".to_string());
        grid.cells.set_text(1, 0, "A".to_string());
        grid.cells.set_text(1, 2, "1".to_string());
        grid.cells.set_text(2, 0, "B".to_string());
        grid.cells.set_text(2, 2, "2".to_string());
        grid.cells.set_text(3, 0, "C".to_string());
        grid.cells.set_text(3, 2, "3".to_string());

        grid.auto_resize_all();
        let detail_width = grid.get_col_width(0);

        crate::outline::subtotal(
            &mut grid,
            pb::AggregateType::AggSum as i32,
            -1,
            2,
            "Very long subtotal caption",
            0,
            0,
            false,
        );
        let subtotal_row = grid.fixed_rows;
        let widened = grid.get_col_width(0);
        assert!(widened > detail_width);

        grid.merge_cells(subtotal_row, 0, subtotal_row, 1);

        assert_eq!(grid.get_col_width(0), detail_width);
    }

    #[test]
    fn merge_cells_recomputes_subtotal_caption_row_height_using_merged_width() {
        let mut grid = VolvoxGrid::new(1, 480, 240, 3, 3, 1, 0);
        grid.default_col_width = 40;
        grid.default_row_height = 16;
        grid.word_wrap = true;
        grid.auto_resize = true;
        grid.auto_size_mode = 2;
        grid.cells.set_text(0, 0, "ID".to_string());
        grid.cells.set_text(0, 1, "Desc".to_string());
        grid.cells.set_text(0, 2, "Qty".to_string());
        grid.cells.set_text(1, 0, "A".to_string());
        grid.cells.set_text(1, 2, "1".to_string());
        grid.cells.set_text(2, 0, "B".to_string());
        grid.cells.set_text(2, 2, "2".to_string());

        crate::outline::subtotal(
            &mut grid,
            pb::AggregateType::AggSum as i32,
            -1,
            2,
            "Very long subtotal caption that should wrap less after merge",
            0,
            0,
            false,
        );
        let subtotal_row = grid.fixed_rows;
        let before_merge = grid.get_row_height(subtotal_row);

        grid.merge_cells(subtotal_row, 0, subtotal_row, 1);

        assert!(grid.get_row_height(subtotal_row) < before_merge);
    }

    #[test]
    fn pull_to_refresh_below_threshold_cancels() {
        let mut grid = pull_to_refresh_test_grid();

        grid.begin_pull_to_refresh_contact();
        assert!(
            grid.handle_pull_to_refresh_scroll(0.0, -(grid.pull_to_refresh_threshold_px() * 0.5),)
        );
        assert!(matches!(
            grid.pull_to_refresh_state,
            PullToRefreshState::Pulling
        ));

        grid.end_pull_to_refresh_contact();

        let events = drain_event_data(&mut grid);
        assert!(events
            .iter()
            .any(|event| matches!(event, GridEventData::PullToRefreshCanceled)));
        assert!(!events
            .iter()
            .any(|event| matches!(event, GridEventData::PullToRefreshTriggered)));
        assert!(matches!(
            grid.pull_to_refresh_state,
            PullToRefreshState::Idle
        ));
        assert_eq!(grid.pull_to_refresh_reveal_px, 0.0);
        assert_eq!(grid.pull_to_refresh_target_reveal_px, 0.0);
    }

    #[test]
    fn pull_to_refresh_above_threshold_triggers_and_settles_immediately() {
        let mut grid = pull_to_refresh_test_grid();

        grid.begin_pull_to_refresh_contact();
        assert!(
            grid.handle_pull_to_refresh_scroll(0.0, -(grid.pull_to_refresh_threshold_px() * 1.5),)
        );
        assert!(matches!(
            grid.pull_to_refresh_state,
            PullToRefreshState::Armed
        ));

        grid.end_pull_to_refresh_contact();

        let gesture_events = drain_event_data(&mut grid);
        assert!(gesture_events
            .iter()
            .any(|event| matches!(event, GridEventData::PullToRefreshTriggered)));
        assert!(!gesture_events.iter().any(|event| matches!(
            event,
            GridEventData::DataRefreshing | GridEventData::DataRefreshed
        )));
        assert!(matches!(
            grid.pull_to_refresh_state,
            PullToRefreshState::Settling
        ));
        assert_eq!(grid.pull_to_refresh_target_reveal_px, 0.0);

        assert!(grid.tick_pull_to_refresh(1.0));
        assert!(matches!(
            grid.pull_to_refresh_state,
            PullToRefreshState::Idle
        ));
        assert_eq!(grid.pull_to_refresh_reveal_px, 0.0);
    }

    #[test]
    fn pull_to_refresh_ignores_non_top_or_horizontal_drag() {
        let mut grid = pull_to_refresh_test_grid();
        grid.scroll.scroll_y = 16.0;
        grid.begin_pull_to_refresh_contact();

        assert!(
            !grid.handle_pull_to_refresh_scroll(0.0, -(grid.pull_to_refresh_threshold_px() * 1.1),)
        );
        assert_eq!(grid.pull_to_refresh_reveal_px, 0.0);
        assert!(matches!(
            grid.pull_to_refresh_state,
            PullToRefreshState::Idle
        ));

        grid.cancel_pull_to_refresh_contact(false);

        let mut grid = pull_to_refresh_test_grid();
        grid.begin_pull_to_refresh_contact();

        assert!(!grid.handle_pull_to_refresh_scroll(
            grid.pull_to_refresh_touch_slop_px() * 2.0,
            -(grid.pull_to_refresh_touch_slop_px() * 0.75),
        ));
        assert_eq!(grid.pull_to_refresh_reveal_px, 0.0);
        assert!(matches!(
            grid.pull_to_refresh_state,
            PullToRefreshState::Idle
        ));
    }

    #[test]
    fn pull_to_refresh_ignores_fast_scroll_active() {
        let mut grid = pull_to_refresh_test_grid();
        grid.fast_scroll_active = true;
        grid.begin_pull_to_refresh_contact();

        assert!(
            !grid.handle_pull_to_refresh_scroll(0.0, -(grid.pull_to_refresh_threshold_px() * 1.1),)
        );
        assert_eq!(grid.pull_to_refresh_reveal_px, 0.0);
        assert!(matches!(
            grid.pull_to_refresh_state,
            PullToRefreshState::Idle
        ));
    }

    #[test]
    fn pull_to_refresh_tiny_cancel_snaps_closed() {
        let mut grid = pull_to_refresh_test_grid();
        let tiny_pull = (grid.pull_to_refresh_cancel_snap_px() * 0.5).max(2.0);

        grid.begin_pull_to_refresh_contact();
        assert!(grid.handle_pull_to_refresh_scroll(0.0, -tiny_pull));

        grid.end_pull_to_refresh_contact();

        let events = drain_event_data(&mut grid);
        assert!(events
            .iter()
            .any(|event| matches!(event, GridEventData::PullToRefreshCanceled)));
        assert!(matches!(
            grid.pull_to_refresh_state,
            PullToRefreshState::Idle
        ));
        assert_eq!(grid.pull_to_refresh_reveal_px, 0.0);
        assert_eq!(grid.pull_to_refresh_target_reveal_px, 0.0);
    }
}
