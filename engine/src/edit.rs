use crate::compose::{ActiveCompose, ComposeResult};
use crate::proto::volvoxgrid::v1 as pb;
use crate::style::HighlightStyle;
use std::time::Instant;

/// Edit state machine for in-place cell editing.
///
/// Tracks whether editing is active, which cell is being edited,
/// the original text (for cancel/undo), and the current edit text.
#[derive(Clone, Debug)]
struct ParsedDropdownItem {
    display: String,
    data: String,
}

#[derive(Clone, Debug, Default)]
pub struct EditHighlightRegion {
    pub row1: i32,
    pub col1: i32,
    pub row2: i32,
    pub col2: i32,
    pub style: HighlightStyle,
    pub ref_id: Option<i32>,
    pub text_start: Option<i32>,
    pub text_length: Option<i32>,
}

impl EditHighlightRegion {
    pub fn color(&self) -> u32 {
        self.style
            .border_color
            .or(self.style.back_color)
            .or(self.style.fore_color)
            .unwrap_or(0xFF1A73E8)
    }

    pub fn show_corner_handles(&self) -> bool {
        self.style.fill_handle == Some(pb::FillHandlePosition::FillHandleAllCorners as i32)
    }
}

fn byte_index_at_char(text: &str, char_index: i32) -> usize {
    let target = char_index.max(0) as usize;
    text.char_indices()
        .nth(target)
        .map(|(idx, _)| idx)
        .unwrap_or(text.len())
}

fn is_word_char(ch: char) -> bool {
    ch.is_alphanumeric() || ch == '_'
}

fn parse_dropdown_entries(list: &str) -> Vec<ParsedDropdownItem> {
    if list.is_empty() {
        return Vec::new();
    }

    // Leading pipe means editable dropdown.
    let src = if list.starts_with('|') {
        &list[1..]
    } else {
        list
    };
    let mut entries = Vec::new();

    for raw_item in src.split('|') {
        if raw_item.is_empty() {
            continue;
        }

        let mut item_body = raw_item;
        let mut data = String::new();
        let mut display_col: Option<usize> = None;

        // Optional metadata prefix before ';' (e.g. "#10*1;" or "*1#10;").
        if let Some(semi) = raw_item.find(';') {
            let meta = &raw_item[..semi];
            if meta.starts_with('#') || meta.starts_with('*') {
                let bytes = meta.as_bytes();
                let mut i = 0usize;
                while i < bytes.len() {
                    match bytes[i] as char {
                        '#' => {
                            i += 1;
                            let start = i;
                            if i < bytes.len()
                                && ((bytes[i] as char) == '-' || (bytes[i] as char) == '+')
                            {
                                i += 1;
                            }
                            let digit_start = i;
                            while i < bytes.len() && (bytes[i] as char).is_ascii_digit() {
                                i += 1;
                            }
                            if i > digit_start {
                                data = meta[start..i].to_string();
                            }
                        }
                        '*' => {
                            i += 1;
                            let start = i;
                            while i < bytes.len() && (bytes[i] as char).is_ascii_digit() {
                                i += 1;
                            }
                            if i > start {
                                if let Ok(v) = meta[start..i].parse::<usize>() {
                                    display_col = Some(v);
                                }
                            }
                        }
                        _ => break,
                    }
                }
                item_body = &raw_item[semi + 1..];
            }
        }

        let cols: Vec<&str> = item_body.split('\t').collect();
        let display = if cols.is_empty() {
            item_body.to_string()
        } else {
            let idx = display_col.unwrap_or(0);
            cols.get(idx)
                .or_else(|| cols.first())
                .copied()
                .unwrap_or("")
                .to_string()
        };

        entries.push(ParsedDropdownItem { display, data });
    }

    entries
}

/// Resolve display text for a stored translated dropdown value.
///
/// Returns `Some(display_text)` if the dropdown list contains a translated entry
/// with matching data id (e.g. `#23;Part Time` and stored value `"23"`).
pub fn translate_dropdown_value_to_display(list: &str, stored_value: &str) -> Option<String> {
    if stored_value.is_empty() {
        return None;
    }
    for entry in parse_dropdown_entries(list) {
        if !entry.data.is_empty() && entry.data == stored_value {
            return Some(entry.display);
        }
    }
    None
}

/// Resolve translated storage value for a display string.
///
/// Returns `Some(id)` when the dropdown list defines translated values (`#id;`)
/// and the input matches the entry's display text.
pub fn translate_dropdown_display_to_value(list: &str, display_value: &str) -> Option<String> {
    if display_value.is_empty() {
        return None;
    }
    for entry in parse_dropdown_entries(list) {
        if !entry.data.is_empty() && entry.display == display_value {
            return Some(entry.data);
        }
    }
    None
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub enum EditUiMode {
    #[default]
    EnterMode,
    EditMode,
}

#[derive(Clone, Debug)]
pub struct EditState {
    pub editing: bool,
    pub edit_row: i32,
    pub edit_col: i32,
    pub session_serial: u64,
    pub edit_text: String,
    pub original_text: String,
    pub formula_mode: bool,
    pub formula_highlights: Vec<EditHighlightRegion>,
    /// Whether the current edit session is Excel-style Enter mode or F2 edit mode.
    pub ui_mode: EditUiMode,
    /// Start position of selected text in editor (EditSelStart).
    pub sel_start: i32,
    /// Length of selected text in editor (EditSelLength).
    pub sel_length: i32,
    /// Active caret edge within the selection; equal to `sel_start` when collapsed.
    pub sel_caret: i32,
    /// Currently selected dropdown item index (DropdownIndex).
    pub dropdown_index: i32,
    /// Parsed dropdown list display values for the current editing cell.
    pub dropdown_items: Vec<String>,
    /// Parsed dropdown list data values (`#id;`) for each dropdown item.
    pub dropdown_data: Vec<String>,
    /// Whether the current list is an editable dropdown (`|item1|item2`).
    pub dropdown_editable: bool,
    /// Buffered type-ahead prefix for a select-only dropdown.
    pub dropdown_search_text: String,
    /// Time of the last type-ahead update for a select-only dropdown.
    pub dropdown_search_last_input: Option<Instant>,
    /// True during IME composition (preedit active).
    pub composing: bool,
    /// In-progress preedit text from IME (e.g. "ㅇ").
    pub preedit_text: String,
    /// Cursor position within the preedit text.
    pub preedit_cursor: i32,
    /// Selected engine-side compose method and its in-flight state.
    pub compose: ActiveCompose,
}

impl Default for EditState {
    fn default() -> Self {
        Self {
            editing: false,
            edit_row: -1,
            edit_col: -1,
            session_serial: 0,
            edit_text: String::new(),
            original_text: String::new(),
            formula_mode: false,
            formula_highlights: Vec::new(),
            ui_mode: EditUiMode::EnterMode,
            sel_start: 0,
            sel_length: 0,
            sel_caret: 0,
            dropdown_index: -1,
            dropdown_items: Vec::new(),
            dropdown_data: Vec::new(),
            dropdown_editable: false,
            dropdown_search_text: String::new(),
            dropdown_search_last_input: None,
            composing: false,
            preedit_text: String::new(),
            preedit_cursor: 0,
            compose: ActiveCompose::None,
        }
    }
}

impl EditState {
    fn text_chars(&self) -> Vec<char> {
        self.edit_text.chars().collect()
    }

    fn text_char_len(&self) -> i32 {
        self.edit_text.chars().count() as i32
    }

    fn selection_bounds(&self) -> (i32, i32) {
        let total = self.text_char_len();
        let start = self.sel_start.clamp(0, total);
        let end = (start + self.sel_length.max(0)).clamp(start, total);
        (start, end)
    }

    fn current_caret(&self) -> i32 {
        let (start, end) = self.selection_bounds();
        if end > start && (self.sel_caret == start || self.sel_caret == end) {
            self.sel_caret
        } else {
            end
        }
    }

    pub(crate) fn current_caret_char(&self) -> i32 {
        self.current_caret()
    }

    fn selection_anchor(&self) -> i32 {
        let (start, end) = self.selection_bounds();
        let caret = self.current_caret();
        if end > start {
            if caret == start { end } else { start }
        } else {
            start
        }
    }

    fn set_selection_from_anchor_and_caret(&mut self, anchor: i32, caret: i32) {
        let total = self.text_char_len();
        let anchor = anchor.clamp(0, total);
        let caret = caret.clamp(0, total);
        self.sel_start = anchor.min(caret);
        self.sel_length = (anchor - caret).abs();
        self.sel_caret = caret;
    }

    pub fn set_selection_anchor_and_caret(&mut self, anchor: i32, caret: i32) {
        self.set_selection_from_anchor_and_caret(anchor, caret);
    }

    fn prev_word_boundary(&self, caret: i32) -> i32 {
        let chars = self.text_chars();
        let mut idx = caret.clamp(0, chars.len() as i32) as usize;

        while idx > 0 && !is_word_char(chars[idx - 1]) {
            idx -= 1;
        }
        if idx == 0 {
            return 0;
        }

        while idx > 0 && is_word_char(chars[idx - 1]) {
            idx -= 1;
        }

        idx as i32
    }

    fn next_word_boundary(&self, caret: i32) -> i32 {
        let chars = self.text_chars();
        let len = chars.len();
        let mut idx = caret.clamp(0, len as i32) as usize;

        if idx >= len {
            return len as i32;
        }

        if is_word_char(chars[idx]) {
            while idx < len && is_word_char(chars[idx]) {
                idx += 1;
            }
        }

        while idx < len && !is_word_char(chars[idx]) {
            idx += 1;
        }

        idx as i32
    }

    fn sync_formula_mode_from_text(&mut self) {
        self.formula_mode = self.edit_text.trim_start().starts_with('=');
        if !self.formula_mode {
            self.formula_highlights.clear();
        }
    }

    pub fn new() -> Self {
        Self::default()
    }

    pub fn heap_size_bytes(&self) -> usize {
        let mut bytes = 0usize;
        bytes += self.edit_text.capacity();
        bytes += self.original_text.capacity();
        bytes += self.preedit_text.capacity();
        bytes += self.compose.heap_size_bytes();
        bytes += self.dropdown_search_text.capacity();
        bytes += self.formula_highlights.capacity() * std::mem::size_of::<EditHighlightRegion>();

        bytes += self.dropdown_items.capacity() * std::mem::size_of::<String>();
        for item in &self.dropdown_items {
            bytes += item.capacity();
        }

        bytes += self.dropdown_data.capacity() * std::mem::size_of::<String>();
        for item in &self.dropdown_data {
            bytes += item.capacity();
        }

        bytes
    }

    /// Returns true if an edit is currently in progress.
    pub fn is_active(&self) -> bool {
        self.editing
    }

    /// Begin editing the cell at (row, col) with the given current text.
    ///
    /// Sets `editing = true`, records the cell coordinates, and saves
    /// both the original text (for cancel) and the current edit text.
    pub fn start_edit(&mut self, row: i32, col: i32, current_text: &str) {
        self.cancel_preedit();
        self.compose.reset();
        self.editing = true;
        self.edit_row = row;
        self.edit_col = col;
        self.session_serial = self.session_serial.wrapping_add(1);
        self.original_text = current_text.to_string();
        self.ui_mode = EditUiMode::EnterMode;
        self.edit_text = current_text.to_string();
        self.formula_mode = self.edit_text.trim_start().starts_with('=');
        self.formula_highlights.clear();
        self.clear_dropdown_search();
        // Select all text when entering edit mode.
        self.sel_start = 0;
        self.sel_length = self.text_char_len();
        self.sel_caret = self.sel_length;
    }

    /// Begin editing with extended options for host-driven key dispatch.
    ///
    /// - `seed_text` set → use seed as edit text, caret at end
    /// - `caret_end` → keep current value, caret at end, no selection
    /// - default / `select_all` → keep current value, select all text
    pub fn start_edit_with_options(
        &mut self,
        row: i32,
        col: i32,
        current_text: &str,
        select_all: Option<bool>,
        caret_end: Option<bool>,
        seed_text: Option<&str>,
        formula_mode: Option<bool>,
    ) {
        self.cancel_preedit();
        self.compose.reset();
        self.editing = true;
        self.edit_row = row;
        self.edit_col = col;
        self.session_serial = self.session_serial.wrapping_add(1);
        self.original_text = current_text.to_string();
        self.ui_mode = if caret_end == Some(true) {
            EditUiMode::EditMode
        } else {
            EditUiMode::EnterMode
        };

        if let Some(seed) = seed_text {
            // seed_text: replace cell text with seed, caret at end
            self.edit_text = seed.to_string();
            self.sel_start = self.text_char_len();
            self.sel_length = 0;
            self.sel_caret = self.sel_start;
        } else if caret_end == Some(true) {
            // caret_end: keep value, caret at end, no selection
            self.edit_text = current_text.to_string();
            self.sel_start = self.text_char_len();
            self.sel_length = 0;
            self.sel_caret = self.sel_start;
        } else {
            // default / select_all: keep value, select all
            self.edit_text = current_text.to_string();
            self.sel_start = 0;
            self.sel_length = self.text_char_len();
            self.sel_caret = self.sel_length;
        }
        self.formula_mode =
            formula_mode.unwrap_or_else(|| self.edit_text.trim_start().starts_with('='));
        self.formula_highlights.clear();
        self.clear_dropdown_search();
        let _ = select_all; // used implicitly as the default path
    }

    /// Select all text in the editor.
    pub fn select_all(&mut self) {
        self.sel_start = 0;
        self.sel_length = self.text_char_len();
        self.sel_caret = self.sel_length;
    }

    /// If an IME preedit is active, commit it into `edit_text` so the
    /// pending composition is not lost when the edit session is committed
    /// or the text is read for validation.
    pub fn flush_preedit(&mut self) {
        if self.composing && !self.preedit_text.is_empty() {
            let preedit = self.preedit_text.clone();
            self.commit_preedit(&preedit);
            self.compose.reset();
        }
    }

    /// Commit the current edit, returning the cell coordinates and
    /// both old and new text: `(row, col, original_text, edit_text)`.
    ///
    /// Returns `None` if no edit is active. Resets the edit state.
    pub fn commit(&mut self) -> Option<(i32, i32, String, String)> {
        if !self.editing {
            return None;
        }
        // Flush any pending IME preedit into edit_text so the composed
        // text is included in the committed result.
        self.flush_preedit();
        self.editing = false;
        let result = (
            self.edit_row,
            self.edit_col,
            self.original_text.clone(),
            self.edit_text.clone(),
        );
        self.edit_row = -1;
        self.edit_col = -1;
        self.formula_mode = false;
        self.formula_highlights.clear();
        self.clear_dropdown_search();
        self.compose.reset();
        self.cancel_preedit();
        Some(result)
    }

    /// Cancel the current edit, returning the cell coordinates `(row, col)`.
    ///
    /// Returns `None` if no edit is active. Resets the edit state.
    pub fn cancel(&mut self) -> Option<(i32, i32)> {
        if !self.editing {
            return None;
        }
        self.editing = false;
        let result = (self.edit_row, self.edit_col);
        self.edit_row = -1;
        self.edit_col = -1;
        self.formula_mode = false;
        self.formula_highlights.clear();
        self.clear_dropdown_search();
        self.compose.reset();
        self.cancel_preedit();
        Some(result)
    }

    pub fn set_formula_mode(&mut self, enabled: bool) {
        self.formula_mode = enabled;
        if !enabled {
            self.formula_highlights.clear();
        }
    }

    pub fn set_highlights(&mut self, highlights: Vec<EditHighlightRegion>) {
        self.formula_highlights = highlights;
    }

    pub fn clear_highlights(&mut self) {
        self.formula_highlights.clear();
    }

    /// Update the in-progress edit text (e.g., as the user types).
    pub fn update_text(&mut self, text: String) {
        self.edit_text = text;
        self.sync_formula_mode_from_text();
    }

    pub fn configure_compose(&mut self, enabled: bool, method: i32) {
        let was_engine_composing = self.is_engine_composing();
        let next_method = if enabled {
            method
        } else {
            pb::ComposeMethod::None as i32
        };
        if self.compose.method() != next_method {
            self.compose = ActiveCompose::for_method(next_method);
        } else {
            self.compose.reset();
        }
        if was_engine_composing {
            self.cancel_preedit();
        }
    }

    pub fn engine_compose_enabled(&self) -> bool {
        !matches!(self.compose, ActiveCompose::None)
    }

    pub fn is_engine_composing(&self) -> bool {
        self.compose.is_active() && self.composing && !self.preedit_text.is_empty()
    }

    pub fn compose_should_handle(&self, ch: char) -> bool {
        self.compose.should_handle(ch)
    }

    pub fn compose_feed(&mut self, ch: char) -> ComposeResult {
        self.compose.feed(ch)
    }

    pub fn compose_backspace(&mut self) -> ComposeResult {
        self.compose.backspace()
    }

    pub fn reset_compose_state(&mut self) {
        self.compose.reset();
    }

    // ── Editor Selection (EditSelStart/Length/Text) ──────────────────

    /// Set the start position of selected text in the editor.
    pub fn set_sel_start(&mut self, pos: i32) {
        let max = self.text_char_len();
        self.sel_start = pos.max(0).min(max);
        // Clamp sel_length so it doesn't extend past end of text
        if self.sel_start + self.sel_length > max {
            self.sel_length = (max - self.sel_start).max(0);
        }
        self.sel_caret = if self.sel_length > 0 {
            self.sel_start + self.sel_length
        } else {
            self.sel_start
        };
    }

    /// Set the length of selected text in the editor.
    pub fn set_sel_length(&mut self, len: i32) {
        let max = self.text_char_len();
        self.sel_length = len.max(0).min(max - self.sel_start);
        self.sel_caret = if self.sel_length > 0 {
            self.sel_start + self.sel_length
        } else {
            self.sel_start
        };
    }

    /// Get the currently selected text in the editor.
    pub fn get_sel_text(&self) -> &str {
        let (start, end) = self.selection_bounds();
        let start_byte = byte_index_at_char(&self.edit_text, start);
        let end_byte = byte_index_at_char(&self.edit_text, end);
        &self.edit_text[start_byte..end_byte]
    }

    // ── Dropdown List Parsing (DropdownIndex/Count/Item) ──────────────────

    /// Parse a pipe-delimited dropdown list string into items.
    ///
    /// Handles the dropdown list format:
    /// - Items separated by `|` (pipe)
    /// - Leading `|` indicates editable dropdown (just strip it)
    /// - `#id;` optional translated data value
    /// - `*n;` optional display column for tab-delimited multi-column items
    pub fn parse_dropdown_items(&mut self, list: &str) {
        self.dropdown_items.clear();
        self.dropdown_data.clear();
        self.dropdown_editable = list.starts_with('|');
        self.clear_dropdown_search();
        if list.is_empty() {
            self.dropdown_index = -1;
            return;
        }

        for entry in parse_dropdown_entries(list) {
            self.dropdown_items.push(entry.display);
            self.dropdown_data.push(entry.data);
        }
        self.dropdown_index = -1;
    }

    /// Returns the number of items in the parsed dropdown list.
    pub fn dropdown_count(&self) -> i32 {
        self.dropdown_items.len() as i32
    }

    /// Get a dropdown item by index. Returns empty string if out of range.
    pub fn get_dropdown_item(&self, idx: i32) -> &str {
        if idx < 0 || (idx as usize) >= self.dropdown_items.len() {
            return "";
        }
        // Return the display part (before any \t for multi-column)
        let item = &self.dropdown_items[idx as usize];
        match item.find('\t') {
            Some(pos) => &item[..pos],
            None => item,
        }
    }

    /// Get dropdown item data (part after `\t`) by index.
    /// Returns empty string if no data portion or out of range.
    pub fn get_dropdown_data(&self, idx: i32) -> &str {
        if idx < 0 || (idx as usize) >= self.dropdown_data.len() {
            return "";
        }
        &self.dropdown_data[idx as usize]
    }

    /// Set the currently selected dropdown item index.
    pub fn set_dropdown_index(&mut self, idx: i32) {
        if idx < -1 || (idx as usize) >= self.dropdown_items.len() {
            self.dropdown_index = -1;
        } else {
            self.dropdown_index = idx;
            // Update edit text to match selected dropdown item
            if idx >= 0 {
                self.edit_text = self.get_dropdown_item(idx).to_string();
                self.sync_formula_mode_from_text();
            }
        }
    }

    // ── Text Manipulation (character-level editing) ────────────────────

    /// Insert a character at the current cursor position, replacing any selection.
    pub fn insert_char(&mut self, ch: char) {
        let chars: Vec<char> = self.edit_text.chars().collect();
        let total = chars.len() as i32;
        let sel_start = self.sel_start.clamp(0, total);
        let sel_end = (self.sel_start + self.sel_length.max(0)).clamp(sel_start, total);

        let mut result: Vec<char> = Vec::with_capacity(chars.len() + 1);
        result.extend_from_slice(&chars[..sel_start as usize]);
        result.push(ch);
        result.extend_from_slice(&chars[sel_end as usize..]);

        self.edit_text = result.into_iter().collect();
        self.sel_start = sel_start + 1;
        self.sel_length = 0;
        self.sel_caret = self.sel_start;
        self.sync_formula_mode_from_text();
    }

    /// Delete the character before the cursor (Backspace behavior).
    pub fn delete_back(&mut self) {
        let chars: Vec<char> = self.edit_text.chars().collect();
        let total = chars.len() as i32;
        let sel_start = self.sel_start.clamp(0, total);
        let sel_end = (self.sel_start + self.sel_length.max(0)).clamp(sel_start, total);

        if sel_end > sel_start {
            // Delete selection
            let mut result: Vec<char> = Vec::new();
            result.extend_from_slice(&chars[..sel_start as usize]);
            result.extend_from_slice(&chars[sel_end as usize..]);
            self.edit_text = result.into_iter().collect();
            self.sel_length = 0;
            self.sel_caret = self.sel_start;
            self.sync_formula_mode_from_text();
        } else if sel_start > 0 {
            // Delete char before cursor
            let mut result: Vec<char> = Vec::new();
            result.extend_from_slice(&chars[..(sel_start - 1) as usize]);
            result.extend_from_slice(&chars[sel_start as usize..]);
            self.edit_text = result.into_iter().collect();
            self.sel_start = sel_start - 1;
            self.sel_length = 0;
            self.sel_caret = self.sel_start;
            self.sync_formula_mode_from_text();
        }
    }

    /// Delete the character at the cursor (Delete key behavior).
    pub fn delete_forward(&mut self) {
        let chars: Vec<char> = self.edit_text.chars().collect();
        let total = chars.len() as i32;
        let sel_start = self.sel_start.clamp(0, total);
        let sel_end = (self.sel_start + self.sel_length.max(0)).clamp(sel_start, total);

        if sel_end > sel_start {
            // Delete selection
            let mut result: Vec<char> = Vec::new();
            result.extend_from_slice(&chars[..sel_start as usize]);
            result.extend_from_slice(&chars[sel_end as usize..]);
            self.edit_text = result.into_iter().collect();
            self.sel_length = 0;
            self.sel_caret = self.sel_start;
            self.sync_formula_mode_from_text();
        } else if (sel_start as usize) < chars.len() {
            // Delete char at cursor
            let mut result: Vec<char> = Vec::new();
            result.extend_from_slice(&chars[..sel_start as usize]);
            result.extend_from_slice(&chars[(sel_start + 1) as usize..]);
            self.edit_text = result.into_iter().collect();
            self.sel_length = 0;
            self.sel_caret = self.sel_start;
            self.sync_formula_mode_from_text();
        }
    }

    /// Move cursor left by one character.
    pub fn move_left(&mut self) {
        if self.sel_length > 0 {
            // Collapse selection to left edge
            self.sel_length = 0;
            self.sel_caret = self.sel_start;
        } else if self.sel_start > 0 {
            self.sel_start -= 1;
            self.sel_caret = self.sel_start;
        }
    }

    /// Move cursor right by one character.
    pub fn move_right(&mut self) {
        let total = self.text_char_len();
        if self.sel_length > 0 {
            // Collapse selection to right edge
            self.sel_start = (self.sel_start + self.sel_length).min(total);
            self.sel_length = 0;
            self.sel_caret = self.sel_start;
        } else if self.sel_start < total {
            self.sel_start += 1;
            self.sel_caret = self.sel_start;
        }
    }

    /// Move cursor to the beginning of the text.
    pub fn move_home(&mut self) {
        self.sel_start = 0;
        self.sel_length = 0;
        self.sel_caret = 0;
    }

    /// Move cursor to the end of the text.
    pub fn move_end(&mut self) {
        self.sel_start = self.text_char_len();
        self.sel_length = 0;
        self.sel_caret = self.sel_start;
    }

    /// Move cursor to the previous word boundary.
    pub fn move_word_left(&mut self) {
        let caret = self.prev_word_boundary(self.current_caret());
        self.sel_start = caret;
        self.sel_length = 0;
        self.sel_caret = caret;
    }

    /// Move cursor to the next word boundary.
    pub fn move_word_right(&mut self) {
        let caret = self.next_word_boundary(self.current_caret());
        self.sel_start = caret;
        self.sel_length = 0;
        self.sel_caret = caret;
    }

    /// Extend or shrink the selection one character to the left.
    pub fn select_left(&mut self) {
        let anchor = self.selection_anchor();
        let caret = (self.current_caret() - 1).max(0);
        self.set_selection_from_anchor_and_caret(anchor, caret);
    }

    /// Extend or shrink the selection one character to the right.
    pub fn select_right(&mut self) {
        let anchor = self.selection_anchor();
        let caret = (self.current_caret() + 1).min(self.text_char_len());
        self.set_selection_from_anchor_and_caret(anchor, caret);
    }

    /// Extend or shrink the selection to the beginning of the text.
    pub fn select_home(&mut self) {
        let anchor = self.selection_anchor();
        self.set_selection_from_anchor_and_caret(anchor, 0);
    }

    /// Extend or shrink the selection to the end of the text.
    pub fn select_end(&mut self) {
        let anchor = self.selection_anchor();
        self.set_selection_from_anchor_and_caret(anchor, self.text_char_len());
    }

    /// Extend or shrink the selection to the previous word boundary.
    pub fn select_word_left(&mut self) {
        let anchor = self.selection_anchor();
        let caret = self.prev_word_boundary(self.current_caret());
        self.set_selection_from_anchor_and_caret(anchor, caret);
    }

    /// Extend or shrink the selection to the next word boundary.
    pub fn select_word_right(&mut self) {
        let anchor = self.selection_anchor();
        let caret = self.next_word_boundary(self.current_caret());
        self.set_selection_from_anchor_and_caret(anchor, caret);
    }

    // ── IME Preedit (composition) ────────────────────────────────────

    /// Update preedit (composition) state from IME.
    ///
    /// Non-empty text activates composing mode. Empty text cancels it.
    /// When a text selection is active and composition starts, the selected
    /// text is deleted first (standard editor behavior — typing while text
    /// is selected replaces it).
    pub fn set_preedit(&mut self, text: &str, cursor: i32) {
        // If starting composition with a selection, delete the selected text
        // so the preedit replaces it. This mirrors what happens when typing
        // a normal character while text is selected.
        if !text.is_empty() && self.sel_length > 0 {
            let chars: Vec<char> = self.edit_text.chars().collect();
            let total = chars.len() as i32;
            let start = self.sel_start.clamp(0, total) as usize;
            let end = (self.sel_start + self.sel_length).clamp(0, total) as usize;
            let mut result: Vec<char> = Vec::with_capacity(chars.len());
            result.extend_from_slice(&chars[..start]);
            result.extend_from_slice(&chars[end..]);
            self.edit_text = result.into_iter().collect();
            self.sel_length = 0;
            self.sel_caret = self.sel_start;
        }
        self.preedit_text = text.to_string();
        self.preedit_cursor = cursor;
        self.composing = !text.is_empty();
    }

    /// Commit the preedit text: insert it into edit_text at the cursor,
    /// replacing any selection, then clear preedit state.
    pub fn commit_preedit(&mut self, committed: &str) {
        let chars: Vec<char> = self.edit_text.chars().collect();
        let total = chars.len() as i32;
        let sel_start = self.sel_start.clamp(0, total);
        let sel_end = (self.sel_start + self.sel_length.max(0)).clamp(sel_start, total);

        let committed_chars: Vec<char> = committed.chars().collect();
        let mut result: Vec<char> = Vec::with_capacity(chars.len() + committed_chars.len());
        result.extend_from_slice(&chars[..sel_start as usize]);
        result.extend_from_slice(&committed_chars);
        result.extend_from_slice(&chars[sel_end as usize..]);

        self.edit_text = result.into_iter().collect();
        self.sel_start = sel_start + committed_chars.len() as i32;
        self.sel_length = 0;
        self.sel_caret = self.sel_start;
        self.composing = false;
        self.preedit_text.clear();
        self.preedit_cursor = 0;
        self.sync_formula_mode_from_text();
    }

    /// Cancel preedit without modifying edit_text.
    pub fn cancel_preedit(&mut self) {
        self.composing = false;
        self.preedit_text.clear();
        self.preedit_cursor = 0;
    }

    /// Search dropdown items for a prefix match, returning the index or -1.
    pub fn search_dropdown(&self, prefix: &str) -> i32 {
        if prefix.is_empty() {
            return -1;
        }
        let lower = prefix.to_lowercase();
        for (i, item) in self.dropdown_items.iter().enumerate() {
            if item.to_lowercase().starts_with(&lower) {
                return i as i32;
            }
        }
        -1
    }

    pub fn clear_dropdown_search(&mut self) {
        self.dropdown_search_text.clear();
        self.dropdown_search_last_input = None;
    }

    pub fn select_readonly_dropdown_char(&mut self, ch: char, delay_ms: u128) -> bool {
        if self.dropdown_items.is_empty() || self.dropdown_editable {
            return false;
        }

        let now = Instant::now();
        if let Some(last) = self.dropdown_search_last_input {
            if now.duration_since(last).as_millis() > delay_ms {
                self.dropdown_search_text.clear();
            }
        } else {
            self.dropdown_search_text.clear();
        }
        self.dropdown_search_last_input = Some(now);

        self.dropdown_search_text.push(ch);
        let mut idx = self.search_dropdown(&self.dropdown_search_text);
        if idx < 0 {
            self.dropdown_search_text.clear();
            self.dropdown_search_text.push(ch);
            idx = self.search_dropdown(&self.dropdown_search_text);
        }

        if idx >= 0 {
            self.set_dropdown_index(idx);
            true
        } else {
            self.dropdown_search_text.clear();
            false
        }
    }
}

/// Apply an edit mask to an input string.
///
/// Mask characters:
/// - `#` or `9` = digit (0-9)
/// - `?` = letter (a-z, A-Z)
/// - `A` = alphanumeric (letter or digit)
/// - Any other character = literal (passed through as-is)
///
/// Returns `(formatted_text, is_valid)` where `is_valid` is true if all
/// required mask positions were filled.
pub fn apply_edit_mask(input: &str, mask: &str) -> (String, bool) {
    if mask.is_empty() {
        return (input.to_string(), true);
    }

    let mask_chars: Vec<char> = mask.chars().collect();
    let input_chars: Vec<char> = input.chars().collect();
    let mut result = Vec::with_capacity(mask_chars.len());
    let mut input_idx = 0usize;
    let mut valid = true;

    for &mc in &mask_chars {
        match mc {
            '#' | '9' => {
                // Expect a digit
                if input_idx < input_chars.len() && input_chars[input_idx].is_ascii_digit() {
                    result.push(input_chars[input_idx]);
                    input_idx += 1;
                } else if input_idx < input_chars.len() {
                    // Skip non-digit input chars until we find one
                    while input_idx < input_chars.len() && !input_chars[input_idx].is_ascii_digit()
                    {
                        input_idx += 1;
                    }
                    if input_idx < input_chars.len() {
                        result.push(input_chars[input_idx]);
                        input_idx += 1;
                    } else {
                        result.push('_');
                        valid = false;
                    }
                } else {
                    result.push('_');
                    valid = false;
                }
            }
            '?' => {
                // Expect a letter
                if input_idx < input_chars.len() && input_chars[input_idx].is_alphabetic() {
                    result.push(input_chars[input_idx]);
                    input_idx += 1;
                } else {
                    result.push('_');
                    if input_idx < input_chars.len() {
                        input_idx += 1;
                    }
                    valid = false;
                }
            }
            'A' => {
                // Expect alphanumeric
                if input_idx < input_chars.len() && input_chars[input_idx].is_alphanumeric() {
                    result.push(input_chars[input_idx]);
                    input_idx += 1;
                } else {
                    result.push('_');
                    if input_idx < input_chars.len() {
                        input_idx += 1;
                    }
                    valid = false;
                }
            }
            _ => {
                // Literal character — insert it directly
                result.push(mc);
                // If the input has this same literal, consume it
                if input_idx < input_chars.len() && input_chars[input_idx] == mc {
                    input_idx += 1;
                }
            }
        }
    }

    (result.into_iter().collect(), valid)
}

/// Check if a character is valid at the given mask position.
///
/// Returns true if the character satisfies the mask at `pos`, or if `pos`
/// is beyond the mask length.
pub fn is_char_valid_for_mask(ch: char, mask: &str, pos: usize) -> bool {
    let mask_chars: Vec<char> = mask.chars().collect();
    if pos >= mask_chars.len() {
        return false;
    }
    match mask_chars[pos] {
        '#' | '9' => ch.is_ascii_digit(),
        '?' => ch.is_alphabetic(),
        'A' => ch.is_alphanumeric(),
        literal => ch == literal,
    }
}

/// Returns the next non-literal position in the mask at or after `pos`.
pub fn next_input_position(mask: &str, pos: usize) -> usize {
    let mask_chars: Vec<char> = mask.chars().collect();
    let mut p = pos;
    while p < mask_chars.len() {
        match mask_chars[p] {
            '#' | '9' | '?' | 'A' => return p,
            _ => p += 1,
        }
    }
    p
}

#[cfg(test)]
mod tests {
    use crate::proto::volvoxgrid::v1 as pb;
    use crate::style::HighlightStyle;

    use super::{
        translate_dropdown_display_to_value, translate_dropdown_value_to_display,
        EditHighlightRegion, EditState,
    };

    #[test]
    fn parse_dropdown_items_with_data_and_display_column() {
        let mut edit = EditState::default();
        edit.parse_dropdown_items("|#10*1;Getz\tStan\t1 Sansome|#20;Mindelis\tNuno");

        assert_eq!(edit.dropdown_count(), 2);
        assert_eq!(edit.get_dropdown_item(0), "Stan");
        assert_eq!(edit.get_dropdown_data(0), "10");
        assert_eq!(edit.get_dropdown_item(1), "Mindelis");
        assert_eq!(edit.get_dropdown_data(1), "20");
    }

    #[test]
    fn insert_char_at_cursor() {
        let mut edit = EditState::default();
        edit.start_edit(1, 0, "hello");
        edit.sel_start = 5;
        edit.sel_length = 0;
        edit.insert_char('!');
        assert_eq!(edit.edit_text, "hello!");
        assert_eq!(edit.sel_start, 6);
    }

    #[test]
    fn insert_char_replaces_selection() {
        let mut edit = EditState::default();
        edit.start_edit(1, 0, "hello");
        edit.sel_start = 0;
        edit.sel_length = 5;
        edit.insert_char('X');
        assert_eq!(edit.edit_text, "X");
        assert_eq!(edit.sel_start, 1);
        assert_eq!(edit.sel_length, 0);
    }

    #[test]
    fn delete_back_removes_char_before_cursor() {
        let mut edit = EditState::default();
        edit.start_edit(1, 0, "abc");
        edit.sel_start = 2;
        edit.sel_length = 0;
        edit.delete_back();
        assert_eq!(edit.edit_text, "ac");
        assert_eq!(edit.sel_start, 1);
    }

    #[test]
    fn delete_back_removes_selection() {
        let mut edit = EditState::default();
        edit.start_edit(1, 0, "abcdef");
        edit.sel_start = 1;
        edit.sel_length = 3;
        edit.delete_back();
        assert_eq!(edit.edit_text, "aef");
        assert_eq!(edit.sel_start, 1);
        assert_eq!(edit.sel_length, 0);
    }

    #[test]
    fn delete_forward_removes_char_at_cursor() {
        let mut edit = EditState::default();
        edit.start_edit(1, 0, "abc");
        edit.sel_start = 1;
        edit.sel_length = 0;
        edit.delete_forward();
        assert_eq!(edit.edit_text, "ac");
    }

    #[test]
    fn move_left_right() {
        let mut edit = EditState::default();
        edit.start_edit(1, 0, "abc");
        edit.sel_start = 1;
        edit.sel_length = 0;
        edit.move_right();
        assert_eq!(edit.sel_start, 2);
        edit.move_left();
        assert_eq!(edit.sel_start, 1);
    }

    #[test]
    fn move_home_end() {
        let mut edit = EditState::default();
        edit.start_edit(1, 0, "abc");
        edit.sel_start = 1;
        edit.sel_length = 0;
        edit.move_end();
        assert_eq!(edit.sel_start, 3);
        edit.move_home();
        assert_eq!(edit.sel_start, 0);
    }

    #[test]
    fn shift_selection_tracks_caret_edge() {
        let mut edit = EditState::default();
        edit.start_edit(1, 0, "abcd");
        edit.move_end();

        edit.select_left();
        assert_eq!(edit.sel_start, 3);
        assert_eq!(edit.sel_length, 1);

        edit.select_left();
        assert_eq!(edit.sel_start, 2);
        assert_eq!(edit.sel_length, 2);

        edit.select_right();
        assert_eq!(edit.sel_start, 3);
        assert_eq!(edit.sel_length, 1);

        edit.select_right();
        assert_eq!(edit.sel_start, 4);
        assert_eq!(edit.sel_length, 0);
    }

    #[test]
    fn selected_text_uses_char_offsets() {
        let mut edit = EditState::default();
        edit.start_edit(1, 0, "가나다");
        edit.set_sel_start(1);
        edit.set_sel_length(1);

        assert_eq!(edit.get_sel_text(), "나");
    }

    #[test]
    fn move_word_left_right_uses_word_boundaries() {
        let mut edit = EditState::default();
        edit.start_edit(1, 0, "abc def! ghi");
        edit.move_end();

        edit.move_word_left();
        assert_eq!(edit.sel_start, 9);

        edit.move_word_left();
        assert_eq!(edit.sel_start, 4);

        edit.move_word_right();
        assert_eq!(edit.sel_start, 9);

        edit.move_word_right();
        assert_eq!(edit.sel_start, 12);
    }

    #[test]
    fn shift_word_selection_tracks_active_caret_edge() {
        let mut edit = EditState::default();
        edit.start_edit(1, 0, "abc def ghi");
        edit.move_end();

        edit.select_word_left();
        assert_eq!(edit.sel_start, 8);
        assert_eq!(edit.sel_length, 3);

        edit.select_word_left();
        assert_eq!(edit.sel_start, 4);
        assert_eq!(edit.sel_length, 7);

        edit.select_word_right();
        assert_eq!(edit.sel_start, 8);
        assert_eq!(edit.sel_length, 3);
    }

    #[test]
    fn search_dropdown_prefix_match() {
        let mut edit = EditState::default();
        edit.parse_dropdown_items("Apple|Banana|Cherry");
        let idx = edit.search_dropdown("ban");
        assert_eq!(idx, 1);
        let none = edit.search_dropdown("xyz");
        assert_eq!(none, -1);
    }

    #[test]
    fn edit_mask_phone_number() {
        let (formatted, valid) = super::apply_edit_mask("5551234567", "(###) ###-####");
        assert_eq!(formatted, "(555) 123-4567");
        assert!(valid);
    }

    #[test]
    fn edit_mask_incomplete() {
        let (formatted, valid) = super::apply_edit_mask("555", "(###) ###-####");
        assert_eq!(formatted, "(555) ___-____");
        assert!(!valid);
    }

    #[test]
    fn is_char_valid_for_mask_digits() {
        assert!(super::is_char_valid_for_mask('5', "###", 0));
        assert!(!super::is_char_valid_for_mask('a', "###", 0));
    }

    #[test]
    fn translate_dropdown_round_trip() {
        let list = "#1;Full time|#23;Part time|#65;Contractor";
        assert_eq!(
            translate_dropdown_display_to_value(list, "Part time").as_deref(),
            Some("23")
        );
        assert_eq!(
            translate_dropdown_value_to_display(list, "65").as_deref(),
            Some("Contractor")
        );
    }

    #[test]
    fn formula_mode_tracks_text_and_clears_highlights() {
        let mut edit = EditState::default();
        edit.start_edit_with_options(1, 1, "", None, None, Some("=SUM("), Some(true));
        assert!(edit.formula_mode);

        edit.set_highlights(vec![EditHighlightRegion {
            row1: 1,
            col1: 1,
            row2: 3,
            col2: 3,
            style: HighlightStyle {
                border_color: Some(0xFF00FF00),
                fill_handle: Some(pb::FillHandlePosition::FillHandleAllCorners as i32),
                ..HighlightStyle::default()
            },
            ref_id: Some(1),
            text_start: Some(1),
            text_length: Some(4),
        }]);
        assert_eq!(edit.formula_highlights.len(), 1);

        edit.update_text("123".to_string());
        assert!(!edit.formula_mode);
        assert!(edit.formula_highlights.is_empty());
    }

    #[test]
    fn commit_and_cancel_clear_formula_highlights() {
        let mut edit = EditState::default();
        edit.start_edit_with_options(1, 1, "=A1", None, None, None, Some(true));
        edit.set_highlights(vec![EditHighlightRegion::default()]);
        let _ = edit.commit();
        assert!(!edit.formula_mode);
        assert!(edit.formula_highlights.is_empty());

        edit.start_edit_with_options(1, 1, "=A1", None, None, None, Some(true));
        edit.set_highlights(vec![EditHighlightRegion::default()]);
        let _ = edit.cancel();
        assert!(!edit.formula_mode);
        assert!(edit.formula_highlights.is_empty());
    }

    #[test]
    fn commit_flushes_pending_preedit() {
        let mut edit = EditState::default();
        edit.start_edit(0, 0, "");
        edit.update_text(String::new());
        edit.sel_start = 0;
        edit.sel_length = 0;

        // Simulate Korean IME: syllable boundaries commit preedit,
        // last syllable stays as preedit.
        edit.commit_preedit("우");
        edit.commit_preedit("리");
        edit.commit_preedit("나");
        // Last syllable is still in preedit (not committed)
        edit.set_preedit("라", 1);

        assert_eq!(edit.edit_text, "우리나");
        assert_eq!(edit.preedit_text, "라");
        assert!(edit.composing);

        // Commit should flush the pending preedit first
        let result = edit.commit().unwrap();
        assert_eq!(result.3, "우리나라");
    }

    #[test]
    fn flush_preedit_inserts_at_cursor() {
        let mut edit = EditState::default();
        edit.start_edit(0, 0, "abc");
        edit.sel_start = 1;
        edit.sel_length = 0;
        edit.set_preedit("X", 1);

        edit.flush_preedit();
        assert_eq!(edit.edit_text, "aXbc");
        assert!(!edit.composing);
        assert!(edit.preedit_text.is_empty());
    }

    #[test]
    fn flush_preedit_noop_when_not_composing() {
        let mut edit = EditState::default();
        edit.start_edit(0, 0, "hello");
        let before = edit.edit_text.clone();
        edit.flush_preedit();
        assert_eq!(edit.edit_text, before);
    }

    // ── Preedit rendering (compose_preedit_display_text) ────────────

    #[test]
    fn compose_preedit_inserts_at_cursor() {
        use crate::canvas::compose_preedit_display_text;
        // Cursor at position 3 in "abcdef", preedit "XY"
        let result = compose_preedit_display_text("abcdef", 3, 3, "XY");
        assert_eq!(result, "abcXYdef");
    }

    #[test]
    fn compose_preedit_replaces_selection() {
        use crate::canvas::compose_preedit_display_text;
        // Selection from 1 to 4 in "abcdef", preedit "XY"
        let result = compose_preedit_display_text("abcdef", 1, 4, "XY");
        assert_eq!(result, "aXYef");
    }

    #[test]
    fn compose_preedit_at_start() {
        use crate::canvas::compose_preedit_display_text;
        let result = compose_preedit_display_text("hello", 0, 0, "ㅇ");
        assert_eq!(result, "ㅇhello");
    }

    #[test]
    fn compose_preedit_at_end() {
        use crate::canvas::compose_preedit_display_text;
        let result = compose_preedit_display_text("hello", 5, 5, "ㅇ");
        assert_eq!(result, "helloㅇ");
    }

    #[test]
    fn compose_preedit_with_cjk_text() {
        use crate::canvas::compose_preedit_display_text;
        // CJK text "안녕", cursor at char 1, preedit "하"
        let result = compose_preedit_display_text("안녕", 1, 1, "하");
        assert_eq!(result, "안하녕");
    }

    #[test]
    fn compose_preedit_empty_preedit() {
        use crate::canvas::compose_preedit_display_text;
        let result = compose_preedit_display_text("hello", 2, 2, "");
        assert_eq!(result, "hello");
    }

    #[test]
    fn compose_preedit_clamped_out_of_bounds() {
        use crate::canvas::compose_preedit_display_text;
        // sel_start and sel_end beyond text length — should clamp
        let result = compose_preedit_display_text("abc", 10, 20, "X");
        assert_eq!(result, "abcX");
    }

    // ── IME integration flow ────────────────────────────────────────

    #[test]
    fn ime_korean_syllable_composition_flow() {
        // Simulate Korean IME typing "우리" (two syllables):
        // 1. compositionstart
        // 2. set_preedit("ㅇ") → compositionupdate
        // 3. set_preedit("우") → compositionupdate
        // 4. commit_preedit("우") → compositionend
        // 5. set_preedit("ㄹ") → compositionstart (new syllable)
        // 6. set_preedit("리") → compositionupdate
        // 7. commit_preedit("리") → compositionend
        let mut edit = EditState::default();
        edit.start_edit(0, 0, "");
        edit.sel_start = 0;
        edit.sel_length = 0;

        // First syllable
        edit.set_preedit("ㅇ", 1);
        assert!(edit.composing);
        assert_eq!(edit.preedit_text, "ㅇ");
        assert_eq!(edit.edit_text, "");

        edit.set_preedit("우", 1);
        assert_eq!(edit.preedit_text, "우");

        edit.commit_preedit("우");
        assert!(!edit.composing);
        assert_eq!(edit.edit_text, "우");
        assert_eq!(edit.sel_start, 1);

        // Second syllable
        edit.set_preedit("ㄹ", 1);
        assert!(edit.composing);
        assert_eq!(edit.edit_text, "우");
        assert_eq!(edit.preedit_text, "ㄹ");

        edit.set_preedit("리", 1);
        edit.commit_preedit("리");
        assert_eq!(edit.edit_text, "우리");
        assert_eq!(edit.sel_start, 2);
    }

    #[test]
    fn ime_multi_segment_composition() {
        // Simulate Japanese IME: type "nihon" → preedit "にほん" → commit "日本"
        let mut edit = EditState::default();
        edit.start_edit(0, 0, "prefix");
        edit.sel_start = 6; // caret at end
        edit.sel_length = 0;

        edit.set_preedit("に", 1);
        assert!(edit.composing);
        assert_eq!(edit.edit_text, "prefix");

        edit.set_preedit("にほ", 2);
        edit.set_preedit("にほん", 3);

        // IME converts and commits
        edit.commit_preedit("日本");
        assert!(!edit.composing);
        assert_eq!(edit.edit_text, "prefix日本");
        assert_eq!(edit.sel_start, 8); // 6 + 2 chars
    }

    #[test]
    fn ime_cancel_mid_preedit() {
        // Start composition, then cancel (Escape)
        let mut edit = EditState::default();
        edit.start_edit(0, 0, "hello");
        edit.sel_start = 5;
        edit.sel_length = 0;

        edit.set_preedit("ㅎ", 1);
        assert!(edit.composing);
        assert_eq!(edit.edit_text, "hello");

        // User presses Escape → cancel preedit
        edit.cancel_preedit();
        assert!(!edit.composing);
        assert!(edit.preedit_text.is_empty());
        assert_eq!(edit.edit_text, "hello"); // unchanged
    }

    #[test]
    fn ime_preedit_with_active_selection_deletes_selection() {
        // When composition starts with text selected, the selection is deleted
        let mut edit = EditState::default();
        edit.start_edit(0, 0, "abcdef");
        edit.sel_start = 1;
        edit.sel_length = 3; // "bcd" selected

        edit.set_preedit("X", 1);
        assert!(edit.composing);
        // Selection should be deleted
        assert_eq!(edit.edit_text, "aef");
        assert_eq!(edit.sel_start, 1);
        assert_eq!(edit.sel_length, 0);
        // Preedit is "X"
        assert_eq!(edit.preedit_text, "X");

        // Commit → inserts at cursor
        edit.commit_preedit("XY");
        assert_eq!(edit.edit_text, "aXYef");
        assert_eq!(edit.sel_start, 3);
    }

    #[test]
    fn ime_preedit_on_empty_text() {
        let mut edit = EditState::default();
        edit.start_edit(0, 0, "");
        edit.sel_start = 0;
        edit.sel_length = 0;

        edit.set_preedit("あ", 1);
        assert!(edit.composing);
        assert_eq!(edit.edit_text, "");

        edit.commit_preedit("亜");
        assert_eq!(edit.edit_text, "亜");
        assert_eq!(edit.sel_start, 1);
    }

    #[test]
    fn ime_commit_flushes_preedit_on_edit_commit() {
        // Full flow: start edit → type with IME → commit edit
        let mut edit = EditState::default();
        edit.start_edit(0, 0, "");
        edit.sel_start = 0;
        edit.sel_length = 0;

        // Type Korean "나라" with last syllable still in preedit
        edit.commit_preedit("나");
        edit.set_preedit("라", 1);
        assert!(edit.composing);
        assert_eq!(edit.edit_text, "나");

        // Commit the edit session (e.g., Enter key)
        let result = edit.commit().unwrap();
        // flush_preedit should have inserted "라" before commit
        assert_eq!(result.3, "나라");
    }

    #[test]
    fn ime_successive_preedit_updates_dont_re_delete_selection() {
        // After the first set_preedit deletes the selection,
        // subsequent calls should NOT delete more text
        let mut edit = EditState::default();
        edit.start_edit(0, 0, "abcdef");
        edit.sel_start = 2;
        edit.sel_length = 2; // "cd" selected

        edit.set_preedit("X", 1);
        assert_eq!(edit.edit_text, "abef"); // "cd" deleted
        assert_eq!(edit.sel_length, 0);

        // Update preedit — should not delete anything more
        edit.set_preedit("XY", 2);
        assert_eq!(edit.edit_text, "abef"); // unchanged
        assert_eq!(edit.preedit_text, "XY");

        edit.set_preedit("XYZ", 3);
        assert_eq!(edit.edit_text, "abef"); // still unchanged

        edit.commit_preedit("XYZ");
        assert_eq!(edit.edit_text, "abXYZef");
    }
}
