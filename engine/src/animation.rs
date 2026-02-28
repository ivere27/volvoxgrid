#[cfg(not(target_arch = "wasm32"))]
use std::time::Instant;
#[cfg(target_arch = "wasm32")]
use web_time::Instant;

use crate::layout::LayoutCache;

/// Default animation duration in milliseconds.
pub const DEFAULT_DURATION_MS: i32 = 200;

/// Smooth layout animation via position-diff + exponential decay.
///
/// When the layout is rebuilt, the old row/col pixel positions are compared
/// against the new ones.  Per-row/col offsets (old − new) are stored and
/// decay exponentially each frame, giving a smooth glide effect for inserts,
/// removes, resizes, hides, shows, and sorts — without per-mutation-site logic.
///
/// The engine ticks internally using `Instant::now()`, so hosts do not need
/// to call any tick method — they only need to keep rendering while `active`
/// is true (the engine sets `dirty = true` for this).
pub struct AnimationState {
    /// Whether animation is enabled.
    pub enabled: bool,
    /// Decay rate (higher = faster), derived from duration_ms.
    speed: f32,
    /// Configured duration in milliseconds (for getter).
    pub duration_ms: i32,
    /// When true, the *next* layout rebuild will not generate offsets.
    /// Used for batch-update (redraw false→true) to suppress visual glitches.
    pub suppress_next: bool,

    // Per-row/col animated pixel offsets (decay toward 0).
    pub row_y_offsets: Vec<f32>,
    pub col_x_offsets: Vec<f32>,

    // Snapshot of the previous layout (saved before rebuild).
    prev_row_positions: Vec<i32>,
    prev_col_positions: Vec<i32>,
    prev_rows: i32,
    prev_cols: i32,
    prev_uniform_rows: bool,
    prev_uniform_row_height: i32,
    prev_uniform_cols: bool,
    prev_uniform_col_width: i32,
    has_prev: bool,

    /// True while any offset is non-zero.
    pub active: bool,

    /// Timestamp of the last tick (for internal dt computation).
    last_tick: Option<Instant>,
}

impl AnimationState {
    /// Convert a duration in milliseconds to the internal decay rate.
    /// After `duration_ms`, the offset decays to ~1% of the original.
    fn duration_to_speed(ms: i32) -> f32 {
        let ms = if ms <= 0 { DEFAULT_DURATION_MS } else { ms };
        // exp(-speed * t) = 0.01  →  speed = ln(100) / t ≈ 4.605 / t
        4.605 / (ms as f32 / 1000.0)
    }

    pub fn new() -> Self {
        Self {
            enabled: false,
            speed: Self::duration_to_speed(DEFAULT_DURATION_MS),
            duration_ms: DEFAULT_DURATION_MS,
            suppress_next: false,
            row_y_offsets: Vec::new(),
            col_x_offsets: Vec::new(),
            prev_row_positions: Vec::new(),
            prev_col_positions: Vec::new(),
            prev_rows: 0,
            prev_cols: 0,
            prev_uniform_rows: false,
            prev_uniform_row_height: 0,
            prev_uniform_cols: false,
            prev_uniform_col_width: 0,
            has_prev: false,
            active: false,
            last_tick: None,
        }
    }

    pub fn heap_size_bytes(&self) -> usize {
        self.row_y_offsets.capacity() * std::mem::size_of::<f32>()
            + self.col_x_offsets.capacity() * std::mem::size_of::<f32>()
            + self.prev_row_positions.capacity() * std::mem::size_of::<i32>()
            + self.prev_col_positions.capacity() * std::mem::size_of::<i32>()
    }

    /// Snapshot the current layout positions *before* a rebuild.
    pub fn save_prev(&mut self, layout: &LayoutCache) {
        if !self.enabled {
            return;
        }
        self.prev_rows = layout.rows;
        self.prev_cols = layout.cols;
        self.prev_uniform_rows = layout.uniform_rows;
        self.prev_uniform_row_height = layout.uniform_row_height;
        self.prev_uniform_cols = layout.uniform_cols;
        self.prev_uniform_col_width = layout.uniform_col_width;
        self.prev_row_positions.clear();
        self.prev_row_positions
            .extend_from_slice(&layout.row_positions);
        self.prev_col_positions.clear();
        self.prev_col_positions
            .extend_from_slice(&layout.col_positions);
        self.has_prev = true;
    }

    /// After a layout rebuild, diff old vs new positions and populate offsets.
    pub fn compute_offsets(&mut self, layout: &LayoutCache) {
        if !self.enabled || !self.has_prev {
            self.has_prev = false;
            return;
        }
        self.has_prev = false;

        if self.suppress_next {
            self.suppress_next = false;
            self.clear();
            return;
        }

        let new_rows = layout.rows;
        let new_cols = layout.cols;

        // Resize offset vecs
        self.row_y_offsets.resize(new_rows.max(0) as usize, 0.0);
        self.col_x_offsets.resize(new_cols.max(0) as usize, 0.0);

        // Compute row Y offsets
        let common_rows = new_rows.min(self.prev_rows).max(0) as usize;
        for r in 0..common_rows {
            let old_y = self.prev_row_pos(r as i32);
            let new_y = layout.row_pos(r as i32);
            let diff = (old_y - new_y) as f32;
            self.row_y_offsets[r] += diff;
        }

        // Compute col X offsets
        let common_cols = new_cols.min(self.prev_cols).max(0) as usize;
        for c in 0..common_cols {
            let old_x = self.prev_col_pos(c as i32);
            let new_x = layout.col_pos(c as i32);
            let diff = (old_x - new_x) as f32;
            self.col_x_offsets[c] += diff;
        }

        self.active = self.row_y_offsets.iter().any(|o| o.abs() >= 0.5)
            || self.col_x_offsets.iter().any(|o| o.abs() >= 0.5);

        if self.active {
            // Reset the clock so the first tick uses a fresh dt
            self.last_tick = Some(Instant::now());
        }
    }

    /// Advance animation using internal clock.  Returns `true` if still active.
    /// Called automatically by the engine (e.g. from `ensure_layout`).
    pub(crate) fn tick(&mut self) -> bool {
        if !self.active {
            return false;
        }
        let now = Instant::now();
        let dt = if let Some(prev) = self.last_tick {
            now.duration_since(prev)
                .as_secs_f32()
                .clamp(1.0 / 240.0, 1.0 / 20.0)
        } else {
            1.0 / 60.0
        };
        self.last_tick = Some(now);

        let factor = (-self.speed * dt).exp();
        let mut any_active = false;
        for o in self.row_y_offsets.iter_mut() {
            *o *= factor;
            if o.abs() < 0.5 {
                *o = 0.0;
            } else {
                any_active = true;
            }
        }
        for o in self.col_x_offsets.iter_mut() {
            *o *= factor;
            if o.abs() < 0.5 {
                *o = 0.0;
            } else {
                any_active = true;
            }
        }

        self.active = any_active;
        any_active
    }

    /// Inject offsets for a row insertion.
    ///
    /// All rows at and after `at` slide down from where they were
    /// (offset = −inserted_height, decaying to 0).
    /// The new row itself gets no offset (it appears in place).
    pub fn notify_rows_inserted(&mut self, at: i32, count: i32, row_height: i32) {
        if !self.enabled || count <= 0 || at < 0 {
            return;
        }
        let total_h = (row_height * count) as f32;
        let new_rows = self.row_y_offsets.len() as i32 + count;
        self.row_y_offsets.resize(new_rows.max(0) as usize, 0.0);

        // Shift existing offsets to make room for inserted rows
        // Move from the end backward to avoid overwriting
        let old_len = new_rows - count;
        for i in (at..old_len).rev() {
            let src = i as usize;
            let dst = (i + count) as usize;
            if dst < self.row_y_offsets.len() && src < self.row_y_offsets.len() {
                self.row_y_offsets[dst] = self.row_y_offsets[src] - total_h;
            }
        }
        // The inserted rows: no offset (they appear at their final position)
        for i in at..(at + count) {
            if (i as usize) < self.row_y_offsets.len() {
                self.row_y_offsets[i as usize] = 0.0;
            }
        }

        self.active = true;
        self.last_tick = Some(Instant::now());
    }

    /// Inject offsets for a row removal.
    ///
    /// All rows at and after `at` slide up from where they were
    /// (offset = +removed_height, decaying to 0).
    pub fn notify_rows_removed(&mut self, at: i32, count: i32, row_height: i32) {
        if !self.enabled || count <= 0 || at < 0 {
            return;
        }
        let total_h = (row_height * count) as f32;
        let new_len = self.row_y_offsets.len() as i32 - count;
        let new_len = new_len.max(0) as usize;

        // Shift offsets up to close the gap, adding removed height
        let old_len = self.row_y_offsets.len();
        for i in (at as usize)..new_len {
            let src = i + count as usize;
            if src < old_len {
                self.row_y_offsets[i] = self.row_y_offsets[src] + total_h;
            }
        }
        self.row_y_offsets.truncate(new_len);

        self.active = true;
        self.last_tick = Some(Instant::now());
    }

    /// Inject offsets for a column insertion.
    pub fn notify_cols_inserted(&mut self, at: i32, count: i32, col_width: i32) {
        if !self.enabled || count <= 0 || at < 0 {
            return;
        }
        let total_w = (col_width * count) as f32;
        let new_cols = self.col_x_offsets.len() as i32 + count;
        self.col_x_offsets.resize(new_cols.max(0) as usize, 0.0);

        let old_len = new_cols - count;
        for i in (at..old_len).rev() {
            let src = i as usize;
            let dst = (i + count) as usize;
            if dst < self.col_x_offsets.len() && src < self.col_x_offsets.len() {
                self.col_x_offsets[dst] = self.col_x_offsets[src] - total_w;
            }
        }
        for i in at..(at + count) {
            if (i as usize) < self.col_x_offsets.len() {
                self.col_x_offsets[i as usize] = 0.0;
            }
        }

        self.active = true;
        self.last_tick = Some(Instant::now());
    }

    /// Inject offsets for a column removal.
    pub fn notify_cols_removed(&mut self, at: i32, count: i32, col_width: i32) {
        if !self.enabled || count <= 0 || at < 0 {
            return;
        }
        let total_w = (col_width * count) as f32;
        let new_len = self.col_x_offsets.len() as i32 - count;
        let new_len = new_len.max(0) as usize;

        let old_len = self.col_x_offsets.len();
        for i in (at as usize)..new_len {
            let src = i + count as usize;
            if src < old_len {
                self.col_x_offsets[i] = self.col_x_offsets[src] + total_w;
            }
        }
        self.col_x_offsets.truncate(new_len);

        self.active = true;
        self.last_tick = Some(Instant::now());
    }

    /// Zero all offsets immediately.
    pub fn clear(&mut self) {
        for o in self.row_y_offsets.iter_mut() {
            *o = 0.0;
        }
        for o in self.col_x_offsets.iter_mut() {
            *o = 0.0;
        }
        self.active = false;
        self.last_tick = None;
    }

    /// Set animation duration in milliseconds. 0 means use default (200ms).
    pub fn set_duration_ms(&mut self, ms: i32) {
        let ms = if ms <= 0 { DEFAULT_DURATION_MS } else { ms };
        self.duration_ms = ms;
        self.speed = Self::duration_to_speed(ms);
    }

    /// Get the animated Y offset for a given row index.
    #[inline]
    pub fn row_offset(&self, row: i32) -> f32 {
        if row < 0 {
            return 0.0;
        }
        self.row_y_offsets.get(row as usize).copied().unwrap_or(0.0)
    }

    /// Get the animated X offset for a given column index.
    #[inline]
    pub fn col_offset(&self, col: i32) -> f32 {
        if col < 0 {
            return 0.0;
        }
        self.col_x_offsets.get(col as usize).copied().unwrap_or(0.0)
    }

    // ── Internal helpers ──────────────────────────────────────────────────

    fn prev_row_pos(&self, row: i32) -> i32 {
        if row <= 0 {
            return 0;
        }
        if self.prev_uniform_rows {
            return row
                .clamp(0, self.prev_rows)
                .saturating_mul(self.prev_uniform_row_height.max(0));
        }
        self.prev_row_positions
            .get(row as usize)
            .copied()
            .unwrap_or(0)
    }

    fn prev_col_pos(&self, col: i32) -> i32 {
        if col <= 0 {
            return 0;
        }
        if self.prev_uniform_cols {
            return col
                .clamp(0, self.prev_cols)
                .saturating_mul(self.prev_uniform_col_width.max(0));
        }
        self.prev_col_positions
            .get(col as usize)
            .copied()
            .unwrap_or(0)
    }
}

impl Default for AnimationState {
    fn default() -> Self {
        Self::new()
    }
}
