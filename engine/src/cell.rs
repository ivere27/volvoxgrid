use std::cell::Cell;
use std::collections::HashMap;

/// Value stored in a cell
#[derive(Clone, Debug)]
pub enum CellValueData {
    Text(String),
    Number(f64),
    Bool(bool),
    Bytes(Vec<u8>),
    Timestamp(i64),
    Empty,
}

impl CellValueData {
    pub fn heap_size_bytes(&self) -> usize {
        match self {
            CellValueData::Text(v) => v.capacity(),
            CellValueData::Bytes(v) => v.capacity(),
            CellValueData::Number(_)
            | CellValueData::Bool(_)
            | CellValueData::Timestamp(_)
            | CellValueData::Empty => 0,
        }
    }
}

static EMPTY_VALUE: CellValueData = CellValueData::Empty;

/// Rarely-used cell properties, boxed to keep `CellData` small.
#[derive(Clone, Debug)]
pub struct CellExtra {
    pub value: CellValueData,
    pub checked: i32,
    pub picture: Option<Vec<u8>>,
    pub picture_format: String,
    pub picture_alignment: i32,
    pub progress_color: u32,
    pub progress_percent: f32,
    pub custom_format: String,
    pub dropdown_items: String,
    pub user_data: Option<Vec<u8>>,
    /// Picture for cell button (distinct from cell picture).
    pub button_picture: Option<Vec<u8>>,
    /// Format of the button picture (e.g. "png", "bmp").
    pub button_picture_format: String,
}

impl Default for CellExtra {
    fn default() -> Self {
        Self {
            value: CellValueData::Empty,
            checked: 0,
            picture: None,
            picture_format: String::new(),
            picture_alignment: 0,
            progress_color: 0,
            progress_percent: 0.0,
            custom_format: String::new(),
            dropdown_items: String::new(),
            user_data: None,
            button_picture: None,
            button_picture_format: String::new(),
        }
    }
}

impl CellExtra {
    pub fn heap_size_bytes(&self) -> usize {
        let mut bytes = 0usize;
        bytes += self.value.heap_size_bytes();
        bytes += self.picture.as_ref().map_or(0, Vec::capacity);
        bytes += self.picture_format.capacity();
        bytes += self.custom_format.capacity();
        bytes += self.dropdown_items.capacity();
        bytes += self.user_data.as_ref().map_or(0, Vec::capacity);
        bytes += self.button_picture.as_ref().map_or(0, Vec::capacity);
        bytes += self.button_picture_format.capacity();
        bytes
    }
}

/// Complete cell data — slim layout: only `text` + optional boxed extras.
///
/// Most cells only need text. Rare properties (value, picture, progress,
/// dropdown items, etc.) are stored in `Option<Box<CellExtra>>` so the
/// common case is only 32 bytes (String + pointer).
#[derive(Clone, Debug)]
pub struct CellData {
    pub text: String,
    pub extra: Option<Box<CellExtra>>,
}

impl Default for CellData {
    fn default() -> Self {
        Self {
            text: String::new(),
            extra: None,
        }
    }
}

impl CellData {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn with_text(text: impl Into<String>) -> Self {
        Self {
            text: text.into(),
            extra: None,
        }
    }

    pub fn display_text(&self) -> &str {
        &self.text
    }

    pub fn heap_size_bytes(&self) -> usize {
        let mut bytes = self.text.capacity();
        if let Some(extra) = self.extra.as_ref() {
            bytes += std::mem::size_of::<CellExtra>();
            bytes += extra.heap_size_bytes();
        }
        bytes
    }

    // ── Accessors for extra fields (return defaults when None) ────────

    pub fn checked(&self) -> i32 {
        self.extra.as_ref().map_or(0, |e| e.checked)
    }

    pub fn progress_percent(&self) -> f32 {
        self.extra.as_ref().map_or(0.0, |e| e.progress_percent)
    }

    pub fn progress_color(&self) -> u32 {
        self.extra.as_ref().map_or(0, |e| e.progress_color)
    }

    pub fn picture(&self) -> Option<&[u8]> {
        self.extra.as_ref().and_then(|e| e.picture.as_deref())
    }

    pub fn picture_alignment(&self) -> i32 {
        self.extra.as_ref().map_or(0, |e| e.picture_alignment)
    }

    pub fn custom_format(&self) -> &str {
        self.extra.as_ref().map_or("", |e| e.custom_format.as_str())
    }

    pub fn dropdown_items(&self) -> &str {
        self.extra
            .as_ref()
            .map_or("", |e| e.dropdown_items.as_str())
    }

    /// Returns a mutable reference to the extra fields, allocating if needed.
    pub fn extra_mut(&mut self) -> &mut CellExtra {
        self.extra
            .get_or_insert_with(|| Box::new(CellExtra::default()))
    }
}

/// Sparse cell storage - only stores cells that have been set.
///
/// Supports an optional `row_map` for O(1) row indirection after sort.
/// When set, all access methods translate display rows to logical (storage)
/// rows via the map, avoiding the need to physically move cells.
pub struct CellStore {
    cells: HashMap<(i32, i32), CellData>,
    /// Display-row → logical-row mapping.  Empty = identity (no translation).
    row_map: Vec<i32>,
    /// Display-col → logical-col mapping.  Empty = identity (no translation).
    col_map: Vec<i32>,
    /// Cached heap size estimate for this store (bytes).
    heap_size_cache: Cell<usize>,
    /// True when `heap_size_cache` reflects current state.
    heap_size_cache_valid: Cell<bool>,
}

impl CellStore {
    pub fn new() -> Self {
        Self {
            cells: HashMap::new(),
            row_map: Vec::new(),
            col_map: Vec::new(),
            heap_size_cache: Cell::new(0),
            heap_size_cache_valid: Cell::new(false),
        }
    }

    pub fn heap_size_bytes(&self) -> usize {
        if self.heap_size_cache_valid.get() {
            return self.heap_size_cache.get();
        }

        let mut bytes = 0usize;
        bytes += self.cells.capacity()
            * (std::mem::size_of::<(i32, i32)>() + std::mem::size_of::<CellData>() + 8);
        for value in self.cells.values() {
            bytes += value.heap_size_bytes();
        }
        bytes += self.row_map.capacity() * std::mem::size_of::<i32>();
        bytes += self.col_map.capacity() * std::mem::size_of::<i32>();
        self.heap_size_cache.set(bytes);
        self.heap_size_cache_valid.set(true);
        bytes
    }

    pub fn with_capacity(cap: usize) -> Self {
        Self {
            cells: HashMap::with_capacity(cap),
            row_map: Vec::new(),
            col_map: Vec::new(),
            heap_size_cache: Cell::new(0),
            heap_size_cache_valid: Cell::new(false),
        }
    }

    #[inline]
    fn invalidate_heap_size_cache(&self) {
        if self.heap_size_cache_valid.get() {
            self.heap_size_cache_valid.set(false);
        }
    }

    // ── Row-map helpers ─────────────────────────────────────────────────

    /// Translate a display row to its logical (storage) row.
    #[inline]
    fn map_row(&self, row: i32) -> i32 {
        if self.row_map.is_empty() {
            row
        } else {
            self.row_map.get(row as usize).copied().unwrap_or(row)
        }
    }

    /// Install a display-row → logical-row mapping (set after sort).
    pub fn set_row_map(&mut self, map: Vec<i32>) {
        self.invalidate_heap_size_cache();
        self.row_map = map;
    }

    /// Clear the row mapping (back to identity).
    pub fn clear_row_map(&mut self) {
        self.invalidate_heap_size_cache();
        self.row_map.clear();
    }

    /// Collapse the row-map by physically remapping all cells so that
    /// storage keys match display rows, then clear the map.
    /// Called before structural operations (insert/remove/clear_range).
    fn materialize_row_map(&mut self) {
        if self.row_map.is_empty() {
            return;
        }
        self.invalidate_heap_size_cache();
        // Build inverse: logical_row → display_row
        let mut inverse: HashMap<i32, i32> = HashMap::with_capacity(self.row_map.len());
        for (display, &logical) in self.row_map.iter().enumerate() {
            inverse.insert(logical, display as i32);
        }
        let old_cells = std::mem::take(&mut self.cells);
        self.cells = HashMap::with_capacity(old_cells.len());
        for ((r, c), cell) in old_cells {
            let display_r = inverse.get(&r).copied().unwrap_or(r);
            self.cells.insert((display_r, c), cell);
        }
        self.row_map.clear();
    }

    // ── Col-map helpers ─────────────────────────────────────────────────

    /// Translate a display col to its logical (storage) col.
    #[inline]
    fn map_col(&self, col: i32) -> i32 {
        if self.col_map.is_empty() {
            col
        } else {
            self.col_map.get(col as usize).copied().unwrap_or(col)
        }
    }

    /// Install a display-col → logical-col mapping.
    pub fn set_col_map(&mut self, map: Vec<i32>) {
        self.invalidate_heap_size_cache();
        self.col_map = map;
    }

    /// Clear the col mapping (back to identity).
    pub fn clear_col_map(&mut self) {
        self.invalidate_heap_size_cache();
        self.col_map.clear();
    }

    /// Whether the col mapping is identity (empty).
    pub fn col_map_is_empty(&self) -> bool {
        self.col_map.is_empty()
    }

    /// Remove an entry from the col_map at the given position.
    pub fn col_map_remove(&mut self, pos: usize) -> i32 {
        self.invalidate_heap_size_cache();
        self.col_map.remove(pos)
    }

    /// Insert a value into the col_map at the given position.
    pub fn col_map_insert(&mut self, pos: usize, val: i32) {
        self.invalidate_heap_size_cache();
        self.col_map.insert(pos, val);
    }

    /// Collapse the col-map by physically remapping all cells so that
    /// storage column keys match display columns, then clear the map.
    fn materialize_col_map(&mut self) {
        if self.col_map.is_empty() {
            return;
        }
        self.invalidate_heap_size_cache();
        let mut inverse: HashMap<i32, i32> = HashMap::with_capacity(self.col_map.len());
        for (display, &logical) in self.col_map.iter().enumerate() {
            inverse.insert(logical, display as i32);
        }
        let old_cells = std::mem::take(&mut self.cells);
        self.cells = HashMap::with_capacity(old_cells.len());
        for ((r, c), cell) in old_cells {
            let display_c = inverse.get(&c).copied().unwrap_or(c);
            self.cells.insert((r, display_c), cell);
        }
        self.col_map.clear();
    }

    // ── Cell access (all translate through row_map + col_map) ────────────

    pub fn get(&self, row: i32, col: i32) -> Option<&CellData> {
        self.cells.get(&(self.map_row(row), self.map_col(col)))
    }

    pub fn get_mut(&mut self, row: i32, col: i32) -> &mut CellData {
        self.invalidate_heap_size_cache();
        let r = self.map_row(row);
        let c = self.map_col(col);
        self.cells.entry((r, c)).or_insert_with(CellData::default)
    }

    pub fn set(&mut self, row: i32, col: i32, data: CellData) {
        self.invalidate_heap_size_cache();
        self.cells
            .insert((self.map_row(row), self.map_col(col)), data);
    }

    pub fn remove(&mut self, row: i32, col: i32) {
        self.invalidate_heap_size_cache();
        self.cells.remove(&(self.map_row(row), self.map_col(col)));
    }

    pub fn get_text(&self, row: i32, col: i32) -> &str {
        match self.cells.get(&(self.map_row(row), self.map_col(col))) {
            Some(cell) => &cell.text,
            None => "",
        }
    }

    pub fn set_text(&mut self, row: i32, col: i32, text: String) {
        let cell = self.get_mut(row, col);
        cell.text = text;
    }

    pub fn get_value(&self, row: i32, col: i32) -> &CellValueData {
        match self.cells.get(&(self.map_row(row), self.map_col(col))) {
            Some(cell) => cell.extra.as_ref().map_or(&EMPTY_VALUE, |e| &e.value),
            None => &EMPTY_VALUE,
        }
    }

    pub fn set_value(&mut self, row: i32, col: i32, value: CellValueData) {
        let cell = self.get_mut(row, col);
        cell.extra_mut().value = value;
    }

    // ── Structural operations (materialize row_map first) ───────────────

    pub fn clear_range(&mut self, row1: i32, col1: i32, row2: i32, col2: i32) {
        self.invalidate_heap_size_cache();
        self.materialize_row_map();
        self.materialize_col_map();
        let r_lo = row1.min(row2);
        let r_hi = row1.max(row2);
        let c_lo = col1.min(col2);
        let c_hi = col1.max(col2);
        self.cells
            .retain(|&(r, c), _| !(r >= r_lo && r <= r_hi && c >= c_lo && c <= c_hi));
    }

    pub fn clear_all(&mut self) {
        self.invalidate_heap_size_cache();
        self.cells.clear();
        self.row_map.clear();
        self.col_map.clear();
    }

    pub fn insert_row(&mut self, at: i32) {
        self.invalidate_heap_size_cache();
        self.materialize_row_map();
        self.materialize_col_map();
        let mut shifted: Vec<((i32, i32), CellData)> = Vec::new();
        let keys_to_remove: Vec<(i32, i32)> = self
            .cells
            .keys()
            .filter(|&&(r, _)| r >= at)
            .cloned()
            .collect();
        for key in keys_to_remove {
            if let Some(data) = self.cells.remove(&key) {
                shifted.push(((key.0 + 1, key.1), data));
            }
        }
        for (key, data) in shifted {
            self.cells.insert(key, data);
        }
    }

    pub fn remove_row(&mut self, at: i32) {
        self.invalidate_heap_size_cache();
        self.materialize_row_map();
        self.materialize_col_map();
        let keys_at: Vec<(i32, i32)> = self
            .cells
            .keys()
            .filter(|&&(r, _)| r == at)
            .cloned()
            .collect();
        for key in keys_at {
            self.cells.remove(&key);
        }

        let mut shifted: Vec<((i32, i32), CellData)> = Vec::new();
        let keys_to_shift: Vec<(i32, i32)> = self
            .cells
            .keys()
            .filter(|&&(r, _)| r > at)
            .cloned()
            .collect();
        for key in keys_to_shift {
            if let Some(data) = self.cells.remove(&key) {
                shifted.push(((key.0 - 1, key.1), data));
            }
        }
        for (key, data) in shifted {
            self.cells.insert(key, data);
        }
    }

    /// Re-map stored column indices after a remove+insert move.
    ///
    /// `source_pos` and `insert_pos` are in the same index space used by
    /// `Vec::remove` + `Vec::insert`.
    pub fn remap_cols_after_move(&mut self, source_pos: i32, insert_pos: i32) {
        if source_pos == insert_pos {
            return;
        }
        self.invalidate_heap_size_cache();
        self.materialize_row_map();
        self.materialize_col_map();
        let old = std::mem::take(&mut self.cells);
        let mut remapped = HashMap::with_capacity(old.len());
        for ((row, col), data) in old {
            let mapped_col = remap_col_index_for_move(col, source_pos, insert_pos);
            remapped.insert((row, mapped_col), data);
        }
        self.cells = remapped;
    }

    // ── Iteration / queries ─────────────────────────────────────────────

    pub fn iter(&self) -> impl Iterator<Item = (&(i32, i32), &CellData)> {
        self.cells.iter()
    }

    pub fn contains(&self, row: i32, col: i32) -> bool {
        self.cells
            .contains_key(&(self.map_row(row), self.map_col(col)))
    }

    /// Drain all entries, yielding ownership without cloning.
    pub fn drain(&mut self) -> impl Iterator<Item = ((i32, i32), CellData)> + '_ {
        self.invalidate_heap_size_cache();
        self.cells.drain()
    }

    /// Number of stored cells.
    pub fn len(&self) -> usize {
        self.cells.len()
    }
}

fn remap_col_index_for_move(index: i32, source_pos: i32, insert_pos: i32) -> i32 {
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
