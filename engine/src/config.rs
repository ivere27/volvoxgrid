//! Batch configuration API.
//!
//! All v1 proto types are accepted directly — prost `optional` fields map to
//! `Option<T>`, giving perfect partial-update semantics. Only set fields are
//! applied; unset fields leave the engine state unchanged.

use crate::cell::CellValueData;
use crate::grid::VolvoxGrid;
use crate::indicator::{
    ColIndicatorCellState, ColIndicatorRowDefState, CornerIndicatorState, RowIndicatorSlotState,
};
use crate::proto::volvoxgrid::v1;
use crate::selection::{HOVER_CELL, HOVER_COLUMN, HOVER_ROW};
use crate::sort::{decode_sort_spec, merge_sort_spec};
use crate::style;

const LEGACY_GRIDLINE_SOLID_HORIZONTAL: i32 = 4;
const LEGACY_GRIDLINE_SOLID_VERTICAL: i32 = 5;
const LEGACY_GRIDLINE_INSET_HORIZONTAL: i32 = 6;
const LEGACY_GRIDLINE_INSET_VERTICAL: i32 = 7;
const LEGACY_GRIDLINE_RAISED_HORIZONTAL: i32 = 8;
const LEGACY_GRIDLINE_RAISED_VERTICAL: i32 = 9;

fn apply_padding_patch(base: style::Padding, patch: &v1::Padding) -> style::Padding {
    let mut next = base;
    if let Some(v) = patch.left {
        next.left = v.max(0);
    }
    if let Some(v) = patch.top {
        next.top = v.max(0);
    }
    if let Some(v) = patch.right {
        next.right = v.max(0);
    }
    if let Some(v) = patch.bottom {
        next.bottom = v.max(0);
    }
    next.clamped_non_negative()
}

fn engine_padding_to_v1(p: style::Padding) -> v1::Padding {
    v1::Padding {
        left: Some(p.left.max(0)),
        top: Some(p.top.max(0)),
        right: Some(p.right.max(0)),
        bottom: Some(p.bottom.max(0)),
    }
}

fn apply_highlight_style_patch(target: &mut style::HighlightStyle, patch: &v1::HighlightStyle) {
    let patch_style = style::HighlightStyle::from_proto(Some(patch));
    target.merge_from(&patch_style);
}

fn apply_hover_flag(mode: &mut u32, flag: u32, value: Option<bool>) {
    match value {
        Some(true) => *mode |= flag,
        Some(false) => *mode &= !flag,
        None => {}
    }
}

fn compose_grid_line_mode(style: i32, direction: i32) -> i32 {
    match (style, direction) {
        (s, _) if s == v1::GridLineStyle::GridlineNone as i32 => {
            v1::GridLineStyle::GridlineNone as i32
        }
        (s, d)
            if s == v1::GridLineStyle::GridlineSolid as i32
                && d == v1::GridLineDirection::GridlineHorizontal as i32 =>
        {
            LEGACY_GRIDLINE_SOLID_HORIZONTAL
        }
        (s, d)
            if s == v1::GridLineStyle::GridlineSolid as i32
                && d == v1::GridLineDirection::GridlineVertical as i32 =>
        {
            LEGACY_GRIDLINE_SOLID_VERTICAL
        }
        (s, d)
            if s == v1::GridLineStyle::GridlineInset as i32
                && d == v1::GridLineDirection::GridlineHorizontal as i32 =>
        {
            LEGACY_GRIDLINE_INSET_HORIZONTAL
        }
        (s, d)
            if s == v1::GridLineStyle::GridlineInset as i32
                && d == v1::GridLineDirection::GridlineVertical as i32 =>
        {
            LEGACY_GRIDLINE_INSET_VERTICAL
        }
        (s, d)
            if s == v1::GridLineStyle::GridlineRaised as i32
                && d == v1::GridLineDirection::GridlineHorizontal as i32 =>
        {
            LEGACY_GRIDLINE_RAISED_HORIZONTAL
        }
        (s, d)
            if s == v1::GridLineStyle::GridlineRaised as i32
                && d == v1::GridLineDirection::GridlineVertical as i32 =>
        {
            LEGACY_GRIDLINE_RAISED_VERTICAL
        }
        (s, _) => s,
    }
}

fn split_grid_line_mode(mode: i32) -> (i32, i32) {
    match mode {
        LEGACY_GRIDLINE_SOLID_HORIZONTAL => (
            v1::GridLineStyle::GridlineSolid as i32,
            v1::GridLineDirection::GridlineHorizontal as i32,
        ),
        LEGACY_GRIDLINE_SOLID_VERTICAL => (
            v1::GridLineStyle::GridlineSolid as i32,
            v1::GridLineDirection::GridlineVertical as i32,
        ),
        LEGACY_GRIDLINE_INSET_HORIZONTAL => (
            v1::GridLineStyle::GridlineInset as i32,
            v1::GridLineDirection::GridlineHorizontal as i32,
        ),
        LEGACY_GRIDLINE_INSET_VERTICAL => (
            v1::GridLineStyle::GridlineInset as i32,
            v1::GridLineDirection::GridlineVertical as i32,
        ),
        LEGACY_GRIDLINE_RAISED_HORIZONTAL => (
            v1::GridLineStyle::GridlineRaised as i32,
            v1::GridLineDirection::GridlineHorizontal as i32,
        ),
        LEGACY_GRIDLINE_RAISED_VERTICAL => (
            v1::GridLineStyle::GridlineRaised as i32,
            v1::GridLineDirection::GridlineVertical as i32,
        ),
        mode if mode == v1::GridLineStyle::GridlineInset as i32 => (
            v1::GridLineStyle::GridlineInset as i32,
            v1::GridLineDirection::GridlineBoth as i32,
        ),
        mode if mode == v1::GridLineStyle::GridlineRaised as i32 => (
            v1::GridLineStyle::GridlineRaised as i32,
            v1::GridLineDirection::GridlineBoth as i32,
        ),
        mode if mode == v1::GridLineStyle::GridlineSolid as i32 => (
            v1::GridLineStyle::GridlineSolid as i32,
            v1::GridLineDirection::GridlineBoth as i32,
        ),
        _ => (
            v1::GridLineStyle::GridlineNone as i32,
            v1::GridLineDirection::GridlineBoth as i32,
        ),
    }
}

fn apply_grid_lines_patch(mode: &mut i32, color: &mut u32, width: &mut i32, patch: &v1::GridLines) {
    let (mut next_style, mut next_direction) = split_grid_line_mode(*mode);
    if let Some(v) = patch.style {
        next_style = v;
    }
    if let Some(v) = patch.direction {
        next_direction = v;
    }
    *mode = compose_grid_line_mode(next_style, next_direction);
    if let Some(v) = patch.color {
        *color = v;
    }
    if let Some(v) = patch.width {
        *width = v.max(1);
    }
}

fn grid_lines_to_v1(mode: i32, color: u32, width: i32) -> v1::GridLines {
    let (style, direction) = split_grid_line_mode(mode);
    v1::GridLines {
        style: Some(style),
        direction: Some(direction),
        color: Some(color),
        width: Some(width.max(1)),
    }
}

fn apply_row_indicator_config(
    target: &mut crate::indicator::RowIndicatorState,
    cfg: &v1::RowIndicatorConfig,
) {
    if let Some(v) = cfg.visible {
        target.visible = v;
    }
    if let Some(v) = cfg.width {
        target.width_px = v.max(1);
    }
    if let Some(v) = cfg.mode_bits {
        target.mode_bits = v;
    }
    if let Some(v) = cfg.background {
        target.back_color = Some(v);
    }
    if let Some(v) = cfg.foreground {
        target.fore_color = Some(v);
    }
    if let Some(v) = cfg.grid_lines {
        target.grid_lines = Some(v);
    }
    if let Some(v) = cfg.grid_color {
        target.grid_color = Some(v);
    }
    if let Some(v) = cfg.auto_size {
        target.auto_size = v;
    }
    if let Some(v) = cfg.allow_resize {
        target.allow_resize = v;
    }
    if let Some(v) = cfg.allow_select {
        target.allow_select = v;
    }
    if let Some(v) = cfg.allow_reorder {
        target.allow_reorder = v;
    }
    if !cfg.slots.is_empty() {
        target.slots = cfg
            .slots
            .iter()
            .map(|slot| RowIndicatorSlotState {
                kind: slot
                    .kind
                    .unwrap_or(v1::RowIndicatorSlotKind::RowIndicatorSlotNone as i32),
                width_px: slot.width.unwrap_or(0).max(0),
                visible: slot.visible.unwrap_or(true),
                custom_key: slot.custom_key.clone().unwrap_or_default(),
                data: slot.data.clone().unwrap_or_default(),
            })
            .collect();
    }
}

fn row_indicator_to_proto(src: &crate::indicator::RowIndicatorState) -> v1::RowIndicatorConfig {
    v1::RowIndicatorConfig {
        visible: Some(src.visible),
        width: Some(src.width_px.max(1)),
        mode_bits: Some(src.mode_bits),
        background: src.back_color,
        foreground: src.fore_color,
        grid_lines: src.grid_lines,
        grid_color: src.grid_color,
        auto_size: Some(src.auto_size),
        allow_resize: Some(src.allow_resize),
        allow_select: Some(src.allow_select),
        allow_reorder: Some(src.allow_reorder),
        slots: src
            .slots
            .iter()
            .map(|slot| v1::RowIndicatorSlot {
                kind: Some(slot.kind),
                width: Some(slot.width_px.max(0)),
                visible: Some(slot.visible),
                custom_key: Some(slot.custom_key.clone()),
                data: Some(slot.data.clone()),
            })
            .collect(),
    }
}

fn apply_col_indicator_config(
    target: &mut crate::indicator::ColIndicatorState,
    cfg: &v1::ColIndicatorConfig,
) {
    if let Some(v) = cfg.visible {
        target.visible = v;
    }
    if let Some(v) = cfg.default_row_height {
        target.default_row_height_px = v.max(1);
    }
    if let Some(v) = cfg.band_rows {
        target.band_rows = v.max(0);
    }
    if let Some(v) = cfg.mode_bits {
        target.mode_bits = v;
    }
    if let Some(v) = cfg.background {
        target.back_color = Some(v);
    }
    if let Some(v) = cfg.foreground {
        target.fore_color = Some(v);
    }
    if let Some(v) = cfg.grid_lines {
        target.grid_lines = Some(v);
    }
    if let Some(v) = cfg.grid_color {
        target.grid_color = Some(v);
    }
    if let Some(v) = cfg.auto_size {
        target.auto_size = v;
    }
    if let Some(v) = cfg.allow_resize {
        target.allow_resize = v;
    }
    if let Some(v) = cfg.allow_reorder {
        target.allow_reorder = v;
    }
    if let Some(v) = cfg.allow_menu {
        target.allow_menu = v;
    }
    if !cfg.row_defs.is_empty() {
        target.row_defs = cfg
            .row_defs
            .iter()
            .map(|row| ColIndicatorRowDefState {
                index: row.index.unwrap_or(0).max(0),
                height_px: row.height.unwrap_or(0).max(1),
            })
            .collect();
    }
    if !cfg.cells.is_empty() {
        target.cells = cfg
            .cells
            .iter()
            .map(|cell| ColIndicatorCellState {
                row1: cell.row1.unwrap_or(0).max(0),
                row2: cell.row2.unwrap_or(0).max(0),
                col1: cell.col1.unwrap_or(0).max(0),
                col2: cell.col2.unwrap_or(0).max(0),
                text: cell.text.clone().unwrap_or_default(),
                mode_bits: cell.mode_bits.unwrap_or(0),
                custom_key: cell.custom_key.clone().unwrap_or_default(),
                data: cell.data.clone().unwrap_or_default(),
            })
            .collect();
    }
}

fn col_indicator_to_proto(src: &crate::indicator::ColIndicatorState) -> v1::ColIndicatorConfig {
    v1::ColIndicatorConfig {
        visible: Some(src.visible),
        default_row_height: Some(src.default_row_height_px.max(1)),
        band_rows: Some(src.band_rows.max(0)),
        mode_bits: Some(src.mode_bits),
        background: src.back_color,
        foreground: src.fore_color,
        grid_lines: src.grid_lines,
        grid_color: src.grid_color,
        auto_size: Some(src.auto_size),
        allow_resize: Some(src.allow_resize),
        allow_reorder: Some(src.allow_reorder),
        allow_menu: Some(src.allow_menu),
        row_defs: src
            .row_defs
            .iter()
            .map(|row| v1::ColIndicatorRowDef {
                index: Some(row.index.max(0)),
                height: Some(row.height_px.max(1)),
            })
            .collect(),
        cells: src
            .cells
            .iter()
            .map(|cell| v1::ColIndicatorCell {
                row1: Some(cell.row1.max(0)),
                row2: Some(cell.row2.max(0)),
                col1: Some(cell.col1.max(0)),
                col2: Some(cell.col2.max(0)),
                text: Some(cell.text.clone()),
                mode_bits: Some(cell.mode_bits),
                custom_key: Some(cell.custom_key.clone()),
                data: Some(cell.data.clone()),
            })
            .collect(),
    }
}

fn apply_corner_indicator_config(
    target: &mut crate::indicator::CornerIndicatorState,
    cfg: &v1::CornerIndicatorConfig,
) {
    if let Some(v) = cfg.visible {
        target.visible = v;
    }
    if let Some(v) = cfg.mode_bits {
        target.mode_bits = v;
    }
    if let Some(v) = cfg.background {
        target.back_color = Some(v);
    }
    if let Some(v) = cfg.foreground {
        target.fore_color = Some(v);
    }
    if let Some(v) = &cfg.custom_key {
        target.custom_key = v.clone();
    }
    if let Some(v) = &cfg.data {
        target.data = v.clone();
    }
}

fn corner_indicator_to_proto(src: &CornerIndicatorState) -> v1::CornerIndicatorConfig {
    v1::CornerIndicatorConfig {
        visible: Some(src.visible),
        mode_bits: Some(src.mode_bits),
        background: src.back_color,
        foreground: src.fore_color,
        custom_key: Some(src.custom_key.clone()),
        data: Some(src.data.clone()),
    }
}

fn apply_icon_slot_patch(slot: &mut Option<String>, patch: &Option<String>) {
    if let Some(v) = patch {
        if v.trim().is_empty() {
            *slot = None;
        } else {
            *slot = Some(v.clone());
        }
    }
}

fn normalize_icon_align(value: i32) -> i32 {
    match value {
        v if v == v1::IconAlign::InlineEnd as i32 => v,
        v if v == v1::IconAlign::InlineStart as i32 => v,
        v if v == v1::IconAlign::Start as i32 => v,
        v if v == v1::IconAlign::End as i32 => v,
        v if v == v1::IconAlign::Center as i32 => v,
        _ => v1::IconAlign::InlineEnd as i32,
    }
}

fn sanitize_font_names(names: &[String]) -> Vec<String> {
    names
        .iter()
        .map(|v| v.trim())
        .filter(|v| !v.is_empty())
        .map(|v| v.to_string())
        .collect()
}

fn apply_grid_font_patch(target: &mut style::GridStyleState, patch: &v1::Font) {
    if let Some(v) = &patch.family {
        target.font_name = v.trim().to_string();
    }
    if !patch.families.is_empty() {
        let names = sanitize_font_names(&patch.families);
        target.font_name = names.into_iter().next().unwrap_or_default();
    }
    if let Some(v) = patch.size {
        if v.is_finite() && v > 0.0 {
            target.font_size = v.clamp(1.0, 256.0);
        }
    }
    if let Some(v) = patch.bold {
        target.font_bold = v;
    }
    if let Some(v) = patch.italic {
        target.font_italic = v;
    }
    if let Some(v) = patch.underline {
        target.font_underline = v;
    }
    if let Some(v) = patch.strikethrough {
        target.font_strikethrough = v;
    }
    if let Some(v) = patch.width {
        if v.is_finite() {
            target.font_width = v;
        }
    }
}

fn grid_font_to_v1(target: &style::GridStyleState) -> v1::Font {
    let family = (!target.font_name.is_empty()).then(|| target.font_name.clone());
    let families = family.clone().into_iter().collect();
    v1::Font {
        family,
        families,
        size: Some(target.font_size),
        bold: Some(target.font_bold),
        italic: Some(target.font_italic),
        underline: Some(target.font_underline),
        strikethrough: Some(target.font_strikethrough),
        width: Some(target.font_width),
    }
}

fn apply_font_patch(
    font_name: &mut Option<String>,
    font_names: &mut Vec<String>,
    font_size: &mut Option<f32>,
    font_bold: &mut Option<bool>,
    font_italic: &mut Option<bool>,
    patch: &v1::Font,
) {
    if let Some(v) = &patch.family {
        let trimmed = v.trim();
        if trimmed.is_empty() {
            *font_name = None;
            font_names.clear();
        } else {
            *font_name = Some(trimmed.to_string());
            font_names.clear();
        }
    }
    if !patch.families.is_empty() {
        let names = sanitize_font_names(&patch.families);
        *font_name = names.first().cloned();
        *font_names = names;
    }
    if let Some(v) = patch.size {
        if v.is_finite() && v > 0.0 {
            *font_size = Some(v.clamp(1.0, 256.0));
        } else {
            *font_size = None;
        }
    }
    if let Some(v) = patch.bold {
        *font_bold = Some(v);
    }
    if let Some(v) = patch.italic {
        *font_italic = Some(v);
    }
}

fn font_to_v1(
    font_name: &Option<String>,
    font_names: &[String],
    font_size: Option<f32>,
    font_bold: Option<bool>,
    font_italic: Option<bool>,
) -> v1::Font {
    let family = font_name.clone().or_else(|| font_names.first().cloned());
    let families = if !font_names.is_empty() {
        font_names.to_vec()
    } else {
        family.clone().into_iter().collect()
    };
    v1::Font {
        family,
        families,
        size: font_size,
        bold: font_bold,
        italic: font_italic,
        underline: None,
        strikethrough: None,
        width: None,
    }
}

fn apply_cell_style_font_patch(target: &mut style::CellStylePatch, patch: &v1::Font) {
    if let Some(v) = &patch.family {
        let trimmed = v.trim();
        target.font_name = if trimmed.is_empty() {
            None
        } else {
            Some(trimmed.to_string())
        };
    }
    if !patch.families.is_empty() {
        let names = sanitize_font_names(&patch.families);
        target.font_name = names.first().cloned();
    }
    if let Some(v) = patch.size {
        if v.is_finite() && v > 0.0 {
            target.font_size = Some(v.clamp(1.0, 256.0));
        }
    }
    if let Some(v) = patch.bold {
        target.font_bold = Some(v);
    }
    if let Some(v) = patch.italic {
        target.font_italic = Some(v);
    }
    if let Some(v) = patch.underline {
        target.font_underline = Some(v);
    }
    if let Some(v) = patch.strikethrough {
        target.font_strikethrough = Some(v);
    }
    if let Some(v) = patch.width {
        if v.is_finite() {
            target.font_width = Some(v);
        }
    }
}

fn cell_style_font_to_v1(target: &style::CellStylePatch) -> Option<v1::Font> {
    if target.font_name.is_none()
        && target.font_size.is_none()
        && target.font_bold.is_none()
        && target.font_italic.is_none()
        && target.font_underline.is_none()
        && target.font_strikethrough.is_none()
        && target.font_width.is_none()
    {
        return None;
    }

    let family = target.font_name.clone();
    let families = family.clone().into_iter().collect();
    Some(v1::Font {
        family,
        families,
        size: target.font_size,
        bold: target.font_bold,
        italic: target.font_italic,
        underline: target.font_underline,
        strikethrough: target.font_strikethrough,
        width: target.font_width,
    })
}

fn apply_icon_style_patch(
    text_style: &mut style::IconFontStyle,
    layout: &mut style::IconLayout,
    patch: &v1::IconStyle,
) {
    if let Some(font) = &patch.font {
        apply_font_patch(
            &mut text_style.font_name,
            &mut text_style.font_names,
            &mut text_style.font_size,
            &mut text_style.font_bold,
            &mut text_style.font_italic,
            font,
        );
    }
    if let Some(v) = patch.color {
        text_style.color = Some(v);
    }
    if let Some(v) = patch.align {
        layout.align = normalize_icon_align(v);
    }
    if let Some(v) = patch.gap {
        layout.gap_px = v.max(0);
    }
}

fn icon_style_to_v1(text_style: &style::IconFontStyle, layout: style::IconLayout) -> v1::IconStyle {
    v1::IconStyle {
        font: Some(font_to_v1(
            &text_style.font_name,
            &text_style.font_names,
            text_style.font_size,
            text_style.font_bold,
            text_style.font_italic,
        )),
        color: text_style.color,
        align: Some(normalize_icon_align(layout.align)),
        gap: Some(layout.gap_px.max(0)),
    }
}

fn apply_icon_slot_style_patch(
    target: &mut Option<style::IconSlotStyle>,
    patch: &Option<v1::IconStyle>,
    default_layout: style::IconLayout,
) {
    let Some(patch) = patch else {
        return;
    };
    let slot = target.get_or_insert_with(style::IconSlotStyle::default);
    let mut layout = slot.layout.unwrap_or(default_layout);
    apply_icon_style_patch(&mut slot.text_style, &mut layout, patch);
    slot.layout = Some(layout);
}

fn icon_slot_style_to_v1(
    slot: &Option<style::IconSlotStyle>,
    default_layout: style::IconLayout,
) -> Option<v1::IconStyle> {
    slot.as_ref()
        .map(|s| icon_style_to_v1(&s.text_style, s.layout.unwrap_or(default_layout)))
}

fn decode_resize_policy(mode: i32) -> (bool, bool, bool) {
    match mode {
        1 => (true, false, false),
        2 => (false, true, false),
        3 => (true, true, false),
        4 => (true, false, true),
        5 => (false, true, true),
        6 => (true, true, true),
        _ => (false, false, false),
    }
}

fn encode_resize_policy(columns: bool, rows: bool, uniform: bool) -> i32 {
    match (columns, rows, uniform) {
        (true, false, false) => 1,
        (false, true, false) => 2,
        (true, true, false) => 3,
        (true, false, true) => 4,
        (false, true, true) => 5,
        (true, true, true) => 6,
        _ => 0,
    }
}

fn decode_freeze_policy(mode: i32) -> (bool, bool) {
    match mode {
        1 => (true, false),
        2 => (false, true),
        3 => (true, true),
        _ => (false, false),
    }
}

fn encode_freeze_policy(columns: bool, rows: bool) -> i32 {
    match (columns, rows) {
        (true, false) => 1,
        (false, true) => 2,
        (true, true) => 3,
        _ => 0,
    }
}

fn apply_header_feature_bit(bits: &mut i32, mask: i32, value: Option<bool>) {
    match value {
        Some(true) => *bits |= mask,
        Some(false) => *bits &= !mask,
        None => {}
    }
}

fn image_bytes_to_proto(data: Option<&[u8]>, format: &str) -> Option<v1::ImageData> {
    data.filter(|bytes| !bytes.is_empty())
        .map(|bytes| v1::ImageData {
            data: bytes.to_vec(),
            format: format.to_string(),
        })
}

fn v1_header_mark_to_engine(
    size: &v1::HeaderMarkSize,
    fallback: style::HeaderMarkHeight,
) -> style::HeaderMarkHeight {
    match size.value {
        Some(v1::header_mark_size::Value::Ratio(r)) if r.is_finite() => {
            style::HeaderMarkHeight::Ratio(r.clamp(0.0, 1.0))
        }
        Some(v1::header_mark_size::Value::Px(px)) => style::HeaderMarkHeight::Px(px.max(1)),
        _ => fallback,
    }
}

fn engine_header_mark_to_v1(height: style::HeaderMarkHeight) -> v1::HeaderMarkSize {
    let value = match height {
        style::HeaderMarkHeight::Ratio(r) => {
            Some(v1::header_mark_size::Value::Ratio(r.clamp(0.0, 1.0)))
        }
        style::HeaderMarkHeight::Px(px) => Some(v1::header_mark_size::Value::Px(px.max(1))),
    };
    v1::HeaderMarkSize { value }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum EffectiveCoercionMode {
    Strict,
    Flexible,
    ParseOnly,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
enum EffectiveWriteErrorMode {
    Reject,
    SetNull,
    Skip,
}

#[derive(Clone, Debug)]
enum PlannedCellValueWrite {
    None,
    Write { value: CellValueData, text: String },
    SetNull,
    Skip,
}

#[derive(Clone, Debug)]
struct PlannedCellUpdate {
    update: v1::CellUpdate,
    value_plan: PlannedCellValueWrite,
    in_bounds: bool,
}

#[derive(Clone, Debug)]
struct PlannedBatchWrite {
    entries: Vec<PlannedCellUpdate>,
    violations: Vec<v1::TypeViolation>,
    written_count: i32,
    rejected_count: i32,
    has_hard_reject: bool,
}

#[derive(Clone, Debug)]
struct ValueDecision {
    plan: PlannedCellValueWrite,
    violation: Option<v1::TypeViolation>,
    hard_reject: bool,
}

fn normalize_column_data_type(data_type: i32) -> i32 {
    match data_type {
        v if v == v1::ColumnDataType::ColumnDataString as i32 => v,
        v if v == v1::ColumnDataType::ColumnDataNumber as i32 => v,
        v if v == v1::ColumnDataType::ColumnDataDate as i32 => v,
        v if v == v1::ColumnDataType::ColumnDataBoolean as i32 => v,
        v if v == v1::ColumnDataType::ColumnDataCurrency as i32 => v,
        _ => v1::ColumnDataType::ColumnDataString as i32,
    }
}

fn effective_coercion_mode(mode: i32) -> EffectiveCoercionMode {
    match mode {
        v if v == v1::CoercionMode::CoercionStrict as i32 => EffectiveCoercionMode::Strict,
        v if v == v1::CoercionMode::CoercionParseOnly as i32 => EffectiveCoercionMode::ParseOnly,
        _ => EffectiveCoercionMode::Flexible,
    }
}

fn effective_error_mode(mode: i32) -> EffectiveWriteErrorMode {
    match mode {
        v if v == v1::WriteErrorMode::WriteErrorSetNull as i32 => EffectiveWriteErrorMode::SetNull,
        v if v == v1::WriteErrorMode::WriteErrorSkip as i32 => EffectiveWriteErrorMode::Skip,
        _ => EffectiveWriteErrorMode::Reject,
    }
}

fn parse_bool_text(raw: &str) -> Option<bool> {
    match raw.trim().to_ascii_lowercase().as_str() {
        "true" | "1" | "yes" | "y" | "on" => Some(true),
        "false" | "0" | "no" | "n" | "off" => Some(false),
        _ => None,
    }
}

fn parse_date_parts(raw: &str) -> Option<(i32, i32, i32, i32, i32, i32)> {
    let s = raw.trim();
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
        (p0, p1, p2)
    } else if parts[2].len() == 4 {
        (p2, p0, p1)
    } else {
        return None;
    };
    if !(1..=12).contains(&m) || !(1..=31).contains(&d) {
        return None;
    }
    let hh = parts
        .get(3)
        .and_then(|v| v.parse::<i32>().ok())
        .unwrap_or(0);
    let mm = parts
        .get(4)
        .and_then(|v| v.parse::<i32>().ok())
        .unwrap_or(0);
    let ss = parts
        .get(5)
        .and_then(|v| v.parse::<i32>().ok())
        .unwrap_or(0);
    if !(0..=23).contains(&hh) || !(0..=59).contains(&mm) || !(0..=59).contains(&ss) {
        return None;
    }
    Some((y, m, d, hh, mm, ss))
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

fn parse_timestamp_text(raw: &str) -> Option<i64> {
    let trimmed = raw.trim();
    if trimmed.is_empty() {
        return None;
    }
    if let Ok(ms) = trimmed.parse::<i64>() {
        return Some(ms);
    }
    let (y, m, d, hh, mm, ss) = parse_date_parts(trimmed)?;
    let days = days_from_civil(y, m, d);
    let secs = hh as i64 * 3_600 + mm as i64 * 60 + ss as i64;
    Some(days * 86_400_000 + secs * 1_000)
}

fn cell_value_to_text(value: &CellValueData) -> String {
    match value {
        CellValueData::Text(v) => v.clone(),
        CellValueData::Number(v) => v.to_string(),
        CellValueData::Bool(v) => {
            if *v {
                "TRUE".to_string()
            } else {
                "FALSE".to_string()
            }
        }
        CellValueData::Bytes(_) => String::new(),
        CellValueData::Timestamp(v) => v.to_string(),
        CellValueData::Empty => String::new(),
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// apply_config / get_config
// ═══════════════════════════════════════════════════════════════════════════

impl VolvoxGrid {
    /// Apply a partial `GridConfig`. Only set sub-messages are dispatched.
    pub fn apply_config(&mut self, config: &v1::GridConfig) {
        if let Some(lc) = &config.layout {
            self.apply_layout_config(lc);
        }
        if let Some(sc) = &config.style {
            self.apply_style_config(sc);
        }
        if let Some(sel) = &config.selection {
            self.apply_selection_config(sel);
        }
        if let Some(ec) = &config.editing {
            self.apply_edit_config(ec);
        }
        if let Some(sc) = &config.scrolling {
            self.apply_scroll_config(sc);
        }
        if let Some(oc) = &config.outline {
            self.apply_outline_config(oc);
        }
        if let Some(sc) = &config.span {
            self.apply_span_config(sc);
        }
        if let Some(ic) = &config.interaction {
            self.apply_interaction_config(ic);
        }
        if let Some(rc) = &config.rendering {
            self.apply_render_config(rc);
        }
        if let Some(ic) = &config.indicators {
            self.apply_indicator_bands_config(ic);
        }
    }

    /// Snapshot the full current state as a `GridConfig`.
    pub fn get_config(&self) -> v1::GridConfig {
        v1::GridConfig {
            layout: Some(self.get_layout_config()),
            style: Some(self.get_style_config()),
            selection: Some(self.get_selection_config()),
            editing: Some(self.get_edit_config()),
            scrolling: Some(self.get_scroll_config()),
            outline: Some(self.get_outline_config()),
            span: Some(self.get_span_config()),
            interaction: Some(self.get_interaction_config()),
            rendering: Some(self.get_render_config()),
            indicators: Some(self.get_indicator_bands_config()),
            version: Self::version().to_string(),
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Sub-config apply methods
    // ═══════════════════════════════════════════════════════════════════════

    fn apply_layout_config(&mut self, lc: &v1::LayoutConfig) {
        // rows/cols must be applied before fixed/frozen to avoid clamping issues.
        if let Some(rows) = lc.rows {
            self.set_rows(rows);
        }
        if let Some(cols) = lc.cols {
            self.set_cols(cols);
        }
        if let Some(fr) = lc.fixed_rows {
            self.fixed_rows = fr.max(0).min(self.rows);
            self.selection
                .clamp(self.rows, self.cols, self.fixed_rows, self.fixed_cols);
        }
        if let Some(fc) = lc.fixed_cols {
            self.fixed_cols = fc.max(0).min(self.cols);
            self.selection
                .clamp(self.rows, self.cols, self.fixed_rows, self.fixed_cols);
        }
        if let Some(fr) = lc.frozen_rows {
            self.frozen_rows = fr.max(0).min(self.rows - self.fixed_rows);
        }
        if let Some(fc) = lc.frozen_cols {
            self.frozen_cols = fc.max(0).min(self.cols - self.fixed_cols);
        }
        if let Some(h) = lc.default_row_height {
            self.default_row_height = h.max(1);
            self.layout.invalidate();
        }
        if let Some(w) = lc.default_col_width {
            self.default_col_width = w.max(1);
            self.layout.invalidate();
        }
        if let Some(rtl) = lc.right_to_left {
            self.right_to_left = rtl;
        }
        if let Some(elc) = lc.extend_last_col {
            self.extend_last_col = elc;
            self.layout.invalidate();
        }
        self.mark_dirty();
    }

    fn apply_indicator_bands_config(&mut self, bands: &v1::IndicatorsConfig) {
        if let Some(cfg) = &bands.row_start {
            apply_row_indicator_config(&mut self.indicator_bands.row_start, cfg);
        }
        if let Some(cfg) = &bands.row_end {
            apply_row_indicator_config(&mut self.indicator_bands.row_end, cfg);
        }
        if let Some(cfg) = &bands.col_top {
            apply_col_indicator_config(&mut self.indicator_bands.col_top, cfg);
        }
        if let Some(cfg) = &bands.col_bottom {
            apply_col_indicator_config(&mut self.indicator_bands.col_bottom, cfg);
        }
        if let Some(cfg) = &bands.corner_top_start {
            apply_corner_indicator_config(&mut self.indicator_bands.corner_top_start, cfg);
        }
        if let Some(cfg) = &bands.corner_top_end {
            apply_corner_indicator_config(&mut self.indicator_bands.corner_top_end, cfg);
        }
        if let Some(cfg) = &bands.corner_bottom_start {
            apply_corner_indicator_config(&mut self.indicator_bands.corner_bottom_start, cfg);
        }
        if let Some(cfg) = &bands.corner_bottom_end {
            apply_corner_indicator_config(&mut self.indicator_bands.corner_bottom_end, cfg);
        }
        self.mark_dirty();
    }

    fn apply_style_config(&mut self, sc: &v1::StyleConfig) {
        if let Some(v) = sc.background {
            self.style.back_color = v;
        }
        if let Some(v) = sc.foreground {
            self.style.fore_color = v;
        }
        if let Some(v) = sc.alternate_background {
            self.style.back_color_alternate = v;
        }
        if let Some(v) = &sc.font {
            apply_grid_font_patch(&mut self.style, v);
        }
        if let Some(v) = &sc.cell_padding {
            self.style.cell_padding = apply_padding_patch(self.style.cell_padding, v);
        }
        if let Some(v) = sc.text_effect {
            self.style.text_effect = v;
        }
        if let Some(v) = sc.progress_color {
            self.style.progress_color = v;
        }
        if let Some(v) = &sc.grid_lines {
            apply_grid_lines_patch(
                &mut self.style.grid_lines,
                &mut self.style.grid_color,
                &mut self.style.grid_line_width,
                v,
            );
        }
        if let Some(v) = &sc.fixed {
            if let Some(value) = v.background {
                self.style.back_color_fixed = value;
            }
            if let Some(value) = v.foreground {
                self.style.fore_color_fixed = value;
            }
            if let Some(value) = v.text_effect {
                self.style.text_effect_fixed = value;
            }
            if let Some(value) = &v.grid_lines {
                apply_grid_lines_patch(
                    &mut self.style.grid_lines_fixed,
                    &mut self.style.grid_color_fixed,
                    &mut self.style.grid_line_width,
                    value,
                );
            }
            if let Some(value) = &v.cell_padding {
                self.style.fixed_cell_padding =
                    apply_padding_patch(self.style.fixed_cell_padding, value);
            }
        }
        if let Some(v) = &sc.frozen {
            if let Some(value) = v.background {
                self.style.back_color_frozen = value;
            }
            if let Some(value) = v.foreground {
                self.style.fore_color_frozen = value;
            }
            if sc
                .fixed
                .as_ref()
                .and_then(|region| region.text_effect)
                .is_none()
            {
                if let Some(value) = v.text_effect {
                    self.style.text_effect_fixed = value;
                }
            }
            if sc
                .fixed
                .as_ref()
                .and_then(|region| region.grid_lines.as_ref())
                .is_none()
            {
                if let Some(value) = &v.grid_lines {
                    apply_grid_lines_patch(
                        &mut self.style.grid_lines_fixed,
                        &mut self.style.grid_color_fixed,
                        &mut self.style.grid_line_width,
                        value,
                    );
                }
            }
            if sc
                .fixed
                .as_ref()
                .and_then(|region| region.cell_padding.as_ref())
                .is_none()
            {
                if let Some(value) = &v.cell_padding {
                    self.style.fixed_cell_padding =
                        apply_padding_patch(self.style.fixed_cell_padding, value);
                }
            }
        }
        if let Some(v) = sc.sheet_background {
            self.style.back_color_bkg = v;
        }
        if let Some(v) = sc.sheet_border {
            self.style.sheet_border = v;
        }
        if let Some(v) = sc.appearance {
            self.style.appearance = v;
        }
        if let Some(v) = &sc.background_image {
            self.style.background_image = v.clone();
        }
        if let Some(v) = sc.background_image_align {
            self.style.background_image_alignment = v;
        }
        if let Some(v) = &sc.text_rendering {
            if let Some(mode) = v.mode {
                self.style.text_render_mode = mode;
            }
            if let Some(hinting) = v.hinting {
                self.style.text_hinting_mode = hinting;
            }
            if let Some(pixel_snap) = v.pixel_snap {
                self.style.text_pixel_snap = pixel_snap;
            }
        }
        if let Some(v) = &sc.header {
            if let Some(separator) = &v.separator {
                if let Some(enabled) = separator.enabled {
                    self.style.header_separator.enabled = enabled;
                }
                if let Some(color) = separator.color {
                    self.style.header_separator.color = color;
                }
                if let Some(width) = separator.width {
                    self.style.header_separator.width_px = width.max(1);
                }
                if let Some(height) = &separator.height {
                    self.style.header_separator.height =
                        v1_header_mark_to_engine(height, self.style.header_separator.height);
                }
                if let Some(skip_merged) = separator.skip_merged {
                    self.style.header_separator.skip_merged = skip_merged;
                }
            }
            if let Some(handle) = &v.resize_handle {
                if let Some(enabled) = handle.enabled {
                    self.style.header_resize_handle.enabled = enabled;
                }
                if let Some(color) = handle.color {
                    self.style.header_resize_handle.color = color;
                }
                if let Some(width) = handle.width {
                    self.style.header_resize_handle.width_px = width.max(1);
                }
                if let Some(height) = &handle.height {
                    self.style.header_resize_handle.height =
                        v1_header_mark_to_engine(height, self.style.header_resize_handle.height);
                }
                if let Some(hit_width) = handle.hit_width {
                    self.style.header_resize_handle.hit_width_px = hit_width.max(1);
                }
                if let Some(show_only_when_resizable) = handle.show_only_when_resizable {
                    self.style.header_resize_handle.show_only_when_resizable =
                        show_only_when_resizable;
                }
            }
        }
        if let Some(v) = &sc.icons {
            if let Some(slots) = &v.slots {
                apply_icon_slot_patch(
                    &mut self.style.icon_theme_slots.sort_ascending,
                    &slots.sort_ascending,
                );
                apply_icon_slot_patch(
                    &mut self.style.icon_theme_slots.sort_descending,
                    &slots.sort_descending,
                );
                apply_icon_slot_patch(&mut self.style.icon_theme_slots.sort_none, &slots.sort_none);
                apply_icon_slot_patch(
                    &mut self.style.icon_theme_slots.tree_expanded,
                    &slots.tree_expanded,
                );
                apply_icon_slot_patch(
                    &mut self.style.icon_theme_slots.tree_collapsed,
                    &slots.tree_collapsed,
                );
                apply_icon_slot_patch(&mut self.style.icon_theme_slots.menu, &slots.menu);
                apply_icon_slot_patch(&mut self.style.icon_theme_slots.filter, &slots.filter);
                apply_icon_slot_patch(
                    &mut self.style.icon_theme_slots.filter_active,
                    &slots.filter_active,
                );
                apply_icon_slot_patch(&mut self.style.icon_theme_slots.columns, &slots.columns);
                apply_icon_slot_patch(
                    &mut self.style.icon_theme_slots.drag_handle,
                    &slots.drag_handle,
                );
                apply_icon_slot_patch(
                    &mut self.style.icon_theme_slots.checkbox_checked,
                    &slots.checkbox_checked,
                );
                apply_icon_slot_patch(
                    &mut self.style.icon_theme_slots.checkbox_unchecked,
                    &slots.checkbox_unchecked,
                );
                apply_icon_slot_patch(
                    &mut self.style.icon_theme_slots.checkbox_indeterminate,
                    &slots.checkbox_indeterminate,
                );
            }
            if let Some(defaults) = &v.defaults {
                apply_icon_style_patch(
                    &mut self.style.icon_theme_defaults.text_style,
                    &mut self.style.icon_theme_defaults.layout,
                    defaults,
                );
            }
            if let Some(overrides) = &v.overrides {
                let default_layout = self.style.icon_theme_defaults.layout;
                apply_icon_slot_style_patch(
                    &mut self.style.icon_theme_slot_styles.sort_ascending,
                    &overrides.sort_ascending,
                    default_layout,
                );
                apply_icon_slot_style_patch(
                    &mut self.style.icon_theme_slot_styles.sort_descending,
                    &overrides.sort_descending,
                    default_layout,
                );
                apply_icon_slot_style_patch(
                    &mut self.style.icon_theme_slot_styles.sort_none,
                    &overrides.sort_none,
                    default_layout,
                );
                apply_icon_slot_style_patch(
                    &mut self.style.icon_theme_slot_styles.tree_expanded,
                    &overrides.tree_expanded,
                    default_layout,
                );
                apply_icon_slot_style_patch(
                    &mut self.style.icon_theme_slot_styles.tree_collapsed,
                    &overrides.tree_collapsed,
                    default_layout,
                );
                apply_icon_slot_style_patch(
                    &mut self.style.icon_theme_slot_styles.menu,
                    &overrides.menu,
                    default_layout,
                );
                apply_icon_slot_style_patch(
                    &mut self.style.icon_theme_slot_styles.filter,
                    &overrides.filter,
                    default_layout,
                );
                apply_icon_slot_style_patch(
                    &mut self.style.icon_theme_slot_styles.filter_active,
                    &overrides.filter_active,
                    default_layout,
                );
                apply_icon_slot_style_patch(
                    &mut self.style.icon_theme_slot_styles.columns,
                    &overrides.columns,
                    default_layout,
                );
                apply_icon_slot_style_patch(
                    &mut self.style.icon_theme_slot_styles.drag_handle,
                    &overrides.drag_handle,
                    default_layout,
                );
                apply_icon_slot_style_patch(
                    &mut self.style.icon_theme_slot_styles.checkbox_checked,
                    &overrides.checkbox_checked,
                    default_layout,
                );
                apply_icon_slot_style_patch(
                    &mut self.style.icon_theme_slot_styles.checkbox_unchecked,
                    &overrides.checkbox_unchecked,
                    default_layout,
                );
                apply_icon_slot_style_patch(
                    &mut self.style.icon_theme_slot_styles.checkbox_indeterminate,
                    &overrides.checkbox_indeterminate,
                    default_layout,
                );
            }
            if let Some(pictures) = &v.pictures {
                self.sort_state.sort_ascending_picture = pictures
                    .sort_ascending
                    .as_ref()
                    .filter(|img| !img.data.is_empty())
                    .map(|img| img.data.clone());
                self.sort_state.sort_descending_picture = pictures
                    .sort_descending
                    .as_ref()
                    .filter(|img| !img.data.is_empty())
                    .map(|img| img.data.clone());
                self.outline.node_open_picture = pictures
                    .node_open
                    .as_ref()
                    .filter(|img| !img.data.is_empty())
                    .map(|img| img.data.clone());
                self.outline.node_closed_picture = pictures
                    .node_closed
                    .as_ref()
                    .filter(|img| !img.data.is_empty())
                    .map(|img| img.data.clone());
                self.style.checkbox_checked_picture = pictures
                    .checkbox_checked
                    .as_ref()
                    .filter(|img| !img.data.is_empty())
                    .map(|img| img.data.clone());
                self.style.checkbox_unchecked_picture = pictures
                    .checkbox_unchecked
                    .as_ref()
                    .filter(|img| !img.data.is_empty())
                    .map(|img| img.data.clone());
                self.style.checkbox_indeterminate_picture = pictures
                    .checkbox_indeterminate
                    .as_ref()
                    .filter(|img| !img.data.is_empty())
                    .map(|img| img.data.clone());
            }
        }
        if let Some(v) = sc.image_over_text {
            self.style.image_over_text = v;
        }
        if let Some(v) = sc.show_sort_numbers {
            self.style.show_sort_numbers = v;
        }
        if let Some(v) = sc.apply_scope {
            self.apply_scope = v;
        }
        if let Some(v) = sc.custom_render {
            self.custom_render = v;
        }
        if let Some(v) = &sc.format {
            self.format_string = v.clone();
        }
        if let Some(v) = sc.word_wrap {
            self.word_wrap = v;
        }
        if let Some(v) = sc.ellipsis {
            self.ellipsis_mode = v;
        }
        if let Some(v) = sc.text_overflow {
            self.text_overflow = v;
        }
        self.mark_dirty();
    }

    fn apply_selection_config(&mut self, sel: &v1::SelectionConfig) {
        if let Some(v) = sel.mode {
            self.selection.mode = v;
        }
        if let Some(v) = sel.focus_border {
            self.selection.focus_border = v;
        }
        if let Some(v) = sel.visibility {
            self.selection.selection_visibility = v;
        }
        if let Some(v) = sel.allow {
            self.allow_selection = v;
            self.selection.allow_selection = v;
        }
        if let Some(v) = sel.header_click_select {
            self.header_click_select = v;
            self.selection.header_click_select = v;
        }
        if let Some(v) = &sel.style {
            apply_highlight_style_patch(&mut self.selection.selection_style, v);
        }
        if let Some(v) = &sel.hover {
            let mut hover_mode = self.selection.hover_mode;
            apply_hover_flag(&mut hover_mode, HOVER_ROW, v.row);
            apply_hover_flag(&mut hover_mode, HOVER_COLUMN, v.column);
            apply_hover_flag(&mut hover_mode, HOVER_CELL, v.cell);
            self.selection.hover_mode = hover_mode;
            if let Some(style) = &v.row_style {
                apply_highlight_style_patch(&mut self.selection.hover_row_style, style);
            }
            if let Some(style) = &v.column_style {
                apply_highlight_style_patch(&mut self.selection.hover_column_style, style);
            }
            if let Some(style) = &v.cell_style {
                apply_highlight_style_patch(&mut self.selection.hover_cell_style, style);
            }
        }
        if let Some(v) = &sel.indicator_row_style {
            let mut style = self
                .selection
                .indicator_row_style
                .clone()
                .unwrap_or_default();
            apply_highlight_style_patch(&mut style, v);
            self.selection.indicator_row_style = Some(style);
        }
        if let Some(v) = &sel.indicator_col_style {
            let mut style = self
                .selection
                .indicator_col_style
                .clone()
                .unwrap_or_default();
            apply_highlight_style_patch(&mut style, v);
            self.selection.indicator_col_style = Some(style);
        }
        self.mark_dirty();
    }

    fn apply_edit_config(&mut self, ec: &v1::EditConfig) {
        if let Some(v) = ec.trigger {
            self.edit_trigger_mode = v;
        }
        if let Some(v) = ec.tab_behavior {
            self.tab_behavior = v;
        }
        if let Some(v) = ec.dropdown_trigger {
            self.dropdown_trigger = v;
        }
        if let Some(v) = ec.dropdown_search {
            self.dropdown_search = v;
        }
        if let Some(v) = ec.max_length {
            self.edit_max_length = v;
        }
        if let Some(v) = &ec.mask {
            self.edit_mask = v.clone();
        }
        if let Some(v) = ec.host_key_dispatch {
            self.host_key_dispatch = v;
        }
        if let Some(v) = ec.host_pointer_dispatch {
            self.host_pointer_dispatch = v;
        }
        self.mark_dirty();
    }

    fn apply_scroll_config(&mut self, sc: &v1::ScrollConfig) {
        if let Some(v) = sc.scrollbars {
            self.scroll_bars = v;
        }
        if let Some(v) = sc.scroll_track {
            self.scroll_track = v;
        }
        if let Some(v) = sc.scroll_tips {
            self.scroll_tips = v;
        }
        if let Some(v) = sc.fling_enabled {
            self.fling_enabled = v;
            if !v {
                // Avoid preserving stale fling velocity across temporary disable/enable
                // cycles (e.g. while switching active grids in Flutter).
                self.scroll.stop_fling();
            }
        }
        if let Some(v) = sc.fling_impulse_gain {
            self.fling_impulse_gain = v;
        }
        if let Some(v) = sc.fling_friction {
            self.fling_friction = v;
        }
        if let Some(v) = sc.pinch_zoom_enabled {
            self.pinch_zoom_enabled = v;
        }
        if let Some(v) = sc.fast_scroll {
            self.fast_scroll_enabled = v;
        }
        self.mark_dirty();
    }

    fn apply_outline_config(&mut self, oc: &v1::OutlineConfig) {
        if let Some(v) = oc.tree_indicator {
            self.outline.tree_indicator = v;
        }
        if let Some(v) = oc.tree_column {
            self.outline.tree_column = v;
        }
        if let Some(v) = oc.tree_color {
            self.style.tree_color = v;
        }
        if let Some(v) = oc.group_total_position {
            self.outline.group_total_position = v;
        }
        if let Some(v) = oc.multi_totals {
            self.outline.multi_totals = v;
        }
        self.mark_dirty();
    }

    fn apply_span_config(&mut self, sc: &v1::SpanConfig) {
        if let Some(v) = sc.cell_span {
            self.span.mode = v;
        }
        if let Some(v) = sc.cell_span_fixed {
            self.span.mode_fixed = v;
        }
        if let Some(v) = sc.cell_span_compare {
            self.span.span_compare = v;
        }
        if let Some(v) = sc.group_span_compare {
            self.span.span_compare = v;
        }
        self.mark_dirty();
    }

    fn apply_interaction_config(&mut self, ic: &v1::InteractionConfig) {
        if let Some(v) = &ic.resize {
            let (mut columns, mut rows, mut uniform) =
                decode_resize_policy(self.allow_user_resizing);
            if let Some(value) = v.columns {
                columns = value;
            }
            if let Some(value) = v.rows {
                rows = value;
            }
            if let Some(value) = v.uniform {
                uniform = value;
            }
            self.allow_user_resizing = encode_resize_policy(columns, rows, uniform);
        }
        if let Some(v) = &ic.freeze {
            let (mut columns, mut rows) = decode_freeze_policy(self.allow_user_freezing);
            if let Some(value) = v.columns {
                columns = value;
            }
            if let Some(value) = v.rows {
                rows = value;
            }
            self.allow_user_freezing = encode_freeze_policy(columns, rows);
        }
        if let Some(v) = ic.type_ahead {
            self.type_ahead_mode = v;
        }
        if let Some(v) = ic.type_ahead_delay {
            self.type_ahead_delay = v;
        }
        if let Some(v) = ic.auto_size_mouse {
            self.auto_size_mouse = v;
        }
        if let Some(v) = ic.auto_size_mode {
            self.auto_size_mode = v;
        }
        if let Some(v) = ic.auto_resize {
            self.auto_resize = v;
        }
        if let Some(v) = ic.drag_mode {
            self.drag.drag_mode = v;
        }
        if let Some(v) = ic.drop_mode {
            self.drag.drop_mode = v;
        }
        if let Some(v) = &ic.header_features {
            let mut bits = self.header_features;
            apply_header_feature_bit(&mut bits, 1, v.sort);
            apply_header_feature_bit(&mut bits, 2, v.reorder);
            apply_header_feature_bit(&mut bits, 4, v.chooser);
            self.header_features = bits;
        }
        self.mark_dirty();
    }

    fn apply_render_config(&mut self, rc: &v1::RenderConfig) {
        if let Some(v) = rc.renderer_mode {
            self.renderer_mode = v;
        }
        if let Some(v) = rc.debug_overlay {
            self.debug_overlay = v;
            self.layer_profiling = v;
        }
        if let Some(v) = rc.animation_enabled {
            self.animation.enabled = v;
        }
        if let Some(v) = rc.animation_duration_ms {
            self.animation.set_duration_ms(v);
        }
        if let Some(v) = rc.text_layout_cache_cap {
            self.set_text_layout_cache_cap(v);
        }
        if let Some(v) = rc.present_mode {
            self.present_mode = v;
        }
        if let Some(v) = rc.frame_pacing_mode {
            self.frame_pacing_mode = v;
        }
        if let Some(v) = rc.target_frame_rate_hz {
            self.target_frame_rate_hz = if v <= 0 {
                crate::grid::DEFAULT_TARGET_FRAME_RATE_HZ
            } else {
                v
            };
        }
        if let Some(v) = rc.render_layer_mask {
            self.render_layer_mask = v as u64;
        }
        self.mark_dirty();
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Sub-config get methods
    // ═══════════════════════════════════════════════════════════════════════

    fn get_layout_config(&self) -> v1::LayoutConfig {
        v1::LayoutConfig {
            rows: Some(self.rows),
            cols: Some(self.cols),
            fixed_rows: Some(self.fixed_rows),
            fixed_cols: Some(self.fixed_cols),
            frozen_rows: Some(self.frozen_rows),
            frozen_cols: Some(self.frozen_cols),
            default_row_height: Some(self.default_row_height),
            default_col_width: Some(self.default_col_width),
            right_to_left: Some(self.right_to_left),
            extend_last_col: Some(self.extend_last_col),
        }
    }

    fn get_style_config(&self) -> v1::StyleConfig {
        v1::StyleConfig {
            background: Some(self.style.back_color),
            foreground: Some(self.style.fore_color),
            alternate_background: Some(self.style.back_color_alternate),
            font: Some(grid_font_to_v1(&self.style)),
            cell_padding: Some(engine_padding_to_v1(self.style.cell_padding)),
            text_effect: Some(self.style.text_effect),
            progress_color: Some(self.style.progress_color),
            grid_lines: Some(grid_lines_to_v1(
                self.style.grid_lines,
                self.style.grid_color,
                self.style.grid_line_width,
            )),
            fixed: Some(v1::RegionStyle {
                background: Some(self.style.back_color_fixed),
                foreground: Some(self.style.fore_color_fixed),
                font: None,
                grid_lines: Some(grid_lines_to_v1(
                    self.style.grid_lines_fixed,
                    self.style.grid_color_fixed,
                    self.style.grid_line_width,
                )),
                text_effect: Some(self.style.text_effect_fixed),
                separator: None,
                cell_padding: Some(engine_padding_to_v1(self.style.fixed_cell_padding)),
            }),
            frozen: Some(v1::RegionStyle {
                background: Some(self.style.back_color_frozen),
                foreground: Some(self.style.fore_color_frozen),
                font: None,
                grid_lines: None,
                text_effect: None,
                separator: None,
                cell_padding: None,
            }),
            header: Some(v1::HeaderStyle {
                separator: Some(v1::HeaderSeparator {
                    enabled: Some(self.style.header_separator.enabled),
                    color: Some(self.style.header_separator.color),
                    width: Some(self.style.header_separator.width_px.max(1)),
                    height: Some(engine_header_mark_to_v1(self.style.header_separator.height)),
                    skip_merged: Some(self.style.header_separator.skip_merged),
                }),
                resize_handle: Some(v1::HeaderResizeHandle {
                    enabled: Some(self.style.header_resize_handle.enabled),
                    color: Some(self.style.header_resize_handle.color),
                    width: Some(self.style.header_resize_handle.width_px.max(1)),
                    height: Some(engine_header_mark_to_v1(
                        self.style.header_resize_handle.height,
                    )),
                    hit_width: Some(self.style.header_resize_handle.hit_width_px.max(1)),
                    show_only_when_resizable: Some(
                        self.style.header_resize_handle.show_only_when_resizable,
                    ),
                }),
            }),
            sheet_background: Some(self.style.back_color_bkg),
            sheet_border: Some(self.style.sheet_border),
            appearance: Some(self.style.appearance),
            background_image: (!self.style.background_image.is_empty())
                .then(|| self.style.background_image.clone()),
            background_image_align: Some(self.style.background_image_alignment),
            text_rendering: Some(v1::TextRendering {
                mode: Some(self.style.text_render_mode),
                hinting: Some(self.style.text_hinting_mode),
                pixel_snap: Some(self.style.text_pixel_snap),
            }),
            icons: Some(v1::IconTheme {
                slots: Some(v1::IconSlots {
                    sort_ascending: self.style.icon_theme_slots.sort_ascending.clone(),
                    sort_descending: self.style.icon_theme_slots.sort_descending.clone(),
                    sort_none: self.style.icon_theme_slots.sort_none.clone(),
                    tree_expanded: self.style.icon_theme_slots.tree_expanded.clone(),
                    tree_collapsed: self.style.icon_theme_slots.tree_collapsed.clone(),
                    menu: self.style.icon_theme_slots.menu.clone(),
                    filter: self.style.icon_theme_slots.filter.clone(),
                    filter_active: self.style.icon_theme_slots.filter_active.clone(),
                    columns: self.style.icon_theme_slots.columns.clone(),
                    drag_handle: self.style.icon_theme_slots.drag_handle.clone(),
                    checkbox_checked: self.style.icon_theme_slots.checkbox_checked.clone(),
                    checkbox_unchecked: self.style.icon_theme_slots.checkbox_unchecked.clone(),
                    checkbox_indeterminate: self
                        .style
                        .icon_theme_slots
                        .checkbox_indeterminate
                        .clone(),
                }),
                defaults: Some(icon_style_to_v1(
                    &self.style.icon_theme_defaults.text_style,
                    self.style.icon_theme_defaults.layout,
                )),
                overrides: Some(v1::IconSlotStyles {
                    sort_ascending: icon_slot_style_to_v1(
                        &self.style.icon_theme_slot_styles.sort_ascending,
                        self.style.icon_theme_defaults.layout,
                    ),
                    sort_descending: icon_slot_style_to_v1(
                        &self.style.icon_theme_slot_styles.sort_descending,
                        self.style.icon_theme_defaults.layout,
                    ),
                    sort_none: icon_slot_style_to_v1(
                        &self.style.icon_theme_slot_styles.sort_none,
                        self.style.icon_theme_defaults.layout,
                    ),
                    tree_expanded: icon_slot_style_to_v1(
                        &self.style.icon_theme_slot_styles.tree_expanded,
                        self.style.icon_theme_defaults.layout,
                    ),
                    tree_collapsed: icon_slot_style_to_v1(
                        &self.style.icon_theme_slot_styles.tree_collapsed,
                        self.style.icon_theme_defaults.layout,
                    ),
                    menu: icon_slot_style_to_v1(
                        &self.style.icon_theme_slot_styles.menu,
                        self.style.icon_theme_defaults.layout,
                    ),
                    filter: icon_slot_style_to_v1(
                        &self.style.icon_theme_slot_styles.filter,
                        self.style.icon_theme_defaults.layout,
                    ),
                    filter_active: icon_slot_style_to_v1(
                        &self.style.icon_theme_slot_styles.filter_active,
                        self.style.icon_theme_defaults.layout,
                    ),
                    columns: icon_slot_style_to_v1(
                        &self.style.icon_theme_slot_styles.columns,
                        self.style.icon_theme_defaults.layout,
                    ),
                    drag_handle: icon_slot_style_to_v1(
                        &self.style.icon_theme_slot_styles.drag_handle,
                        self.style.icon_theme_defaults.layout,
                    ),
                    checkbox_checked: icon_slot_style_to_v1(
                        &self.style.icon_theme_slot_styles.checkbox_checked,
                        self.style.icon_theme_defaults.layout,
                    ),
                    checkbox_unchecked: icon_slot_style_to_v1(
                        &self.style.icon_theme_slot_styles.checkbox_unchecked,
                        self.style.icon_theme_defaults.layout,
                    ),
                    checkbox_indeterminate: icon_slot_style_to_v1(
                        &self.style.icon_theme_slot_styles.checkbox_indeterminate,
                        self.style.icon_theme_defaults.layout,
                    ),
                }),
                pictures: Some(v1::IconPictures {
                    sort_ascending: image_bytes_to_proto(
                        self.sort_state.sort_ascending_picture.as_deref(),
                        "png",
                    ),
                    sort_descending: image_bytes_to_proto(
                        self.sort_state.sort_descending_picture.as_deref(),
                        "png",
                    ),
                    node_open: image_bytes_to_proto(
                        self.outline.node_open_picture.as_deref(),
                        "png",
                    ),
                    node_closed: image_bytes_to_proto(
                        self.outline.node_closed_picture.as_deref(),
                        "png",
                    ),
                    checkbox_checked: image_bytes_to_proto(
                        self.style.checkbox_checked_picture.as_deref(),
                        "png",
                    ),
                    checkbox_unchecked: image_bytes_to_proto(
                        self.style.checkbox_unchecked_picture.as_deref(),
                        "png",
                    ),
                    checkbox_indeterminate: image_bytes_to_proto(
                        self.style.checkbox_indeterminate_picture.as_deref(),
                        "png",
                    ),
                }),
            }),
            image_over_text: Some(self.style.image_over_text),
            show_sort_numbers: Some(self.style.show_sort_numbers),
            apply_scope: Some(self.apply_scope),
            custom_render: Some(self.custom_render),
            format: Some(self.format_string.clone()),
            word_wrap: Some(self.word_wrap),
            ellipsis: Some(self.ellipsis_mode),
            text_overflow: Some(self.text_overflow),
        }
    }

    fn get_selection_config(&self) -> v1::SelectionConfig {
        v1::SelectionConfig {
            mode: Some(self.selection.mode),
            focus_border: Some(self.selection.focus_border),
            visibility: Some(self.selection.selection_visibility),
            allow: Some(self.allow_selection),
            header_click_select: Some(self.header_click_select),
            style: Some(self.selection.selection_style.to_proto()),
            hover: Some(v1::HoverConfig {
                row: Some(self.selection.hover_mode & HOVER_ROW != 0),
                column: Some(self.selection.hover_mode & HOVER_COLUMN != 0),
                cell: Some(self.selection.hover_mode & HOVER_CELL != 0),
                row_style: Some(self.selection.hover_row_style.to_proto()),
                column_style: Some(self.selection.hover_column_style.to_proto()),
                cell_style: Some(self.selection.hover_cell_style.to_proto()),
            }),
            indicator_row_style: self
                .selection
                .indicator_row_style
                .as_ref()
                .map(|s| s.to_proto()),
            indicator_col_style: self
                .selection
                .indicator_col_style
                .as_ref()
                .map(|s| s.to_proto()),
        }
    }

    fn get_edit_config(&self) -> v1::EditConfig {
        v1::EditConfig {
            trigger: Some(self.edit_trigger_mode),
            tab_behavior: Some(self.tab_behavior),
            dropdown_trigger: Some(self.dropdown_trigger),
            dropdown_search: Some(self.dropdown_search),
            max_length: Some(self.edit_max_length),
            mask: Some(self.edit_mask.clone()),
            host_key_dispatch: Some(self.host_key_dispatch),
            host_pointer_dispatch: Some(self.host_pointer_dispatch),
        }
    }

    fn get_scroll_config(&self) -> v1::ScrollConfig {
        v1::ScrollConfig {
            scrollbars: Some(self.scroll_bars),
            scroll_track: Some(self.scroll_track),
            scroll_tips: Some(self.scroll_tips),
            fling_enabled: Some(self.fling_enabled),
            fling_impulse_gain: Some(self.fling_impulse_gain),
            fling_friction: Some(self.fling_friction),
            pinch_zoom_enabled: Some(self.pinch_zoom_enabled),
            fast_scroll: Some(self.fast_scroll_enabled),
        }
    }

    fn get_outline_config(&self) -> v1::OutlineConfig {
        v1::OutlineConfig {
            tree_indicator: Some(self.outline.tree_indicator),
            tree_column: Some(self.outline.tree_column),
            tree_color: Some(self.style.tree_color),
            group_total_position: Some(self.outline.group_total_position),
            multi_totals: Some(self.outline.multi_totals),
        }
    }

    fn get_span_config(&self) -> v1::SpanConfig {
        v1::SpanConfig {
            cell_span: Some(self.span.mode),
            cell_span_fixed: Some(self.span.mode_fixed),
            cell_span_compare: Some(self.span.span_compare),
            group_span_compare: None,
        }
    }

    fn get_interaction_config(&self) -> v1::InteractionConfig {
        let (resize_columns, resize_rows, resize_uniform) =
            decode_resize_policy(self.allow_user_resizing);
        let (freeze_columns, freeze_rows) = decode_freeze_policy(self.allow_user_freezing);
        v1::InteractionConfig {
            resize: Some(v1::ResizePolicy {
                columns: Some(resize_columns),
                rows: Some(resize_rows),
                uniform: Some(resize_uniform),
            }),
            freeze: Some(v1::FreezePolicy {
                columns: Some(freeze_columns),
                rows: Some(freeze_rows),
            }),
            type_ahead: Some(self.type_ahead_mode),
            type_ahead_delay: Some(self.type_ahead_delay),
            auto_size_mouse: Some(self.auto_size_mouse),
            auto_size_mode: Some(self.auto_size_mode),
            auto_resize: Some(self.auto_resize),
            drag_mode: Some(self.drag.drag_mode),
            drop_mode: Some(self.drag.drop_mode),
            header_features: Some(v1::HeaderFeatures {
                sort: Some(self.header_features & 1 != 0),
                reorder: Some(self.header_features & 2 != 0),
                chooser: Some(self.header_features & 4 != 0),
            }),
        }
    }

    fn get_render_config(&self) -> v1::RenderConfig {
        v1::RenderConfig {
            renderer_mode: Some(self.renderer_mode),
            debug_overlay: Some(self.debug_overlay),
            animation_enabled: Some(self.animation.enabled),
            animation_duration_ms: Some(self.animation.duration_ms),
            text_layout_cache_cap: Some(self.text_layout_cache_cap.min(i32::MAX as usize) as i32),
            present_mode: Some(self.present_mode),
            frame_pacing_mode: Some(self.frame_pacing_mode),
            target_frame_rate_hz: Some(self.target_frame_rate_hz),
            render_layer_mask: Some(self.render_layer_mask as i64),
        }
    }

    fn get_indicator_bands_config(&self) -> v1::IndicatorsConfig {
        v1::IndicatorsConfig {
            row_start: Some(row_indicator_to_proto(&self.indicator_bands.row_start)),
            row_end: Some(row_indicator_to_proto(&self.indicator_bands.row_end)),
            col_top: Some(col_indicator_to_proto(&self.indicator_bands.col_top)),
            col_bottom: Some(col_indicator_to_proto(&self.indicator_bands.col_bottom)),
            corner_top_start: Some(corner_indicator_to_proto(
                &self.indicator_bands.corner_top_start,
            )),
            corner_top_end: Some(corner_indicator_to_proto(
                &self.indicator_bands.corner_top_end,
            )),
            corner_bottom_start: Some(corner_indicator_to_proto(
                &self.indicator_bands.corner_bottom_start,
            )),
            corner_bottom_end: Some(corner_indicator_to_proto(
                &self.indicator_bands.corner_bottom_end,
            )),
        }
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Batch column/row definitions
    // ═══════════════════════════════════════════════════════════════════════

    /// Batch-set column properties. Only set (Some) fields per entry are applied.
    pub fn define_columns(&mut self, defs: &[v1::ColumnDef]) {
        for def in defs {
            let idx = def.index;
            if idx < 0 || idx >= self.cols {
                continue;
            }
            let col = idx as usize;

            // Width
            if let Some(w) = def.width {
                self.set_col_width(idx, w);
            }
            if let Some(w) = def.min_width {
                if col < self.columns.len() {
                    self.columns[col].width_min = w;
                }
                self.col_width_min.insert(idx, w);
            }
            if let Some(w) = def.max_width {
                if col < self.columns.len() {
                    self.columns[col].width_max = w;
                }
                self.col_width_max.insert(idx, w);
            }

            if col < self.columns.len() {
                let grid_cell_padding = self.style.cell_padding;
                let grid_fixed_padding = self.style.fixed_cell_padding;
                let mut sticky_to_apply: Option<i32> = None;
                let cp = &mut self.columns[col];
                if let Some(v) = &def.caption {
                    cp.caption = v.clone();
                }
                if let Some(v) = def.align {
                    cp.alignment = v;
                }
                if let Some(v) = def.fixed_align {
                    cp.fixed_alignment = v;
                }
                if let Some(v) = def.data_type {
                    cp.data_type = v;
                }
                if let Some(v) = &def.format {
                    cp.format = v.clone();
                }
                if let Some(v) = &def.key {
                    cp.key = v.clone();
                }
                if def.sort_order.is_some() || def.sort_type.is_some() {
                    cp.sort_order = merge_sort_spec(cp.sort_order, def.sort_order, def.sort_type);
                    cp.sort_defined = true;
                }
                if let Some(v) = &def.dropdown_items {
                    cp.dropdown_items = v.clone();
                }
                if let Some(v) = &def.edit_mask {
                    cp.edit_mask = v.clone();
                }
                if let Some(v) = def.indent {
                    cp.indent = v;
                }
                if let Some(v) = def.hidden {
                    cp.hidden = v;
                    if v {
                        self.cols_hidden.insert(idx);
                    } else {
                        self.cols_hidden.remove(&idx);
                    }
                }
                if let Some(v) = def.span {
                    cp.span = v;
                    self.span.span_cols.insert(idx, v);
                }
                if !def.image_list.is_empty() {
                    cp.image_list = def.image_list.iter().map(|img| img.data.clone()).collect();
                }
                if let Some(v) = &def.data {
                    cp.user_data = if v.is_empty() { None } else { Some(v.clone()) };
                }
                if let Some(v) = def.sticky {
                    cp.sticky = v;
                    sticky_to_apply = Some(v);
                }
                if let Some(v) = &def.padding {
                    let base = cp.cell_padding.unwrap_or(grid_cell_padding);
                    cp.cell_padding = Some(apply_padding_patch(base, v));
                }
                if let Some(v) = &def.fixed_padding {
                    let base = cp
                        .fixed_cell_padding
                        .or(cp.cell_padding)
                        .unwrap_or(grid_fixed_padding);
                    cp.fixed_cell_padding = Some(apply_padding_patch(base, v));
                }
                if let Some(v) = def.nullable {
                    cp.nullable = v;
                }
                if let Some(v) = def.coercion_mode {
                    cp.coercion_mode = v;
                }
                if let Some(v) = def.error_mode {
                    cp.error_mode = v;
                }
                if let Some(v) = sticky_to_apply {
                    self.set_col_sticky(idx, v);
                }
            }
        }
        self.layout.invalidate();
        self.mark_dirty();
    }

    /// Batch-set row properties. Only set (Some) fields per entry are applied.
    pub fn define_rows(&mut self, defs: &[v1::RowDef]) {
        for def in defs {
            let idx = def.index;
            if idx < 0 || idx >= self.rows {
                continue;
            }
            if let Some(h) = def.height {
                self.set_row_height(idx, h);
            }
            if let Some(hidden) = def.hidden {
                if hidden {
                    self.rows_hidden.insert(idx);
                } else {
                    self.rows_hidden.remove(&idx);
                }
            }

            // Pin
            if let Some(v) = def.pin {
                self.pin_row(idx, v);
            }

            // Sticky
            if let Some(v) = def.sticky {
                self.set_row_sticky(idx, v);
            }

            // Row props — only touch if at least one field is set.
            let has_props = def.is_subtotal.is_some()
                || def.outline_level.is_some()
                || def.is_collapsed.is_some()
                || def.data.is_some()
                || def.status.is_some()
                || def.span.is_some();
            if has_props {
                let rp = self.row_props.entry(idx).or_default();
                if let Some(v) = def.is_subtotal {
                    rp.is_subtotal = v;
                }
                if let Some(v) = def.outline_level {
                    rp.outline_level = v;
                }
                if let Some(v) = def.is_collapsed {
                    rp.is_collapsed = v;
                }
                if let Some(v) = &def.data {
                    rp.user_data = if v.is_empty() { None } else { Some(v.clone()) };
                }
                if let Some(v) = def.status {
                    rp.status = v;
                }
                if let Some(v) = def.span {
                    rp.span = v;
                    self.span.span_rows.insert(idx, v);
                }
            }
        }
        self.layout.invalidate();
        self.mark_dirty();
    }

    // ═══════════════════════════════════════════════════════════════════════
    // Batch cell updates / reads
    // ═══════════════════════════════════════════════════════════════════════

    fn column_write_policy(
        &self,
        col: i32,
    ) -> (i32, bool, EffectiveCoercionMode, EffectiveWriteErrorMode) {
        let cp = self.columns.get(col as usize);
        let data_type = cp.map_or(v1::ColumnDataType::ColumnDataString as i32, |c| c.data_type);
        let nullable = cp.map_or(true, |c| c.nullable);
        let coercion_mode = cp.map_or(0, |c| c.coercion_mode);
        let error_mode = cp.map_or(0, |c| c.error_mode);
        (
            normalize_column_data_type(data_type),
            nullable,
            effective_coercion_mode(coercion_mode),
            effective_error_mode(error_mode),
        )
    }

    fn coerce_value_for_column(
        &self,
        expected: i32,
        mode: EffectiveCoercionMode,
        inbound: &v1::cell_value::Value,
    ) -> Result<CellValueData, String> {
        let parse_number = |raw: &str| {
            raw.trim()
                .parse::<f64>()
                .map_err(|_| format!("Could not parse '{}' as Number", raw))
        };
        let parse_bool = |raw: &str| {
            parse_bool_text(raw).ok_or_else(|| format!("Could not parse '{}' as Boolean", raw))
        };
        let parse_date = |raw: &str| {
            parse_timestamp_text(raw).ok_or_else(|| format!("Could not parse '{}' as Date", raw))
        };

        match expected {
            v if v == v1::ColumnDataType::ColumnDataString as i32 => match mode {
                EffectiveCoercionMode::Strict | EffectiveCoercionMode::ParseOnly => match inbound {
                    v1::cell_value::Value::Text(t) => Ok(CellValueData::Text(t.clone())),
                    _ => Err("Expected Text value".to_string()),
                },
                EffectiveCoercionMode::Flexible => match inbound {
                    v1::cell_value::Value::Text(t) => Ok(CellValueData::Text(t.clone())),
                    v1::cell_value::Value::Number(n) => Ok(CellValueData::Text(n.to_string())),
                    v1::cell_value::Value::Flag(b) => Ok(CellValueData::Text(
                        if *b { "true" } else { "false" }.to_string(),
                    )),
                    v1::cell_value::Value::Raw(d) => {
                        Ok(CellValueData::Text(String::from_utf8_lossy(d).to_string()))
                    }
                    v1::cell_value::Value::Timestamp(ts) => Ok(CellValueData::Text(ts.to_string())),
                },
            },
            v if v == v1::ColumnDataType::ColumnDataNumber as i32
                || v == v1::ColumnDataType::ColumnDataCurrency as i32 =>
            {
                match mode {
                    EffectiveCoercionMode::Strict => match inbound {
                        v1::cell_value::Value::Number(n) => Ok(CellValueData::Number(*n)),
                        _ => Err("Expected Number value".to_string()),
                    },
                    EffectiveCoercionMode::ParseOnly => match inbound {
                        v1::cell_value::Value::Text(t) => {
                            parse_number(t).map(CellValueData::Number)
                        }
                        _ => Err("ParseOnly accepts only Text input".to_string()),
                    },
                    EffectiveCoercionMode::Flexible => match inbound {
                        v1::cell_value::Value::Number(n) => Ok(CellValueData::Number(*n)),
                        v1::cell_value::Value::Text(t) => {
                            parse_number(t).map(CellValueData::Number)
                        }
                        v1::cell_value::Value::Flag(b) => {
                            Ok(CellValueData::Number(if *b { 1.0 } else { 0.0 }))
                        }
                        v1::cell_value::Value::Timestamp(ts) => {
                            Ok(CellValueData::Number(*ts as f64))
                        }
                        v1::cell_value::Value::Raw(_) => {
                            Err("Cannot coerce Bytes to Number".to_string())
                        }
                    },
                }
            }
            v if v == v1::ColumnDataType::ColumnDataDate as i32 => match mode {
                EffectiveCoercionMode::Strict => match inbound {
                    v1::cell_value::Value::Timestamp(ts) => Ok(CellValueData::Timestamp(*ts)),
                    _ => Err("Expected Timestamp value".to_string()),
                },
                EffectiveCoercionMode::ParseOnly => match inbound {
                    v1::cell_value::Value::Text(t) => parse_date(t).map(CellValueData::Timestamp),
                    _ => Err("ParseOnly accepts only Text input".to_string()),
                },
                EffectiveCoercionMode::Flexible => match inbound {
                    v1::cell_value::Value::Timestamp(ts) => Ok(CellValueData::Timestamp(*ts)),
                    v1::cell_value::Value::Number(n) if n.is_finite() => {
                        Ok(CellValueData::Timestamp(*n as i64))
                    }
                    v1::cell_value::Value::Text(t) => parse_date(t).map(CellValueData::Timestamp),
                    v1::cell_value::Value::Flag(_) => {
                        Err("Cannot coerce Boolean to Date".to_string())
                    }
                    v1::cell_value::Value::Raw(_) => Err("Cannot coerce Bytes to Date".to_string()),
                    v1::cell_value::Value::Number(_) => {
                        Err("Cannot coerce non-finite Number to Date".to_string())
                    }
                },
            },
            v if v == v1::ColumnDataType::ColumnDataBoolean as i32 => match mode {
                EffectiveCoercionMode::Strict => match inbound {
                    v1::cell_value::Value::Flag(b) => Ok(CellValueData::Bool(*b)),
                    _ => Err("Expected Boolean value".to_string()),
                },
                EffectiveCoercionMode::ParseOnly => match inbound {
                    v1::cell_value::Value::Text(t) => parse_bool(t).map(CellValueData::Bool),
                    _ => Err("ParseOnly accepts only Text input".to_string()),
                },
                EffectiveCoercionMode::Flexible => match inbound {
                    v1::cell_value::Value::Flag(b) => Ok(CellValueData::Bool(*b)),
                    v1::cell_value::Value::Text(t) => parse_bool(t).map(CellValueData::Bool),
                    v1::cell_value::Value::Number(n) => Ok(CellValueData::Bool(*n != 0.0)),
                    v1::cell_value::Value::Timestamp(ts) => Ok(CellValueData::Bool(*ts != 0)),
                    v1::cell_value::Value::Raw(_) => {
                        Err("Cannot coerce Bytes to Boolean".to_string())
                    }
                },
            },
            _ => Err("Unsupported column data type".to_string()),
        }
    }

    fn build_violation(
        &self,
        row: i32,
        col: i32,
        expected: i32,
        actual: &v1::CellValue,
        reason: String,
    ) -> v1::TypeViolation {
        v1::TypeViolation {
            row,
            col,
            expected,
            actual: Some(actual.clone()),
            reason,
        }
    }

    fn plan_value_write(&self, row: i32, col: i32, incoming: &v1::CellValue) -> ValueDecision {
        let (expected, nullable, coercion_mode, error_mode) = self.column_write_policy(col);

        let apply_error_policy = |reason: String,
                                  nullable: bool,
                                  error_mode: EffectiveWriteErrorMode|
         -> ValueDecision {
            let violation = self.build_violation(row, col, expected, incoming, reason);
            match error_mode {
                EffectiveWriteErrorMode::Reject => ValueDecision {
                    plan: PlannedCellValueWrite::Skip,
                    violation: Some(violation),
                    hard_reject: true,
                },
                EffectiveWriteErrorMode::SetNull => {
                    if nullable {
                        ValueDecision {
                            plan: PlannedCellValueWrite::SetNull,
                            violation: Some(violation),
                            hard_reject: false,
                        }
                    } else {
                        ValueDecision {
                            plan: PlannedCellValueWrite::Skip,
                            violation: Some(
                                self.build_violation(
                                    row,
                                    col,
                                    expected,
                                    incoming,
                                    "WriteErrorMode=SET_NULL is invalid when nullable=false"
                                        .to_string(),
                                ),
                            ),
                            hard_reject: true,
                        }
                    }
                }
                EffectiveWriteErrorMode::Skip => ValueDecision {
                    plan: PlannedCellValueWrite::Skip,
                    violation: Some(violation),
                    hard_reject: false,
                },
            }
        };

        match incoming.value.as_ref() {
            None => {
                if nullable {
                    ValueDecision {
                        plan: PlannedCellValueWrite::SetNull,
                        violation: None,
                        hard_reject: false,
                    }
                } else {
                    apply_error_policy(
                        "Null is not allowed for this column".to_string(),
                        nullable,
                        error_mode,
                    )
                }
            }
            Some(value) => match self.coerce_value_for_column(expected, coercion_mode, value) {
                Ok(v) => ValueDecision {
                    plan: PlannedCellValueWrite::Write {
                        text: cell_value_to_text(&v),
                        value: v,
                    },
                    violation: None,
                    hard_reject: false,
                },
                Err(reason) => apply_error_policy(reason, nullable, error_mode),
            },
        }
    }

    fn plan_batch_write(
        &self,
        updates: &[v1::CellUpdate],
        row_limit: i32,
        col_limit: i32,
    ) -> PlannedBatchWrite {
        let mut entries = Vec::with_capacity(updates.len());
        let mut violations = Vec::new();
        let mut written_count = 0i32;
        let mut rejected_count = 0i32;
        let mut has_hard_reject = false;

        for update in updates {
            let row = update.row;
            let col = update.col;
            let in_bounds = row >= 0 && row < row_limit && col >= 0 && col < col_limit;
            let value_plan = if let Some(incoming) = &update.value {
                let decision = if in_bounds {
                    self.plan_value_write(row, col, incoming)
                } else {
                    ValueDecision {
                        plan: PlannedCellValueWrite::Skip,
                        violation: Some(self.build_violation(
                            row,
                            col,
                            v1::ColumnDataType::ColumnDataString as i32,
                            incoming,
                            "Cell out of bounds".to_string(),
                        )),
                        hard_reject: true,
                    }
                };
                if let Some(v) = decision.violation {
                    violations.push(v);
                }
                if decision.hard_reject {
                    has_hard_reject = true;
                }
                match decision.plan {
                    PlannedCellValueWrite::Write { .. } | PlannedCellValueWrite::SetNull => {
                        written_count += 1
                    }
                    PlannedCellValueWrite::Skip => rejected_count += 1,
                    PlannedCellValueWrite::None => {}
                }
                decision.plan
            } else {
                PlannedCellValueWrite::None
            };
            entries.push(PlannedCellUpdate {
                update: update.clone(),
                value_plan,
                in_bounds,
            });
        }

        PlannedBatchWrite {
            entries,
            violations,
            written_count,
            rejected_count,
            has_hard_reject,
        }
    }

    fn apply_value_plan(&mut self, row: i32, col: i32, plan: &PlannedCellValueWrite) {
        match plan {
            PlannedCellValueWrite::None | PlannedCellValueWrite::Skip => {}
            PlannedCellValueWrite::SetNull => {
                self.cells.set_value(row, col, CellValueData::Empty);
                self.cells.set_text(row, col, String::new());
            }
            PlannedCellValueWrite::Write { value, text } => {
                self.cells.set_value(row, col, value.clone());
                self.cells.set_text(row, col, text.clone());
            }
        }
    }

    fn apply_non_value_update(&mut self, u: &v1::CellUpdate) {
        let row = u.row;
        let col = u.col;

        if let Some(s) = &u.style {
            let patch = v2_cell_style_to_engine(s);
            if patch.is_empty() {
                self.cell_styles.remove(&(row, col));
            } else {
                self.cell_styles
                    .entry((row, col))
                    .and_modify(|existing| existing.merge_from(&patch))
                    .or_insert(patch);
            }
        }

        if let Some(c) = u.checked {
            let cell = self.cells.get_mut(row, col);
            cell.extra_mut().checked = c;
        }

        if let Some(img) = &u.picture {
            let cell = self.cells.get_mut(row, col);
            let extra = cell.extra_mut();
            if img.data.is_empty() {
                extra.picture = None;
                extra.picture_format = String::new();
            } else {
                extra.picture = Some(img.data.clone());
                extra.picture_format = img.format.clone();
            }
        }

        if let Some(pa) = u.picture_align {
            let cell = self.cells.get_mut(row, col);
            cell.extra_mut().picture_alignment = pa;
        }

        if let Some(img) = &u.button_picture {
            let cell = self.cells.get_mut(row, col);
            let extra = cell.extra_mut();
            if img.data.is_empty() {
                extra.button_picture = None;
                extra.button_picture_format = String::new();
            } else {
                extra.button_picture = Some(img.data.clone());
                extra.button_picture_format = img.format.clone();
            }
        }

        if let Some(cl) = &u.dropdown_items {
            let cell = self.cells.get_mut(row, col);
            cell.extra_mut().dropdown_items = cl.clone();
        }

        if u.sticky_row.is_some() || u.sticky_col.is_some() {
            let sr = u.sticky_row.unwrap_or(0);
            let sc = u.sticky_col.unwrap_or(0);
            self.set_cell_sticky(row, col, sr, sc);
        }
    }

    /// Batch-set cell values, styles, checked state, and pictures with
    /// strict typing + per-cell write feedback.
    pub fn write_cells(&mut self, updates: &[v1::CellUpdate], atomic: bool) -> v1::WriteResult {
        let plan = self.plan_batch_write(updates, self.rows, self.cols);
        if atomic && plan.has_hard_reject {
            return v1::WriteResult {
                written_count: 0,
                rejected_count: plan.rejected_count,
                violations: plan.violations,
            };
        }

        let mut applied_any = false;
        for entry in &plan.entries {
            if !entry.in_bounds {
                continue;
            }
            self.apply_value_plan(entry.update.row, entry.update.col, &entry.value_plan);
            if matches!(
                entry.value_plan,
                PlannedCellValueWrite::Write { .. } | PlannedCellValueWrite::SetNull
            ) {
                applied_any = true;
            }
            self.apply_non_value_update(&entry.update);
            if entry.update.style.is_some()
                || entry.update.checked.is_some()
                || entry.update.picture.is_some()
                || entry.update.picture_align.is_some()
                || entry.update.button_picture.is_some()
                || entry.update.dropdown_items.is_some()
                || entry.update.sticky_row.is_some()
                || entry.update.sticky_col.is_some()
            {
                applied_any = true;
            }
        }
        if applied_any {
            self.mark_dirty();
        }

        v1::WriteResult {
            written_count: plan.written_count,
            rejected_count: plan.rejected_count,
            violations: plan.violations,
        }
    }

    /// Legacy compatibility wrapper for callers that ignore write feedback.
    pub fn update_cells(&mut self, updates: &[v1::CellUpdate]) {
        let _ = self.write_cells(updates, false);
    }

    /// Typed bulk ingestion path used by `LoadTable`.
    pub fn load_table(
        &mut self,
        rows: i32,
        cols: i32,
        values: &[v1::CellValue],
        atomic: bool,
    ) -> v1::WriteResult {
        let rows = rows.max(1);
        let cols = cols.max(1);
        let max = (rows as usize).saturating_mul(cols as usize);
        let updates: Vec<v1::CellUpdate> = values
            .iter()
            .take(max)
            .enumerate()
            .map(|(idx, value)| {
                let idx = idx as i32;
                v1::CellUpdate {
                    row: idx / cols,
                    col: idx % cols,
                    value: Some(value.clone()),
                    style: None,
                    checked: None,
                    picture: None,
                    picture_align: None,
                    button_picture: None,
                    dropdown_items: None,
                    sticky_row: None,
                    sticky_col: None,
                }
            })
            .collect();

        let plan = self.plan_batch_write(&updates, rows, cols);
        if atomic && plan.has_hard_reject {
            return v1::WriteResult {
                written_count: 0,
                rejected_count: plan.rejected_count,
                violations: plan.violations,
            };
        }

        self.set_rows(rows);
        self.set_cols(cols);
        self.cells.clear_all();
        for entry in &plan.entries {
            if entry.in_bounds {
                self.apply_value_plan(entry.update.row, entry.update.col, &entry.value_plan);
            }
        }
        self.mark_dirty();

        v1::WriteResult {
            written_count: plan.written_count,
            rejected_count: plan.rejected_count,
            violations: plan.violations,
        }
    }

    /// Export effective column definitions as schema.
    pub fn get_schema(&self, grid_id: i64) -> v1::DefineColumnsRequest {
        let mut columns = Vec::with_capacity(self.cols.max(0) as usize);
        for col in 0..self.cols {
            let cp = self
                .columns
                .get(col as usize)
                .cloned()
                .unwrap_or_else(crate::column::ColumnProps::default);
            let (sort_order, sort_type) = if cp.sort_defined {
                decode_sort_spec(cp.sort_order)
            } else {
                (None, None)
            };
            columns.push(v1::ColumnDef {
                index: col,
                width: Some(self.get_col_width(col)),
                min_width: if cp.width_min != 0 {
                    Some(cp.width_min)
                } else {
                    None
                },
                max_width: if cp.width_max != 0 {
                    Some(cp.width_max)
                } else {
                    None
                },
                caption: if cp.caption.is_empty() {
                    None
                } else {
                    Some(cp.caption)
                },
                align: Some(cp.alignment),
                fixed_align: Some(cp.fixed_alignment),
                data_type: Some(normalize_column_data_type(cp.data_type)),
                format: if cp.format.is_empty() {
                    None
                } else {
                    Some(cp.format)
                },
                key: if cp.key.is_empty() {
                    None
                } else {
                    Some(cp.key)
                },
                sort_order,
                sort_type,
                dropdown_items: if cp.dropdown_items.is_empty() {
                    None
                } else {
                    Some(cp.dropdown_items)
                },
                edit_mask: if cp.edit_mask.is_empty() {
                    None
                } else {
                    Some(cp.edit_mask)
                },
                indent: if cp.indent != 0 {
                    Some(cp.indent)
                } else {
                    None
                },
                hidden: Some(cp.hidden),
                span: Some(cp.span),
                image_list: cp
                    .image_list
                    .into_iter()
                    .map(|data| v1::ImageData {
                        data,
                        format: String::new(),
                    })
                    .collect(),
                data: cp.user_data,
                sticky: if cp.sticky != 0 {
                    Some(cp.sticky)
                } else {
                    None
                },
                padding: cp.cell_padding.map(engine_padding_to_v1),
                fixed_padding: cp.fixed_cell_padding.map(engine_padding_to_v1),
                nullable: Some(cp.nullable),
                coercion_mode: if cp.coercion_mode != 0 {
                    Some(cp.coercion_mode)
                } else {
                    None
                },
                error_mode: if cp.error_mode != 0 {
                    Some(cp.error_mode)
                } else {
                    None
                },
            });
        }
        v1::DefineColumnsRequest { grid_id, columns }
    }

    /// Read cell data for a range.
    pub fn get_cells(
        &self,
        row1: i32,
        col1: i32,
        row2: i32,
        col2: i32,
        include_style: bool,
        include_checked: bool,
        include_typed: bool,
    ) -> Vec<v1::CellData> {
        let r1 = row1.max(0).min(self.rows - 1);
        let r2 = row2.max(0).min(self.rows - 1);
        let c1 = col1.max(0).min(self.cols - 1);
        let c2 = col2.max(0).min(self.cols - 1);

        let mut result = Vec::new();
        for row in r1..=r2 {
            for col in c1..=c2 {
                let text = self.cells.get_text(row, col).to_string();
                let typed_value = if include_typed {
                    match self.cells.get_value(row, col) {
                        CellValueData::Text(v) => Some(v1::CellValue {
                            value: Some(v1::cell_value::Value::Text(v.clone())),
                        }),
                        CellValueData::Number(v) => Some(v1::CellValue {
                            value: Some(v1::cell_value::Value::Number(*v)),
                        }),
                        CellValueData::Bool(v) => Some(v1::CellValue {
                            value: Some(v1::cell_value::Value::Flag(*v)),
                        }),
                        CellValueData::Bytes(v) => Some(v1::CellValue {
                            value: Some(v1::cell_value::Value::Raw(v.clone())),
                        }),
                        CellValueData::Timestamp(v) => Some(v1::CellValue {
                            value: Some(v1::cell_value::Value::Timestamp(*v)),
                        }),
                        CellValueData::Empty => {
                            if text.is_empty() {
                                None
                            } else {
                                Some(v1::CellValue {
                                    value: Some(v1::cell_value::Value::Text(text.clone())),
                                })
                            }
                        }
                    }
                } else if text.is_empty() {
                    None
                } else {
                    Some(v1::CellValue {
                        value: Some(v1::cell_value::Value::Text(text.clone())),
                    })
                };

                let style = if include_style {
                    self.cell_styles
                        .get(&(row, col))
                        .map(engine_cell_style_to_v2)
                } else {
                    None
                };

                let checked = if include_checked {
                    self.cells.get(row, col).map_or(0, |cd| cd.checked())
                } else {
                    0
                };

                result.push(v1::CellData {
                    row,
                    col,
                    value: typed_value,
                    style,
                    checked,
                });
            }
        }
        result
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Conversion helpers: proto ↔ engine types
// ═══════════════════════════════════════════════════════════════════════════

pub fn v2_cell_style_to_engine(s: &v1::CellStyle) -> style::CellStylePatch {
    let (
        border,
        border_color,
        border_top,
        border_top_color,
        border_right,
        border_right_color,
        border_bottom,
        border_bottom_color,
        border_left,
        border_left_color,
    ) = style::proto_borders_to_parts(s.borders.as_ref());
    let mut result = style::CellStylePatch {
        back_color: s.background,
        fore_color: s.foreground,
        alignment: s.align,
        text_effect: s.text_effect,
        font_name: None,
        font_size: None,
        font_bold: None,
        font_italic: None,
        font_underline: None,
        font_strikethrough: None,
        font_width: None,
        border,
        border_color,
        border_top,
        border_right,
        border_bottom,
        border_left,
        border_top_color,
        border_right_color,
        border_bottom_color,
        border_left_color,
        padding: s
            .padding
            .as_ref()
            .map(|p| apply_padding_patch(style::Padding::default(), p)),
        shrink_to_fit: s.shrink_to_fit,
    };
    if let Some(font) = &s.font {
        apply_cell_style_font_patch(&mut result, font);
    }
    result
}

pub fn engine_cell_style_to_v2(s: &style::CellStylePatch) -> v1::CellStyle {
    v1::CellStyle {
        background: s.back_color,
        foreground: s.fore_color,
        align: s.alignment,
        font: cell_style_font_to_v1(s),
        padding: s.padding.map(engine_padding_to_v1),
        borders: style::parts_to_proto_borders(
            s.border,
            s.border_color,
            s.border_top,
            s.border_top_color,
            s.border_right,
            s.border_right_color,
            s.border_bottom,
            s.border_bottom_color,
            s.border_left,
            s.border_left_color,
        ),
        text_effect: s.text_effect,
        progress: None,
        progress_color: None,
        shrink_to_fit: s.shrink_to_fit,
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Tests
// ═══════════════════════════════════════════════════════════════════════════

#[cfg(test)]
mod tests {
    use super::*;
    use crate::grid::VolvoxGrid;

    fn test_grid() -> VolvoxGrid {
        VolvoxGrid::new(1, 800, 600, 10, 5, 1, 1)
    }

    #[test]
    fn apply_config_partial_layout() {
        let mut grid = test_grid();
        assert_eq!(grid.rows, 10);
        assert_eq!(grid.cols, 5);

        let config = v1::GridConfig {
            layout: Some(v1::LayoutConfig {
                rows: Some(20),
                ..Default::default()
            }),
            ..Default::default()
        };
        grid.apply_config(&config);

        assert_eq!(grid.rows, 20);
        assert_eq!(grid.cols, 5); // unchanged
    }

    #[test]
    fn apply_config_partial_style() {
        let mut grid = test_grid();
        let old_back = grid.style.back_color;

        let config = v1::GridConfig {
            style: Some(v1::StyleConfig {
                background: Some(0xFF112233),
                ..Default::default()
            }),
            ..Default::default()
        };
        grid.apply_config(&config);

        assert_eq!(grid.style.back_color, 0xFF112233);
        assert_ne!(old_back, grid.style.back_color);
        assert_eq!(grid.style.fore_color, 0xFF000000); // unchanged
    }

    #[test]
    fn get_config_roundtrip() {
        let mut grid = test_grid();
        grid.style.back_color = 0xAABBCCDD;
        grid.edit_trigger_mode = 2;
        grid.scroll_bars = 3;

        let config = grid.get_config();

        assert_eq!(config.style.as_ref().unwrap().background, Some(0xAABBCCDD));
        assert_eq!(config.editing.as_ref().unwrap().trigger, Some(2));
        assert_eq!(config.scrolling.as_ref().unwrap().scrollbars, Some(3));
    }

    #[test]
    fn disabling_fling_stops_active_fling() {
        let mut grid = test_grid();
        grid.fling_enabled = true;
        grid.scroll.add_fling_impulse(640.0, 480.0);
        assert!(grid.scroll.fling_active);
        assert!(grid.scroll.fling_vx.abs() > 0.0 || grid.scroll.fling_vy.abs() > 0.0);

        let config = v1::GridConfig {
            scrolling: Some(v1::ScrollConfig {
                fling_enabled: Some(false),
                ..Default::default()
            }),
            ..Default::default()
        };
        grid.apply_config(&config);

        assert!(!grid.fling_enabled);
        assert!(!grid.scroll.fling_active);
        assert_eq!(grid.scroll.fling_vx, 0.0);
        assert_eq!(grid.scroll.fling_vy, 0.0);
    }

    #[test]
    fn define_columns_batch() {
        let mut grid = test_grid();
        let defs = vec![
            v1::ColumnDef {
                index: 0,
                width: Some(100),
                align: Some(4),
                hidden: Some(false),
                ..Default::default()
            },
            v1::ColumnDef {
                index: 2,
                width: Some(200),
                key: Some("revenue".to_string()),
                ..Default::default()
            },
        ];
        grid.define_columns(&defs);

        assert_eq!(*grid.col_widths.get(&0).unwrap(), 100);
        assert_eq!(grid.columns[0].alignment, 4);
        assert_eq!(*grid.col_widths.get(&2).unwrap(), 200);
        assert_eq!(grid.columns[2].key, "revenue");
    }

    #[test]
    fn style_padding_partial_update() {
        let mut grid = test_grid();
        assert_eq!(grid.style.cell_padding.left, 3);
        assert_eq!(grid.style.cell_padding.right, 3);

        let config = v1::GridConfig {
            style: Some(v1::StyleConfig {
                cell_padding: Some(v1::Padding {
                    left: Some(12),
                    ..Default::default()
                }),
                ..Default::default()
            }),
            ..Default::default()
        };
        grid.apply_config(&config);

        assert_eq!(grid.style.cell_padding.left, 12);
        assert_eq!(grid.style.cell_padding.top, 0);
        assert_eq!(grid.style.cell_padding.right, 3);
        assert_eq!(grid.style.cell_padding.bottom, 0);
    }

    #[test]
    fn define_columns_padding_override() {
        let mut grid = test_grid();
        let defs = vec![v1::ColumnDef {
            index: 1,
            padding: Some(v1::Padding {
                left: Some(7),
                right: Some(9),
                ..Default::default()
            }),
            fixed_padding: Some(v1::Padding {
                left: Some(2),
                right: Some(2),
                ..Default::default()
            }),
            ..Default::default()
        }];
        grid.define_columns(&defs);

        let cp = &grid.columns[1];
        let body = cp.cell_padding.unwrap();
        let fixed = cp.fixed_cell_padding.unwrap();
        assert_eq!(body.left, 7);
        assert_eq!(body.right, 9);
        assert_eq!(fixed.left, 2);
        assert_eq!(fixed.right, 2);
    }

    #[test]
    fn define_rows_batch() {
        let mut grid = test_grid();
        let defs = vec![v1::RowDef {
            index: 3,
            height: Some(40),
            is_subtotal: Some(true),
            outline_level: Some(1),
            ..Default::default()
        }];
        grid.define_rows(&defs);

        assert_eq!(*grid.row_heights.get(&3).unwrap(), 40);
        let rp = grid.row_props.get(&3).unwrap();
        assert!(rp.is_subtotal);
        assert_eq!(rp.outline_level, 1);
    }

    #[test]
    fn update_cells_batch() {
        let mut grid = test_grid();
        let updates = vec![
            v1::CellUpdate {
                row: 1,
                col: 1,
                value: Some(v1::CellValue {
                    value: Some(v1::cell_value::Value::Text("Hello".to_string())),
                }),
                ..Default::default()
            },
            v1::CellUpdate {
                row: 2,
                col: 2,
                value: Some(v1::CellValue {
                    value: Some(v1::cell_value::Value::Text("World".to_string())),
                }),
                style: Some(v1::CellStyle {
                    background: Some(0xFF0000FF),
                    ..Default::default()
                }),
                ..Default::default()
            },
        ];
        grid.update_cells(&updates);

        assert_eq!(grid.cells.get_text(1, 1), "Hello");
        assert_eq!(grid.cells.get_text(2, 2), "World");
        assert_eq!(
            grid.cell_styles.get(&(2, 2)).unwrap().back_color,
            Some(0xFF0000FF)
        );
    }

    #[test]
    fn write_cells_strict_rejects_type_mismatch() {
        let mut grid = test_grid();
        grid.define_columns(&[v1::ColumnDef {
            index: 0,
            data_type: Some(v1::ColumnDataType::ColumnDataNumber as i32),
            coercion_mode: Some(v1::CoercionMode::CoercionStrict as i32),
            error_mode: Some(v1::WriteErrorMode::WriteErrorReject as i32),
            ..Default::default()
        }]);

        let result = grid.write_cells(
            &[v1::CellUpdate {
                row: 1,
                col: 0,
                value: Some(v1::CellValue {
                    value: Some(v1::cell_value::Value::Text("abc".to_string())),
                }),
                ..Default::default()
            }],
            false,
        );

        assert_eq!(result.written_count, 0);
        assert_eq!(result.rejected_count, 1);
        assert_eq!(result.violations.len(), 1);
        assert_eq!(grid.cells.get_text(1, 0), "");
    }

    #[test]
    fn write_cells_atomic_rejects_all_on_hard_error() {
        let mut grid = test_grid();
        grid.define_columns(&[v1::ColumnDef {
            index: 0,
            data_type: Some(v1::ColumnDataType::ColumnDataNumber as i32),
            coercion_mode: Some(v1::CoercionMode::CoercionStrict as i32),
            error_mode: Some(v1::WriteErrorMode::WriteErrorReject as i32),
            ..Default::default()
        }]);
        grid.cells.set_text(1, 0, "old".to_string());

        let result = grid.write_cells(
            &[
                v1::CellUpdate {
                    row: 1,
                    col: 0,
                    value: Some(v1::CellValue {
                        value: Some(v1::cell_value::Value::Number(42.0)),
                    }),
                    ..Default::default()
                },
                v1::CellUpdate {
                    row: 2,
                    col: 0,
                    value: Some(v1::CellValue {
                        value: Some(v1::cell_value::Value::Text("bad".to_string())),
                    }),
                    ..Default::default()
                },
            ],
            true,
        );

        assert_eq!(result.written_count, 0);
        assert_eq!(result.rejected_count, 1);
        assert_eq!(grid.cells.get_text(1, 0), "old");
    }

    #[test]
    fn load_table_supports_timestamp_values() {
        let mut grid = test_grid();
        grid.define_columns(&[v1::ColumnDef {
            index: 0,
            data_type: Some(v1::ColumnDataType::ColumnDataDate as i32),
            coercion_mode: Some(v1::CoercionMode::CoercionStrict as i32),
            ..Default::default()
        }]);

        let ts = 1_700_000_000_000i64;
        let result = grid.load_table(
            1,
            1,
            &[v1::CellValue {
                value: Some(v1::cell_value::Value::Timestamp(ts)),
            }],
            true,
        );
        assert_eq!(result.written_count, 1);
        assert_eq!(result.rejected_count, 0);

        let cells = grid.get_cells(0, 0, 0, 0, false, false, true);
        assert!(matches!(
            cells.first().and_then(|c| c.value.clone()),
            Some(v1::CellValue {
                value: Some(v1::cell_value::Value::Timestamp(v))
            }) if v == ts
        ));
    }

    #[test]
    fn get_cells_range() {
        let mut grid = test_grid();
        grid.cells.set_text(1, 1, "A".to_string());
        grid.cells.set_text(1, 2, "B".to_string());
        grid.cells.set_text(2, 1, "C".to_string());

        let cells = grid.get_cells(1, 1, 2, 2, false, false, false);
        assert_eq!(cells.len(), 4); // 2x2 range

        let a = cells.iter().find(|c| c.row == 1 && c.col == 1).unwrap();
        assert!(matches!(
            &a.value,
            Some(v1::CellValue {
                value: Some(v1::cell_value::Value::Text(t))
            }) if t == "A"
        ));
    }

    #[test]
    fn cell_style_roundtrip() {
        let engine_style = style::CellStylePatch {
            back_color: Some(0xFF112233),
            font_bold: Some(true),
            border: Some(1),
            padding: Some(style::Padding {
                left: 4,
                top: 1,
                right: 5,
                bottom: 2,
            }),
            ..Default::default()
        };
        let v2_style = engine_cell_style_to_v2(&engine_style);
        let back = v2_cell_style_to_engine(&v2_style);
        assert_eq!(back.back_color, Some(0xFF112233));
        assert_eq!(back.font_bold, Some(true));
        assert_eq!(back.border, Some(1));
        let padding = back.padding.unwrap();
        assert_eq!(padding.left, 4);
        assert_eq!(padding.top, 1);
        assert_eq!(padding.right, 5);
        assert_eq!(padding.bottom, 2);
    }

    // ── text_overflow config tests ─────────────────────────────────

    #[test]
    fn text_overflow_defaults_to_false() {
        let grid = test_grid();
        assert!(!grid.text_overflow);
    }

    #[test]
    fn apply_config_sets_text_overflow() {
        let mut grid = test_grid();
        assert!(!grid.text_overflow);

        let config = v1::GridConfig {
            style: Some(v1::StyleConfig {
                text_overflow: Some(true),
                ..Default::default()
            }),
            ..Default::default()
        };
        grid.apply_config(&config);
        assert!(grid.text_overflow);

        // Unset fields leave it unchanged
        let config2 = v1::GridConfig {
            layout: Some(v1::LayoutConfig {
                rows: Some(50),
                ..Default::default()
            }),
            ..Default::default()
        };
        grid.apply_config(&config2);
        assert!(grid.text_overflow); // still true
        assert_eq!(grid.rows, 50);
    }

    #[test]
    fn get_config_returns_text_overflow() {
        let mut grid = test_grid();
        grid.text_overflow = true;
        let config = grid.get_config();
        assert_eq!(config.style.as_ref().unwrap().text_overflow, Some(true));
    }

    #[test]
    fn apply_config_sets_text_layout_cache_cap() {
        let mut grid = test_grid();
        assert_ne!(grid.text_layout_cache_cap, 256);

        let config = v1::GridConfig {
            rendering: Some(v1::RenderConfig {
                text_layout_cache_cap: Some(256),
                ..Default::default()
            }),
            ..Default::default()
        };
        grid.apply_config(&config);
        assert_eq!(grid.text_layout_cache_cap, 256);

        // Negative values are clamped to zero.
        let config2 = v1::GridConfig {
            rendering: Some(v1::RenderConfig {
                text_layout_cache_cap: Some(-1),
                ..Default::default()
            }),
            ..Default::default()
        };
        grid.apply_config(&config2);
        assert_eq!(grid.text_layout_cache_cap, 0);
    }

    #[test]
    fn get_config_returns_text_layout_cache_cap() {
        let mut grid = test_grid();
        grid.text_layout_cache_cap = 1234;
        let config = grid.get_config();
        assert_eq!(
            config.rendering.as_ref().unwrap().text_layout_cache_cap,
            Some(1234)
        );
    }

    #[test]
    fn apply_config_sets_frame_pacing_config() {
        let mut grid = test_grid();
        assert_eq!(grid.frame_pacing_mode, v1::FramePacingMode::Auto as i32);
        assert_eq!(
            grid.target_frame_rate_hz,
            crate::grid::DEFAULT_TARGET_FRAME_RATE_HZ
        );

        let config = v1::GridConfig {
            rendering: Some(v1::RenderConfig {
                frame_pacing_mode: Some(v1::FramePacingMode::Fixed as i32),
                target_frame_rate_hz: Some(120),
                ..Default::default()
            }),
            ..Default::default()
        };
        grid.apply_config(&config);
        assert_eq!(grid.frame_pacing_mode, v1::FramePacingMode::Fixed as i32);
        assert_eq!(grid.target_frame_rate_hz, 120);

        let fallback = v1::GridConfig {
            rendering: Some(v1::RenderConfig {
                target_frame_rate_hz: Some(0),
                ..Default::default()
            }),
            ..Default::default()
        };
        grid.apply_config(&fallback);
        assert_eq!(
            grid.target_frame_rate_hz,
            crate::grid::DEFAULT_TARGET_FRAME_RATE_HZ
        );
    }

    #[test]
    fn get_config_returns_frame_pacing_config() {
        let mut grid = test_grid();
        grid.frame_pacing_mode = v1::FramePacingMode::Platform as i32;
        grid.target_frame_rate_hz = 45;
        let config = grid.get_config();
        let rendering = config.rendering.as_ref().unwrap();
        assert_eq!(
            rendering.frame_pacing_mode,
            Some(v1::FramePacingMode::Platform as i32)
        );
        assert_eq!(rendering.target_frame_rate_hz, Some(45));
    }

    // ── shrink_to_fit style tests ──────────────────────────────────

    #[test]
    fn shrink_to_fit_roundtrip() {
        let engine_style = style::CellStylePatch {
            shrink_to_fit: Some(true),
            ..Default::default()
        };
        let v2 = engine_cell_style_to_v2(&engine_style);
        assert_eq!(v2.shrink_to_fit, Some(true));
        let back = v2_cell_style_to_engine(&v2);
        assert_eq!(back.shrink_to_fit, Some(true));
    }

    #[test]
    fn shrink_to_fit_none_roundtrip() {
        let engine_style = style::CellStylePatch {
            font_bold: Some(true),
            ..Default::default()
        };
        assert!(engine_style.shrink_to_fit.is_none());
        let v2 = engine_cell_style_to_v2(&engine_style);
        assert!(v2.shrink_to_fit.is_none());
        let back = v2_cell_style_to_engine(&v2);
        assert!(back.shrink_to_fit.is_none());
    }

    #[test]
    fn shrink_to_fit_is_empty_and_merge() {
        // is_empty should return false when shrink_to_fit is set
        let s = style::CellStylePatch {
            shrink_to_fit: Some(true),
            ..Default::default()
        };
        assert!(!s.is_empty());

        // is_empty should return true when all fields are None
        let empty = style::CellStylePatch::default();
        assert!(empty.is_empty());

        // merge_from should overwrite shrink_to_fit
        let mut base = style::CellStylePatch::default();
        let patch = style::CellStylePatch {
            shrink_to_fit: Some(true),
            ..Default::default()
        };
        base.merge_from(&patch);
        assert_eq!(base.shrink_to_fit, Some(true));

        // merge_from with None should not overwrite
        let noop = style::CellStylePatch::default();
        base.merge_from(&noop);
        assert_eq!(base.shrink_to_fit, Some(true));
    }

    #[test]
    fn apply_cell_style_shrink_to_fit_via_update_cells() {
        let mut grid = test_grid();
        let updates = vec![v1::CellUpdate {
            row: 1,
            col: 1,
            value: Some(v1::CellValue {
                value: Some(v1::cell_value::Value::Text("Hello".into())),
            }),
            style: Some(v1::CellStyle {
                shrink_to_fit: Some(true),
                ..Default::default()
            }),
            ..Default::default()
        }];
        grid.update_cells(&updates);

        let s = grid.get_cell_style(1, 1);
        assert_eq!(s.shrink_to_fit, Some(true));
    }

    // ── text_overflow + ellipsis interaction ────────────────────────

    #[test]
    fn text_overflow_and_ellipsis_coexist_in_config() {
        let mut grid = test_grid();
        let config = v1::GridConfig {
            style: Some(v1::StyleConfig {
                text_overflow: Some(true),
                ellipsis: Some(1),
                ..Default::default()
            }),
            ..Default::default()
        };
        grid.apply_config(&config);
        assert!(grid.text_overflow);
        assert_eq!(grid.ellipsis_mode, 1);
    }
}
