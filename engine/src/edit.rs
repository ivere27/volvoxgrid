use crate::compose::{ActiveCompose, ComposeResult};
use crate::proto::volvoxgrid::v1 as pb;
use crate::style::HighlightStyle;
use std::time::Instant;

/// Per-adapter editor support matrix.
///
/// Each adapter (sfdatagrid, xtragrid, vsflexgrid, terminal TUI, web canvas,
/// flutter, .NET WinForms, etc.) advertises which `(EditorKind, EditorOwner)`
/// combinations it can actually render. The engine consults this matrix at
/// configuration time and rejects unsupported combinations before the host
/// has to handle a session it cannot draw.
///
/// `None` capability slots fall back to "permit anything that passes the
/// universal checks." Adapters that fully own their editor model can leave
/// `host_editor_capabilities = None`.
#[derive(Clone, Debug, Default)]
pub struct HostEditorCapabilities {
    /// Adapter identifier (for diagnostic messages). E.g. "sfdatagrid", "tui".
    pub adapter_id: String,
    /// Explicit allow-list of `(kind, owner)` pairs. Empty = no restriction.
    pub allowed: Vec<(pb::EditorKind, pb::EditorOwner)>,
    /// Owners that the adapter implements via a host-rendered surface.
    /// HOST_NATIVE on adapters not in this list is rejected.
    pub host_native_supported: bool,
    /// Whether the adapter can route CustomEditorAction through to a custom
    /// host editor (e.g. a popup widget). Affects `EDITOR_OWNER_CUSTOM`.
    pub custom_owner_supported: bool,
}

impl HostEditorCapabilities {
    /// Returns `Ok(())` when this adapter advertises support for the given
    /// `(kind, owner)` pair, or an error string describing why the
    /// configuration is rejected.
    pub fn accepts(&self, kind: pb::EditorKind, owner: pb::EditorOwner) -> Result<(), String> {
        if matches!(owner, pb::EditorOwner::HostNative) && !self.host_native_supported {
            return Err(format!(
                "adapter '{}' does not support EDITOR_OWNER_HOST_NATIVE",
                self.adapter_id
            ));
        }
        if matches!(owner, pb::EditorOwner::Custom) && !self.custom_owner_supported {
            return Err(format!(
                "adapter '{}' does not support EDITOR_OWNER_CUSTOM",
                self.adapter_id
            ));
        }
        if self.allowed.is_empty() {
            return Ok(());
        }
        let pair_listed = self
            .allowed
            .iter()
            .any(|(k, o)| (*k == kind || *k == pb::EditorKind::Unspecified) && *o == owner);
        if pair_listed {
            Ok(())
        } else {
            Err(format!(
                "adapter '{}' does not support (kind={:?}, owner={:?})",
                self.adapter_id, kind, owner
            ))
        }
    }
}

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

fn cell_value_to_edit_string(value: &pb::CellValue) -> String {
    match value.value.as_ref() {
        Some(pb::cell_value::Value::Text(v)) => v.clone(),
        Some(pb::cell_value::Value::Number(v)) => v.to_string(),
        Some(pb::cell_value::Value::Flag(v)) => v.to_string(),
        Some(pb::cell_value::Value::Raw(v)) => String::from_utf8_lossy(v).into_owned(),
        Some(pb::cell_value::Value::Timestamp(v)) => v.to_string(),
        None => String::new(),
    }
}

fn dropdown_item_label(item: &pb::ListItem) -> String {
    if !item.label.is_empty() {
        item.label.clone()
    } else if let Some(value) = item.value.as_ref() {
        cell_value_to_edit_string(value)
    } else if let Some(detail) = item.details.first() {
        detail.clone()
    } else {
        String::new()
    }
}

fn dropdown_item_value(item: &pb::ListItem) -> String {
    item.value
        .as_ref()
        .map(cell_value_to_edit_string)
        .unwrap_or_default()
}

fn dropdown_entries(dropdown: &pb::ListEditorParams) -> Vec<ParsedDropdownItem> {
    dropdown
        .static_items
        .iter()
        .filter(|item| !item.disabled)
        .map(|item| ParsedDropdownItem {
            display: dropdown_item_label(item),
            data: dropdown_item_value(item),
        })
        .filter(|entry| !entry.display.is_empty() || !entry.data.is_empty())
        .collect()
}

pub fn legacy_dropdown_items_to_dropdown(list: &str) -> pb::ListEditorParams {
    let mut dropdown = pb::ListEditorParams {
        static_items: Vec::new(),
        data_source: None,
        allow_custom_value: list.starts_with('|'),
        searchable: false,
        multi_select: false,
        item_layout: pb::DropdownItemLayout::DropdownItemAuto as i32,
    };

    for entry in parse_dropdown_entries(list) {
        dropdown.static_items.push(pb::ListItem {
            value: (!entry.data.is_empty()).then_some(pb::CellValue {
                value: Some(pb::cell_value::Value::Text(entry.data)),
            }),
            label: entry.display,
            details: Vec::new(),
            disabled: false,
        });
    }

    dropdown
}

pub fn dropdown_to_legacy_items(dropdown: &pb::ListEditorParams) -> String {
    let mut parts = Vec::new();
    if dropdown.allow_custom_value {
        parts.push(String::new());
    }
    for item in &dropdown.static_items {
        if item.disabled {
            continue;
        }
        let label = dropdown_item_label(item);
        let value = dropdown_item_value(item);
        if label.is_empty() && value.is_empty() {
            continue;
        }
        if !value.is_empty() {
            parts.push(format!("#{value};{label}"));
        } else {
            parts.push(label);
        }
    }
    parts.join("|")
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

pub fn translate_dropdown_value_to_display_typed(
    dropdown: &pb::ListEditorParams,
    stored_value: &str,
) -> Option<String> {
    if stored_value.is_empty() {
        return None;
    }
    for entry in dropdown_entries(dropdown) {
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

pub fn translate_dropdown_display_to_value_typed(
    dropdown: &pb::ListEditorParams,
    display_value: &str,
) -> Option<String> {
    if display_value.is_empty() {
        return None;
    }
    for entry in dropdown_entries(dropdown) {
        if !entry.data.is_empty() && entry.display == display_value {
            return Some(entry.data);
        }
    }
    None
}

pub fn dropdown_text_matches_item(list: &str, text: &str) -> bool {
    if text.is_empty() {
        return false;
    }
    parse_dropdown_entries(list)
        .into_iter()
        .any(|entry| entry.display == text || (!entry.data.is_empty() && entry.data == text))
}

pub fn dropdown_text_matches_item_typed(dropdown: &pb::ListEditorParams, text: &str) -> bool {
    if text.is_empty() {
        return false;
    }
    dropdown_entries(dropdown)
        .into_iter()
        .any(|entry| entry.display == text || (!entry.data.is_empty() && entry.data == text))
}

pub fn validation_mode_for_editor(editor: &pb::EditorSpec) -> pb::ValidationMode {
    pb::ValidationMode::try_from(editor.validation_mode)
        .unwrap_or(pb::ValidationMode::ValidationBlock)
}

pub fn validation_error(
    code: impl Into<String>,
    message: impl Into<String>,
    blocking: bool,
) -> pb::ValidationError {
    pb::ValidationError {
        code: code.into(),
        message: message.into(),
        blocking,
    }
}

pub fn validate_editor_commit_text(
    editor: &pb::EditorSpec,
    text: &str,
) -> Vec<pb::ValidationError> {
    let kind = pb::EditorKind::try_from(editor.kind).unwrap_or(pb::EditorKind::Unspecified);
    match kind {
        pb::EditorKind::EditorText | pb::EditorKind::EditorMultilineText => {
            validate_text_editor_commit(editor.text.as_ref(), text)
        }
        pb::EditorKind::EditorNumber => validate_number_editor_commit(editor.number.as_ref(), text),
        pb::EditorKind::EditorSelect => validate_select_editor_commit(editor.list.as_ref(), text),
        pb::EditorKind::EditorDateTime => {
            validate_date_time_editor_commit(editor.date_time.as_ref(), text)
        }
        _ => Vec::new(),
    }
}

#[derive(Clone, Debug)]
pub enum PreparedEditCommit {
    Commit(String),
    Block {
        attempted: String,
        errors: Vec<pb::ValidationError>,
    },
    Revert(String),
    AllowInvalid {
        committed: String,
        errors: Vec<pb::ValidationError>,
    },
}

pub fn prepare_committed_edit_text(
    editor: &pb::EditorSpec,
    old_text: &str,
    new_text: &str,
    grid_max_length: i32,
) -> PreparedEditCommit {
    let mut committed = truncate_to_char_count(
        new_text,
        effective_commit_max_length(editor, grid_max_length),
    );

    if let Some(list) = editor.list.as_ref() {
        if let Some(mapped) = translate_dropdown_display_to_value_typed(list, &committed) {
            committed = mapped;
        }
    }

    let mut errors = validate_editor_commit_text(editor, &committed);
    dedupe_validation_errors(&mut errors);

    if errors.is_empty() {
        return PreparedEditCommit::Commit(committed);
    }

    match validation_mode_for_editor(editor) {
        pb::ValidationMode::ValidationRevert => PreparedEditCommit::Revert(old_text.to_string()),
        pb::ValidationMode::ValidationAllowInvalid => {
            PreparedEditCommit::AllowInvalid { committed, errors }
        }
        _ => PreparedEditCommit::Block {
            attempted: committed,
            errors,
        },
    }
}

pub fn truncate_to_char_count(input: &str, max_chars: i32) -> String {
    if max_chars <= 0 {
        return input.to_string();
    }
    input.chars().take(max_chars as usize).collect()
}

pub fn effective_commit_max_length(editor: &pb::EditorSpec, grid_max_length: i32) -> i32 {
    let editor_max = editor
        .text
        .as_ref()
        .map(|text| text.max_length)
        .unwrap_or(0);
    match (grid_max_length, editor_max) {
        (grid_max, editor_max) if grid_max > 0 && editor_max > 0 => grid_max.min(editor_max),
        (_, editor_max) if editor_max > 0 => editor_max,
        (grid_max, _) => grid_max,
    }
}

fn dedupe_validation_errors(errors: &mut Vec<pb::ValidationError>) {
    let mut deduped = Vec::with_capacity(errors.len());
    for error in errors.drain(..) {
        if !deduped
            .iter()
            .any(|existing: &pb::ValidationError| existing.code == error.code)
        {
            deduped.push(error);
        }
    }
    *errors = deduped;
}

fn validate_text_editor_commit(
    text_params: Option<&pb::TextEditorParams>,
    text: &str,
) -> Vec<pb::ValidationError> {
    let Some(params) = text_params else {
        return Vec::new();
    };
    let mut errors = Vec::new();
    if params.max_length > 0 && text.chars().count() > params.max_length as usize {
        errors.push(validation_error(
            "text.max_length",
            format!("Value must be at most {} characters.", params.max_length),
            true,
        ));
    }
    if !params.allow_newlines && text.chars().any(|ch| ch == '\n' || ch == '\r') {
        errors.push(validation_error(
            "text.newline",
            "Value cannot contain line breaks.",
            true,
        ));
    }
    errors
}

fn validate_number_editor_commit(
    number_params: Option<&pb::NumberEditorParams>,
    text: &str,
) -> Vec<pb::ValidationError> {
    let trimmed = text.trim();
    let params = number_params.cloned().unwrap_or_default();
    if trimmed.is_empty() {
        return if params.nullable {
            Vec::new()
        } else {
            vec![validation_error(
                "number.required",
                "Value is required.",
                true,
            )]
        };
    }

    let Some(value) = parse_editor_number(trimmed) else {
        return vec![validation_error(
            "number.invalid",
            "Value must be a number.",
            true,
        )];
    };
    if let Some(min) = params.min {
        if value < min {
            return vec![validation_error(
                "number.min",
                format!("Value must be greater than or equal to {}.", min),
                true,
            )];
        }
    }
    if let Some(max) = params.max {
        if value > max {
            return vec![validation_error(
                "number.max",
                format!("Value must be less than or equal to {}.", max),
                true,
            )];
        }
    }
    Vec::new()
}

fn validate_select_editor_commit(
    list_params: Option<&pb::ListEditorParams>,
    text: &str,
) -> Vec<pb::ValidationError> {
    let Some(list) = list_params else {
        return Vec::new();
    };
    if list.static_items.is_empty() {
        return Vec::new();
    }
    if dropdown_text_matches_item_typed(list, text) {
        return Vec::new();
    }
    vec![validation_error(
        "select.invalid",
        "Value must be selected from the list.",
        true,
    )]
}

fn validate_date_time_editor_commit(
    date_time_params: Option<&pb::DateTimeEditorParams>,
    text: &str,
) -> Vec<pb::ValidationError> {
    let trimmed = text.trim();
    if trimmed.is_empty() {
        return Vec::new();
    }
    let params = date_time_params.cloned().unwrap_or_default();
    let Some(value) = parse_editor_timestamp(trimmed, params.date_only, params.time_only) else {
        return vec![validation_error(
            "date.invalid",
            "Value must be a valid date or time.",
            true,
        )];
    };
    if let Some(min) = params.min_timestamp {
        if value < min {
            return vec![validation_error(
                "date.min",
                "Value is earlier than the minimum date.",
                true,
            )];
        }
    }
    if let Some(max) = params.max_timestamp {
        if value > max {
            return vec![validation_error(
                "date.max",
                "Value is later than the maximum date.",
                true,
            )];
        }
    }
    Vec::new()
}

fn parse_editor_number(raw: &str) -> Option<f64> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return None;
    }
    let mut negative = false;
    let mut inner = trimmed;
    if trimmed.starts_with('(') && trimmed.ends_with(')') && trimmed.len() > 2 {
        negative = true;
        inner = &trimmed[1..trimmed.len() - 1];
    }

    // Percent signs are accepted as formatting noise only: "85%" parses to
    // 85.0, not 0.85. Display formats own percent scaling.
    let needs_clean = inner.chars().any(|ch| matches!(ch, ',' | '$' | ' ' | '%'));
    let parsed = if needs_clean {
        let mut cleaned = String::with_capacity(inner.len());
        for ch in inner.chars() {
            if !matches!(ch, ',' | '$' | ' ' | '%') {
                cleaned.push(ch);
            }
        }
        cleaned.parse::<f64>().ok()?
    } else {
        inner.parse::<f64>().ok()?
    };

    if !parsed.is_finite() {
        return None;
    }
    Some(if negative { -parsed } else { parsed })
}

fn parse_editor_timestamp(raw: &str, date_only: bool, time_only: bool) -> Option<i64> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return None;
    }
    // Existing stored timestamp cells may edit as their raw epoch-millisecond
    // integer, so integer text is accepted before loose date parsing. Ambiguous
    // forms such as "20260513" are therefore treated as epoch milliseconds.
    if let Ok(ms) = trimmed.parse::<i64>() {
        return Some(ms);
    }

    let parts = trimmed
        .split(|ch: char| !ch.is_ascii_digit())
        .filter(|part| !part.is_empty())
        .collect::<Vec<_>>();

    if time_only {
        if parts.len() < 2 || parts.len() > 3 {
            return None;
        }
        let hour = parts[0].parse::<i32>().ok()?;
        let minute = parts[1].parse::<i32>().ok()?;
        let second = parts
            .get(2)
            .and_then(|value| value.parse::<i32>().ok())
            .unwrap_or(0);
        if !(0..=23).contains(&hour) || !(0..=59).contains(&minute) || !(0..=59).contains(&second) {
            return None;
        }
        return Some((hour as i64 * 3_600 + minute as i64 * 60 + second as i64) * 1_000);
    }

    if parts.len() < 3 || (date_only && parts.len() > 3) {
        return None;
    }
    let p0 = parts[0].parse::<i32>().ok()?;
    let p1 = parts[1].parse::<i32>().ok()?;
    let p2 = parts[2].parse::<i32>().ok()?;
    let (year, month, day) = if parts[0].len() == 4 {
        (p0, p1, p2)
    } else if parts[2].len() == 4 {
        (p2, p0, p1)
    } else {
        return None;
    };
    if !valid_ymd(year, month, day) {
        return None;
    }
    let hour = parts
        .get(3)
        .and_then(|value| value.parse::<i32>().ok())
        .unwrap_or(0);
    let minute = parts
        .get(4)
        .and_then(|value| value.parse::<i32>().ok())
        .unwrap_or(0);
    let second = parts
        .get(5)
        .and_then(|value| value.parse::<i32>().ok())
        .unwrap_or(0);
    if !(0..=23).contains(&hour) || !(0..=59).contains(&minute) || !(0..=59).contains(&second) {
        return None;
    }
    let days = days_from_civil(year, month, day);
    let secs = hour as i64 * 3_600 + minute as i64 * 60 + second as i64;
    Some(days * 86_400_000 + secs * 1_000)
}

fn valid_ymd(year: i32, month: i32, day: i32) -> bool {
    if !(1..=12).contains(&month) {
        return false;
    }
    let max_day = match month {
        1 | 3 | 5 | 7 | 8 | 10 | 12 => 31,
        4 | 6 | 9 | 11 => 30,
        2 if is_leap_year(year) => 29,
        2 => 28,
        _ => return false,
    };
    (1..=max_day).contains(&day)
}

fn is_leap_year(year: i32) -> bool {
    (year % 4 == 0 && year % 100 != 0) || year % 400 == 0
}

fn days_from_civil(y: i32, m: i32, d: i32) -> i64 {
    let y = y as i64 - if m <= 2 { 1 } else { 0 };
    let era = if y >= 0 { y } else { y - 399 } / 400;
    let yoe = y - era * 400;
    let mp = m as i64 + if m > 2 { -3 } else { 9 };
    let doy = (153 * mp + 2) / 5 + d as i64 - 1;
    let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    era * 146_097 + doe - 719_468
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub enum EditUiMode {
    #[default]
    EnterMode,
    EditMode,
}

/// Derive `EditUiMode` from the gesture that initiated the edit session.
///
/// `F2`, `DOUBLE_CLICK`, and `CLICK_CARET` produce `EditMode` (caret-positioned,
/// no select-all). Every other reason — including the default `Unspecified` —
/// produces `EnterMode` (select-all, first printable key replaces content).
pub fn ui_mode_from_reason(reason: pb::EditStartReason) -> EditUiMode {
    match reason {
        pb::EditStartReason::EditStartF2
        | pb::EditStartReason::EditStartDoubleClick
        | pb::EditStartReason::EditStartClickCaret => EditUiMode::EditMode,
        _ => EditUiMode::EnterMode,
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub(crate) struct EditorVisualLine<'a> {
    pub text: &'a str,
    pub start_char: i32,
    pub end_char: i32,
}

pub(crate) fn editor_visual_lines(text: &str) -> Vec<EditorVisualLine<'_>> {
    let mut lines = Vec::new();
    let mut line_start_byte = 0;
    let mut line_start_char = 0;
    let mut char_index = 0;

    for (byte_index, ch) in text.char_indices() {
        if ch == '\n' {
            lines.push(EditorVisualLine {
                text: &text[line_start_byte..byte_index],
                start_char: line_start_char,
                end_char: char_index,
            });
            char_index += 1;
            line_start_byte = byte_index + ch.len_utf8();
            line_start_char = char_index;
        } else {
            char_index += 1;
        }
    }

    lines.push(EditorVisualLine {
        text: &text[line_start_byte..],
        start_char: line_start_char,
        end_char: char_index,
    });
    lines
}

pub(crate) fn editor_line_index_for_char(lines: &[EditorVisualLine<'_>], char_index: i32) -> usize {
    let char_index = char_index.max(0);
    lines
        .iter()
        .position(|line| char_index <= line.end_char)
        .unwrap_or_else(|| lines.len().saturating_sub(1))
}

#[derive(Clone, Debug)]
struct EndedEditSession {
    session_id: u64,
    reason: i32,
    committed_text: Option<String>,
    state_version: u64,
}

/// Maximum number of ended edit sessions retained for late `EditorSessionEnded`
/// emission. The render-session refresh path emits `EditorSessionEnded` after
/// the engine has already cleared `EditState`, so we need to look up the reason
/// and committed_value of the prior session by its `session_id`. The cap bounds
/// memory in pathological cases (e.g. host programmatically opening and
/// canceling editors in a tight loop); once exceeded, the oldest entry is
/// dropped and `build_editor_ended` falls back to `EditEndUnspecified`.
const ENDED_EDIT_SESSION_HISTORY_CAP: usize = 8;

#[derive(Clone, Debug)]
pub struct EditState {
    pub editing: bool,
    pub edit_row: i32,
    pub edit_col: i32,
    pub session_serial: u64,
    pub state_version: u64,
    pub last_ended_session_id: u64,
    pub last_end_reason: i32,
    pub last_end_text: Option<String>,
    pub last_end_state_version: u64,
    ended_sessions: Vec<EndedEditSession>,
    pub validation_errors: Vec<pb::ValidationError>,
    pub last_validation_request_id: i64,
    pub last_list_items_request_id: i64,
    pub edit_text: String,
    pub original_text: String,
    pub formula_mode: bool,
    pub formula_highlights: Vec<EditHighlightRegion>,
    /// Whether the current edit session is Excel-style Enter mode or F2 edit mode.
    pub ui_mode: EditUiMode,
    /// Gesture or trigger that opened the current session.
    pub start_reason: pb::EditStartReason,
    /// Start position of selected text in editor (EditSelStart).
    pub sel_start: i32,
    /// Length of selected text in editor (EditSelLength).
    pub sel_length: i32,
    /// Active caret edge within the selection; equal to `sel_start` when collapsed.
    pub sel_caret: i32,
    /// Desired visual-line column while moving repeatedly with Up/Down.
    vertical_caret_goal: Option<i32>,
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
            state_version: 0,
            last_ended_session_id: 0,
            last_end_reason: pb::EditEndReason::EditEndUnspecified as i32,
            last_end_text: None,
            last_end_state_version: 0,
            ended_sessions: Vec::new(),
            validation_errors: Vec::new(),
            last_validation_request_id: 0,
            last_list_items_request_id: 0,
            edit_text: String::new(),
            original_text: String::new(),
            formula_mode: false,
            formula_highlights: Vec::new(),
            ui_mode: EditUiMode::EnterMode,
            start_reason: pb::EditStartReason::EditStartUnspecified,
            sel_start: 0,
            sel_length: 0,
            sel_caret: 0,
            vertical_caret_goal: None,
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
            if caret == start {
                end
            } else {
                start
            }
        } else {
            start
        }
    }

    fn set_selection_from_anchor_and_caret_internal(&mut self, anchor: i32, caret: i32) {
        let total = self.text_char_len();
        let anchor = anchor.clamp(0, total);
        let caret = caret.clamp(0, total);
        self.sel_start = anchor.min(caret);
        self.sel_length = (anchor - caret).abs();
        self.sel_caret = caret;
    }

    fn set_selection_from_anchor_and_caret(&mut self, anchor: i32, caret: i32) {
        self.set_selection_from_anchor_and_caret_internal(anchor, caret);
        self.vertical_caret_goal = None;
        self.bump_state_version();
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

    pub fn bump_state_version(&mut self) {
        if self.editing {
            self.state_version = self.state_version.wrapping_add(1).max(1);
        }
    }

    fn reset_session_version(&mut self) {
        self.state_version = 1;
    }

    fn record_session_end(&mut self, reason: pb::EditEndReason, committed_text: Option<String>) {
        self.last_ended_session_id = self.session_serial;
        self.last_end_reason = reason as i32;
        self.last_end_state_version = self.state_version.max(1);
        self.last_end_text = committed_text;
        self.ended_sessions.push(EndedEditSession {
            session_id: self.last_ended_session_id,
            reason: self.last_end_reason,
            committed_text: self.last_end_text.clone(),
            state_version: self.last_end_state_version,
        });
        if self.ended_sessions.len() > ENDED_EDIT_SESSION_HISTORY_CAP {
            self.ended_sessions.remove(0);
        }
    }

    pub fn ended_session_details(&self, session_id: u64) -> Option<(i32, Option<&str>, u64)> {
        self.ended_sessions
            .iter()
            .rev()
            .find(|ended| ended.session_id == session_id)
            .map(|ended| {
                (
                    ended.reason,
                    ended.committed_text.as_deref(),
                    ended.state_version,
                )
            })
    }

    pub fn heap_size_bytes(&self) -> usize {
        let mut bytes = 0usize;
        bytes += self.edit_text.capacity();
        bytes += self.original_text.capacity();
        bytes += self.preedit_text.capacity();
        bytes += self.compose.heap_size_bytes();
        bytes += self.dropdown_search_text.capacity();
        bytes += self.formula_highlights.capacity() * std::mem::size_of::<EditHighlightRegion>();
        bytes += self.validation_errors.capacity() * std::mem::size_of::<pb::ValidationError>();
        bytes += self.ended_sessions.capacity() * std::mem::size_of::<EndedEditSession>();
        for ended in &self.ended_sessions {
            if let Some(text) = &ended.committed_text {
                bytes += text.capacity();
            }
        }
        for error in &self.validation_errors {
            bytes += error.code.capacity() + error.message.capacity();
        }

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

    /// Begin editing the cell at (row, col). UI mode and initial selection are
    /// derived from `reason` via [`ui_mode_from_reason`]: EDIT places the caret
    /// at the end of `current_text` with no selection; ENTER selects all so the
    /// first printable key replaces the cell content.
    pub fn start_edit(
        &mut self,
        row: i32,
        col: i32,
        reason: pb::EditStartReason,
        current_text: &str,
    ) {
        self.start_edit_with(row, col, reason, current_text, None, None, None);
    }

    /// Begin editing with explicit overrides:
    /// - `seed_text` — replace cell content with this seed (e.g. first typed char)
    /// - `caret_position` — explicit caret offset (only used when `reason` is
    ///   `EditStartClickCaret`; otherwise the position is derived from ui_mode)
    /// - `formula_mode` — force formula mode on/off (default: infer from text)
    pub fn start_edit_with(
        &mut self,
        row: i32,
        col: i32,
        reason: pb::EditStartReason,
        current_text: &str,
        seed_text: Option<&str>,
        caret_position: Option<i32>,
        formula_mode: Option<bool>,
    ) {
        self.cancel_preedit();
        self.compose.reset();
        self.editing = true;
        self.edit_row = row;
        self.edit_col = col;
        self.session_serial = self.session_serial.wrapping_add(1);
        self.reset_session_version();
        self.original_text = current_text.to_string();
        self.start_reason = reason;
        self.ui_mode = ui_mode_from_reason(reason);

        if let Some(seed) = seed_text {
            self.edit_text = seed.to_string();
            self.sel_start = self.text_char_len();
            self.sel_length = 0;
            self.sel_caret = self.sel_start;
        } else {
            self.edit_text = current_text.to_string();
            match self.ui_mode {
                EditUiMode::EditMode => {
                    let len = self.text_char_len();
                    let pos = match (reason, caret_position) {
                        (pb::EditStartReason::EditStartClickCaret, Some(p)) => p.clamp(0, len),
                        _ => len,
                    };
                    self.sel_start = pos;
                    self.sel_length = 0;
                    self.sel_caret = pos;
                }
                EditUiMode::EnterMode => {
                    self.sel_start = 0;
                    self.sel_length = self.text_char_len();
                    self.sel_caret = self.sel_length;
                }
            }
        }
        self.vertical_caret_goal = None;
        self.formula_mode =
            formula_mode.unwrap_or_else(|| self.edit_text.trim_start().starts_with('='));
        self.formula_highlights.clear();
        self.validation_errors.clear();
        self.last_validation_request_id = 0;
        self.last_list_items_request_id = 0;
        self.clear_dropdown_search();
    }

    /// Select all text in the editor.
    pub fn select_all(&mut self) {
        self.sel_start = 0;
        self.sel_length = self.text_char_len();
        self.sel_caret = self.sel_length;
        self.vertical_caret_goal = None;
        self.bump_state_version();
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
        self.validation_errors.clear();
        self.last_validation_request_id = 0;
        self.last_list_items_request_id = 0;
        self.clear_dropdown_search();
        self.compose.reset();
        self.cancel_preedit();
        self.vertical_caret_goal = None;
        self.record_session_end(pb::EditEndReason::EditEndCommitted, Some(result.3.clone()));
        Some(result)
    }

    /// Finish a commit after the caller has already validated and normalized
    /// the text. Returns `(row, col, original_text)` and records the supplied
    /// committed text in the session-ended snapshot.
    pub fn finish_commit_with_text(
        &mut self,
        committed_text: String,
    ) -> Option<(i32, i32, String)> {
        if !self.editing {
            return None;
        }
        self.editing = false;
        let result = (self.edit_row, self.edit_col, self.original_text.clone());
        self.edit_row = -1;
        self.edit_col = -1;
        self.formula_mode = false;
        self.formula_highlights.clear();
        self.validation_errors.clear();
        self.last_validation_request_id = 0;
        self.last_list_items_request_id = 0;
        self.clear_dropdown_search();
        self.compose.reset();
        self.cancel_preedit();
        self.vertical_caret_goal = None;
        self.record_session_end(pb::EditEndReason::EditEndCommitted, Some(committed_text));
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
        self.validation_errors.clear();
        self.last_validation_request_id = 0;
        self.last_list_items_request_id = 0;
        self.clear_dropdown_search();
        self.compose.reset();
        self.cancel_preedit();
        self.vertical_caret_goal = None;
        self.record_session_end(pb::EditEndReason::EditEndCanceled, None);
        Some(result)
    }

    pub fn set_formula_mode(&mut self, enabled: bool) {
        self.formula_mode = enabled;
        if !enabled {
            self.formula_highlights.clear();
        }
        self.bump_state_version();
    }

    pub fn set_highlights(&mut self, highlights: Vec<EditHighlightRegion>) {
        self.formula_highlights = highlights;
        self.bump_state_version();
    }

    pub fn clear_highlights(&mut self) {
        self.formula_highlights.clear();
        self.bump_state_version();
    }

    /// Update the in-progress edit text (e.g., as the user types).
    pub fn update_text(&mut self, text: String) {
        self.edit_text = text;
        self.validation_errors.clear();
        self.vertical_caret_goal = None;
        self.sync_formula_mode_from_text();
        self.bump_state_version();
    }

    pub fn set_validation_errors(&mut self, errors: Vec<pb::ValidationError>) {
        self.validation_errors = errors;
        self.bump_state_version();
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
        self.bump_state_version();
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
        self.bump_state_version();
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
        self.bump_state_version();
    }

    /// Parse a typed dropdown into the active edit list.
    pub fn parse_dropdown(&mut self, dropdown: &pb::ListEditorParams) {
        self.dropdown_items.clear();
        self.dropdown_data.clear();
        self.dropdown_editable = dropdown.allow_custom_value;
        self.clear_dropdown_search();

        for entry in dropdown_entries(dropdown) {
            self.dropdown_items.push(entry.display);
            self.dropdown_data.push(entry.data);
        }
        self.dropdown_index = -1;
        self.bump_state_version();
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
                self.vertical_caret_goal = None;
                self.sync_formula_mode_from_text();
            }
        }
        self.bump_state_version();
    }

    // ── Text Manipulation (character-level editing) ────────────────────

    /// Insert a character at the current cursor position, replacing any selection.
    pub fn insert_char(&mut self, ch: char) {
        let mut text = String::new();
        text.push(ch);
        self.insert_text(&text);
    }

    /// Insert text at the current cursor position, replacing any selection.
    pub fn insert_text(&mut self, text: &str) {
        let chars: Vec<char> = self.edit_text.chars().collect();
        let total = chars.len() as i32;
        let sel_start = self.sel_start.clamp(0, total);
        let sel_end = (self.sel_start + self.sel_length.max(0)).clamp(sel_start, total);
        let insert_chars: Vec<char> = text.chars().collect();

        let mut result: Vec<char> = Vec::with_capacity(chars.len() + insert_chars.len());
        result.extend_from_slice(&chars[..sel_start as usize]);
        result.extend_from_slice(&insert_chars);
        result.extend_from_slice(&chars[sel_end as usize..]);

        self.edit_text = result.into_iter().collect();
        self.sel_start = sel_start + insert_chars.len() as i32;
        self.sel_length = 0;
        self.sel_caret = self.sel_start;
        self.vertical_caret_goal = None;
        self.sync_formula_mode_from_text();
        self.bump_state_version();
    }

    /// Delete the current text selection, returning whether anything changed.
    pub fn delete_selection(&mut self) -> bool {
        let chars: Vec<char> = self.edit_text.chars().collect();
        let total = chars.len() as i32;
        let sel_start = self.sel_start.clamp(0, total);
        let sel_end = (self.sel_start + self.sel_length.max(0)).clamp(sel_start, total);
        if sel_end <= sel_start {
            return false;
        }

        let mut result: Vec<char> =
            Vec::with_capacity(chars.len() - (sel_end - sel_start) as usize);
        result.extend_from_slice(&chars[..sel_start as usize]);
        result.extend_from_slice(&chars[sel_end as usize..]);
        self.edit_text = result.into_iter().collect();
        self.sel_start = sel_start;
        self.sel_length = 0;
        self.sel_caret = self.sel_start;
        self.vertical_caret_goal = None;
        self.sync_formula_mode_from_text();
        self.bump_state_version();
        true
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
            self.vertical_caret_goal = None;
            self.sync_formula_mode_from_text();
            self.bump_state_version();
        } else if sel_start > 0 {
            // Delete char before cursor
            let mut result: Vec<char> = Vec::new();
            result.extend_from_slice(&chars[..(sel_start - 1) as usize]);
            result.extend_from_slice(&chars[sel_start as usize..]);
            self.edit_text = result.into_iter().collect();
            self.sel_start = sel_start - 1;
            self.sel_length = 0;
            self.sel_caret = self.sel_start;
            self.vertical_caret_goal = None;
            self.sync_formula_mode_from_text();
            self.bump_state_version();
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
            self.vertical_caret_goal = None;
            self.sync_formula_mode_from_text();
            self.bump_state_version();
        } else if (sel_start as usize) < chars.len() {
            // Delete char at cursor
            let mut result: Vec<char> = Vec::new();
            result.extend_from_slice(&chars[..sel_start as usize]);
            result.extend_from_slice(&chars[(sel_start + 1) as usize..]);
            self.edit_text = result.into_iter().collect();
            self.sel_length = 0;
            self.sel_caret = self.sel_start;
            self.vertical_caret_goal = None;
            self.sync_formula_mode_from_text();
            self.bump_state_version();
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
        self.vertical_caret_goal = None;
        self.bump_state_version();
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
        self.vertical_caret_goal = None;
        self.bump_state_version();
    }

    /// Move cursor to the beginning of the text.
    pub fn move_home(&mut self) {
        self.sel_start = 0;
        self.sel_length = 0;
        self.sel_caret = 0;
        self.vertical_caret_goal = None;
        self.bump_state_version();
    }

    /// Move cursor to the end of the text.
    pub fn move_end(&mut self) {
        self.sel_start = self.text_char_len();
        self.sel_length = 0;
        self.sel_caret = self.sel_start;
        self.vertical_caret_goal = None;
        self.bump_state_version();
    }

    /// Move cursor to the previous word boundary.
    pub fn move_word_left(&mut self) {
        let caret = self.prev_word_boundary(self.current_caret());
        self.sel_start = caret;
        self.sel_length = 0;
        self.sel_caret = caret;
        self.vertical_caret_goal = None;
        self.bump_state_version();
    }

    /// Move cursor to the next word boundary.
    pub fn move_word_right(&mut self) {
        let caret = self.next_word_boundary(self.current_caret());
        self.sel_start = caret;
        self.sel_length = 0;
        self.sel_caret = caret;
        self.vertical_caret_goal = None;
        self.bump_state_version();
    }

    fn vertical_line_target(&mut self, delta: i32) -> i32 {
        let lines = editor_visual_lines(&self.edit_text);
        if lines.len() <= 1 {
            return if delta < 0 { 0 } else { self.text_char_len() };
        }

        let caret = self.current_caret().clamp(0, self.text_char_len());
        let line_index = editor_line_index_for_char(&lines, caret);
        let current_line = lines[line_index];
        let current_col = (caret - current_line.start_char)
            .clamp(0, current_line.end_char - current_line.start_char);
        let goal = self.vertical_caret_goal.unwrap_or(current_col);
        self.vertical_caret_goal = Some(goal);

        let target_index = if delta < 0 {
            line_index.saturating_sub(1)
        } else {
            (line_index + 1).min(lines.len() - 1)
        };
        let target_line = lines[target_index];
        let target_col = goal.clamp(0, target_line.end_char - target_line.start_char);
        target_line.start_char + target_col
    }

    /// Move cursor to the nearest caret column on the previous visual line.
    pub fn move_line_up(&mut self) {
        let caret = self.vertical_line_target(-1);
        self.set_selection_from_anchor_and_caret_internal(caret, caret);
        self.bump_state_version();
    }

    /// Move cursor to the nearest caret column on the next visual line.
    pub fn move_line_down(&mut self) {
        let caret = self.vertical_line_target(1);
        self.set_selection_from_anchor_and_caret_internal(caret, caret);
        self.bump_state_version();
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

    /// Extend or shrink the selection to the nearest column on the previous visual line.
    pub fn select_line_up(&mut self) {
        let anchor = self.selection_anchor();
        let caret = self.vertical_line_target(-1);
        self.set_selection_from_anchor_and_caret_internal(anchor, caret);
        self.bump_state_version();
    }

    /// Extend or shrink the selection to the nearest column on the next visual line.
    pub fn select_line_down(&mut self) {
        let anchor = self.selection_anchor();
        let caret = self.vertical_line_target(1);
        self.set_selection_from_anchor_and_caret_internal(anchor, caret);
        self.bump_state_version();
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
            self.vertical_caret_goal = None;
        }
        self.preedit_text = text.to_string();
        self.preedit_cursor = cursor;
        self.composing = !text.is_empty();
        self.bump_state_version();
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
        self.vertical_caret_goal = None;
        self.composing = false;
        self.preedit_text.clear();
        self.preedit_cursor = 0;
        self.sync_formula_mode_from_text();
        self.bump_state_version();
    }

    /// Cancel preedit without modifying edit_text.
    pub fn cancel_preedit(&mut self) {
        let changed = self.composing || !self.preedit_text.is_empty() || self.preedit_cursor != 0;
        self.composing = false;
        self.preedit_text.clear();
        self.preedit_cursor = 0;
        if changed {
            self.bump_state_version();
        }
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

    /// True when the active edit state exposes a mutable text buffer.
    ///
    /// Select-only editors (read-only dropdowns) still have an edit session for
    /// list navigation, but must not expose caret movement, text selection, or
    /// mutating clipboard operations.
    pub fn accepts_text_input(&self) -> bool {
        self.editing && (self.dropdown_items.is_empty() || self.dropdown_editable)
    }

    /// True when the editor exposes a movable caret / text selection.
    pub fn supports_selection(&self) -> bool {
        self.accepts_text_input()
    }

    /// True when Cut may mutate the editor buffer (text editors only).
    pub fn supports_cut(&self) -> bool {
        self.accepts_text_input()
    }

    /// True when Paste may mutate the editor buffer (text editors only).
    pub fn supports_paste(&self) -> bool {
        self.accepts_text_input()
    }

    /// True when the editor maintains an undoable history.
    pub fn supports_undo(&self) -> bool {
        self.accepts_text_input()
    }

    /// Apply one character of type-ahead search to a select-only dropdown.
    /// Returns `true` if the search advanced (and possibly changed the
    /// selected index); `false` if the editor isn't a select-only dropdown.
    pub fn apply_select_type_ahead_char(&mut self, ch: char, delay_ms: u128) -> bool {
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
        prepare_committed_edit_text, translate_dropdown_display_to_value,
        translate_dropdown_value_to_display, validate_editor_commit_text, EditHighlightRegion,
        EditState, PreparedEditCommit,
    };

    fn editor(kind: pb::EditorKind) -> pb::EditorSpec {
        pb::EditorSpec {
            kind: kind as i32,
            validation_mode: pb::ValidationMode::ValidationBlock as i32,
            validation_trigger: pb::ValidationTrigger::OnCommit as i32,
            ..Default::default()
        }
    }

    #[test]
    fn validate_number_editor_rejects_non_numeric_and_range() {
        let mut spec = editor(pb::EditorKind::EditorNumber);
        spec.number = Some(pb::NumberEditorParams {
            min: Some(0.0),
            max: Some(100.0),
            step: None,
            format: String::new(),
            nullable: false,
        });

        assert_eq!(
            validate_editor_commit_text(&spec, "abc")[0].code,
            "number.invalid"
        );
        assert_eq!(
            validate_editor_commit_text(&spec, "120")[0].code,
            "number.max"
        );
        assert!(validate_editor_commit_text(&spec, "85").is_empty());
    }

    #[test]
    fn validate_date_time_editor_rejects_invalid_date_and_range() {
        let mut spec = editor(pb::EditorKind::EditorDateTime);
        spec.date_time = Some(pb::DateTimeEditorParams {
            format: String::new(),
            min_timestamp: Some(0),
            max_timestamp: Some(86_400_000),
            date_only: false,
            time_only: false,
        });

        assert_eq!(
            validate_editor_commit_text(&spec, "2026-02-30")[0].code,
            "date.invalid"
        );
        assert_eq!(
            validate_editor_commit_text(&spec, "1969-12-31")[0].code,
            "date.min"
        );
        assert!(validate_editor_commit_text(&spec, "1970-01-02").is_empty());
    }

    #[test]
    fn validate_date_time_editor_honors_date_only_and_time_only() {
        let mut date_spec = editor(pb::EditorKind::EditorDateTime);
        date_spec.date_time = Some(pb::DateTimeEditorParams {
            format: String::new(),
            min_timestamp: None,
            max_timestamp: None,
            date_only: true,
            time_only: false,
        });
        assert!(validate_editor_commit_text(&date_spec, "2026-05-13").is_empty());
        assert_eq!(
            validate_editor_commit_text(&date_spec, "2026-05-13 12:30")[0].code,
            "date.invalid"
        );

        let mut time_spec = editor(pb::EditorKind::EditorDateTime);
        time_spec.date_time = Some(pb::DateTimeEditorParams {
            format: String::new(),
            min_timestamp: None,
            max_timestamp: None,
            date_only: false,
            time_only: true,
        });
        assert!(validate_editor_commit_text(&time_spec, "12:30:05").is_empty());
        assert_eq!(
            validate_editor_commit_text(&time_spec, "25:00")[0].code,
            "date.invalid"
        );
    }

    #[test]
    fn validate_text_editor_rejects_newlines_when_disabled() {
        let mut spec = editor(pb::EditorKind::EditorText);
        spec.text = Some(pb::TextEditorParams {
            max_length: 0,
            mask: String::new(),
            allow_newlines: false,
            input_type: pb::InputType::Text as i32,
        });

        assert_eq!(
            validate_editor_commit_text(&spec, "a\nb")[0].code,
            "text.newline"
        );
    }

    #[test]
    fn prepare_commit_truncates_to_effective_text_max_length() {
        let mut spec = editor(pb::EditorKind::EditorText);
        spec.text = Some(pb::TextEditorParams {
            max_length: 3,
            mask: String::new(),
            allow_newlines: false,
            input_type: pb::InputType::Text as i32,
        });

        match prepare_committed_edit_text(&spec, "old", "abcdef", 10) {
            PreparedEditCommit::Commit(committed) => assert_eq!(committed, "abc"),
            other => panic!("unexpected commit result: {other:?}"),
        }
    }

    #[test]
    fn prepare_commit_supports_revert_and_allow_invalid_modes() {
        let mut spec = editor(pb::EditorKind::EditorNumber);
        spec.number = Some(pb::NumberEditorParams {
            min: Some(0.0),
            max: Some(100.0),
            step: None,
            format: String::new(),
            nullable: false,
        });

        spec.validation_mode = pb::ValidationMode::ValidationRevert as i32;
        match prepare_committed_edit_text(&spec, "42", "abc", 0) {
            PreparedEditCommit::Revert(value) => assert_eq!(value, "42"),
            other => panic!("unexpected commit result: {other:?}"),
        }

        spec.validation_mode = pb::ValidationMode::ValidationAllowInvalid as i32;
        match prepare_committed_edit_text(&spec, "42", "abc", 0) {
            PreparedEditCommit::AllowInvalid { committed, errors } => {
                assert_eq!(committed, "abc");
                assert_eq!(errors[0].code, "number.invalid");
            }
            other => panic!("unexpected commit result: {other:?}"),
        }
    }

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
        edit.start_edit(1, 0, pb::EditStartReason::EditStartUnspecified, "hello");
        edit.sel_start = 5;
        edit.sel_length = 0;
        edit.insert_char('!');
        assert_eq!(edit.edit_text, "hello!");
        assert_eq!(edit.sel_start, 6);
    }

    #[test]
    fn insert_char_replaces_selection() {
        let mut edit = EditState::default();
        edit.start_edit(1, 0, pb::EditStartReason::EditStartUnspecified, "hello");
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
        edit.start_edit(1, 0, pb::EditStartReason::EditStartUnspecified, "abc");
        edit.sel_start = 2;
        edit.sel_length = 0;
        edit.delete_back();
        assert_eq!(edit.edit_text, "ac");
        assert_eq!(edit.sel_start, 1);
    }

    #[test]
    fn delete_back_removes_selection() {
        let mut edit = EditState::default();
        edit.start_edit(1, 0, pb::EditStartReason::EditStartUnspecified, "abcdef");
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
        edit.start_edit(1, 0, pb::EditStartReason::EditStartUnspecified, "abc");
        edit.sel_start = 1;
        edit.sel_length = 0;
        edit.delete_forward();
        assert_eq!(edit.edit_text, "ac");
    }

    #[test]
    fn move_left_right() {
        let mut edit = EditState::default();
        edit.start_edit(1, 0, pb::EditStartReason::EditStartUnspecified, "abc");
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
        edit.start_edit(1, 0, pb::EditStartReason::EditStartUnspecified, "abc");
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
        edit.start_edit(1, 0, pb::EditStartReason::EditStartUnspecified, "abcd");
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
        edit.start_edit(1, 0, pb::EditStartReason::EditStartUnspecified, "가나다");
        edit.set_sel_start(1);
        edit.set_sel_length(1);

        assert_eq!(edit.get_sel_text(), "나");
    }

    #[test]
    fn move_word_left_right_uses_word_boundaries() {
        let mut edit = EditState::default();
        edit.start_edit(
            1,
            0,
            pb::EditStartReason::EditStartUnspecified,
            "abc def! ghi",
        );
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
        edit.start_edit(
            1,
            0,
            pb::EditStartReason::EditStartUnspecified,
            "abc def ghi",
        );
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
        edit.start_edit_with(
            1,
            1,
            pb::EditStartReason::EditStartUnspecified,
            "",
            Some("=SUM("),
            None,
            Some(true),
        );
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
        edit.start_edit_with(
            1,
            1,
            pb::EditStartReason::EditStartUnspecified,
            "=A1",
            None,
            None,
            Some(true),
        );
        edit.set_highlights(vec![EditHighlightRegion::default()]);
        let _ = edit.commit();
        assert!(!edit.formula_mode);
        assert!(edit.formula_highlights.is_empty());

        edit.start_edit_with(
            1,
            1,
            pb::EditStartReason::EditStartUnspecified,
            "=A1",
            None,
            None,
            Some(true),
        );
        edit.set_highlights(vec![EditHighlightRegion::default()]);
        let _ = edit.cancel();
        assert!(!edit.formula_mode);
        assert!(edit.formula_highlights.is_empty());
    }

    #[test]
    fn commit_flushes_pending_preedit() {
        let mut edit = EditState::default();
        edit.start_edit(0, 0, pb::EditStartReason::EditStartUnspecified, "");
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
        edit.start_edit(0, 0, pb::EditStartReason::EditStartUnspecified, "abc");
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
        edit.start_edit(0, 0, pb::EditStartReason::EditStartUnspecified, "hello");
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
        edit.start_edit(0, 0, pb::EditStartReason::EditStartUnspecified, "");
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
        edit.start_edit(0, 0, pb::EditStartReason::EditStartUnspecified, "prefix");
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
        edit.start_edit(0, 0, pb::EditStartReason::EditStartUnspecified, "hello");
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
        edit.start_edit(0, 0, pb::EditStartReason::EditStartUnspecified, "abcdef");
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
        edit.start_edit(0, 0, pb::EditStartReason::EditStartUnspecified, "");
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
        edit.start_edit(0, 0, pb::EditStartReason::EditStartUnspecified, "");
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
        edit.start_edit(0, 0, pb::EditStartReason::EditStartUnspecified, "abcdef");
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
