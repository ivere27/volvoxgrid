//! Batch configuration API.
//!
//! All v1 proto types are accepted directly — prost `optional` fields map to
//! `Option<T>`, giving perfect partial-update semantics. Only set fields are
//! applied; unset fields leave the engine state unchanged.

use crate::cell::CellValueData;
use crate::grid::VolvoxGrid;
use crate::proto::volvoxgrid::v1;
use crate::style;

fn apply_padding_patch(base: style::CellPadding, patch: &v1::CellPadding) -> style::CellPadding {
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

fn engine_padding_to_v1(p: style::CellPadding) -> v1::CellPadding {
    v1::CellPadding {
        left: Some(p.left.max(0)),
        top: Some(p.top.max(0)),
        right: Some(p.right.max(0)),
        bottom: Some(p.bottom.max(0)),
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

fn apply_icon_text_style_patch(target: &mut style::IconTextStyle, patch: &v1::IconTextStyle) {
    if let Some(v) = &patch.font_name {
        let trimmed = v.trim();
        if trimmed.is_empty() {
            target.font_name = None;
            target.font_names.clear();
        } else {
            target.font_name = Some(trimmed.to_string());
            target.font_names.clear();
        }
    }
    if !patch.font_names.is_empty() {
        let names = sanitize_font_names(&patch.font_names);
        target.font_name = names.first().cloned();
        target.font_names = names;
    }
    if let Some(v) = patch.font_size {
        if v.is_finite() && v > 0.0 {
            target.font_size = Some(v.clamp(1.0, 256.0));
        } else {
            target.font_size = None;
        }
    }
    if let Some(v) = patch.font_bold {
        target.font_bold = Some(v);
    }
    if let Some(v) = patch.font_italic {
        target.font_italic = Some(v);
    }
    if let Some(v) = patch.color {
        target.color = Some(v);
    }
}

fn icon_text_style_to_v1(style: &style::IconTextStyle) -> v1::IconTextStyle {
    let font_name = style
        .font_name
        .clone()
        .or_else(|| style.font_names.first().cloned());
    v1::IconTextStyle {
        font_name,
        font_names: style.font_names.clone(),
        font_size: style.font_size,
        font_bold: style.font_bold,
        font_italic: style.font_italic,
        color: style.color,
    }
}

fn apply_icon_layout_patch(target: &mut style::IconLayoutStyle, patch: &v1::IconLayoutStyle) {
    if let Some(v) = patch.align {
        target.align = normalize_icon_align(v);
    }
    if let Some(v) = patch.gap_px {
        target.gap_px = v.max(0);
    }
}

fn icon_layout_to_v1(layout: style::IconLayoutStyle) -> v1::IconLayoutStyle {
    v1::IconLayoutStyle {
        align: Some(normalize_icon_align(layout.align)),
        gap_px: Some(layout.gap_px.max(0)),
    }
}

fn apply_icon_slot_style_patch(
    target: &mut Option<style::IconThemeSlotStyle>,
    patch: &Option<v1::IconThemeSlotStyle>,
    default_layout: style::IconLayoutStyle,
) {
    let Some(patch) = patch else {
        return;
    };
    let slot = target.get_or_insert_with(style::IconThemeSlotStyle::default);
    if let Some(text_style) = &patch.text_style {
        apply_icon_text_style_patch(&mut slot.text_style, text_style);
    }
    if let Some(layout_patch) = &patch.layout {
        let mut layout = slot.layout.unwrap_or(default_layout);
        apply_icon_layout_patch(&mut layout, layout_patch);
        slot.layout = Some(layout);
    }
}

fn icon_slot_style_to_v1(
    slot: &Option<style::IconThemeSlotStyle>,
) -> Option<v1::IconThemeSlotStyle> {
    slot.as_ref().map(|s| v1::IconThemeSlotStyle {
        text_style: Some(icon_text_style_to_v1(&s.text_style)),
        layout: s.layout.map(icon_layout_to_v1),
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
            version: env!("CARGO_PKG_VERSION").to_string(),
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
            self.fixed_rows = fr.max(1).min(self.rows);
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
        if let Some(fs) = &lc.format_string {
            self.format_string = fs.clone();
        }
        if let Some(ww) = lc.word_wrap {
            self.word_wrap = ww;
        }
        if let Some(e) = lc.ellipsis {
            self.ellipsis_mode = e;
        }
        if let Some(to) = lc.text_overflow {
            self.text_overflow = to;
        }
        self.mark_dirty();
    }

    fn apply_style_config(&mut self, sc: &v1::StyleConfig) {
        if let Some(v) = sc.appearance {
            self.style.appearance = v;
        }
        if let Some(v) = sc.back_color {
            self.style.back_color = v;
        }
        if let Some(v) = sc.fore_color {
            self.style.fore_color = v;
        }
        if let Some(v) = sc.back_color_fixed {
            self.style.back_color_fixed = v;
        }
        if let Some(v) = sc.fore_color_fixed {
            self.style.fore_color_fixed = v;
        }
        if let Some(v) = sc.back_color_frozen {
            self.style.back_color_frozen = v;
        }
        if let Some(v) = sc.fore_color_frozen {
            self.style.fore_color_frozen = v;
        }
        if let Some(v) = sc.back_color_sel {
            self.style.back_color_sel = v;
        }
        if let Some(v) = sc.fore_color_sel {
            self.style.fore_color_sel = v;
        }
        if let Some(v) = sc.back_color_bkg {
            self.style.back_color_bkg = v;
        }
        if let Some(v) = sc.back_color_alternate {
            self.style.back_color_alternate = v;
        }
        if let Some(v) = sc.grid_lines {
            self.style.grid_lines = v;
        }
        if let Some(v) = sc.grid_lines_fixed {
            self.style.grid_lines_fixed = v;
        }
        if let Some(v) = sc.grid_color {
            self.style.grid_color = v;
        }
        if let Some(v) = sc.grid_color_fixed {
            self.style.grid_color_fixed = v;
        }
        if let Some(v) = sc.grid_line_width {
            self.style.grid_line_width = v;
        }
        if let Some(v) = sc.text_effect {
            self.style.text_effect = v;
        }
        if let Some(v) = sc.text_effect_fixed {
            self.style.text_effect_fixed = v;
        }
        if let Some(v) = &sc.font_name {
            self.style.font_name = v.clone();
        }
        if let Some(v) = sc.font_size {
            self.style.font_size = v;
        }
        if let Some(v) = sc.font_bold {
            self.style.font_bold = v;
        }
        if let Some(v) = sc.font_italic {
            self.style.font_italic = v;
        }
        if let Some(v) = sc.font_underline {
            self.style.font_underline = v;
        }
        if let Some(v) = sc.font_strikethrough {
            self.style.font_strikethrough = v;
        }
        if let Some(v) = sc.font_width {
            self.style.font_width = v;
        }
        if let Some(v) = sc.sheet_border {
            self.style.sheet_border = v;
        }
        if let Some(v) = sc.progress_color {
            self.style.progress_color = v;
        }
        if let Some(v) = sc.image_over_text {
            self.style.image_over_text = v;
        }
        if let Some(v) = &sc.background_image {
            self.style.background_image = v.clone();
        }
        if let Some(v) = sc.background_image_alignment {
            self.style.background_image_alignment = v;
        }
        if let Some(v) = sc.text_render_mode {
            self.style.text_render_mode = v;
        }
        if let Some(v) = sc.text_hinting_mode {
            self.style.text_hinting_mode = v;
        }
        if let Some(v) = sc.text_pixel_snap {
            self.style.text_pixel_snap = v;
        }
        if let Some(v) = &sc.cell_padding {
            self.style.cell_padding = apply_padding_patch(self.style.cell_padding, v);
        }
        if let Some(v) = &sc.fixed_cell_padding {
            self.style.fixed_cell_padding = apply_padding_patch(self.style.fixed_cell_padding, v);
        }
        if let Some(v) = &sc.header_separator {
            if let Some(enabled) = v.enabled {
                self.style.header_separator.enabled = enabled;
            }
            if let Some(color) = v.color {
                self.style.header_separator.color = color;
            }
            if let Some(width_px) = v.width_px {
                self.style.header_separator.width_px = width_px.max(1);
            }
            if let Some(height) = &v.height {
                self.style.header_separator.height =
                    v1_header_mark_to_engine(height, self.style.header_separator.height);
            }
            if let Some(skip_merged) = v.skip_merged {
                self.style.header_separator.skip_merged = skip_merged;
            }
        }
        if let Some(v) = &sc.header_resize_handle {
            if let Some(enabled) = v.enabled {
                self.style.header_resize_handle.enabled = enabled;
            }
            if let Some(color) = v.color {
                self.style.header_resize_handle.color = color;
            }
            if let Some(width_px) = v.width_px {
                self.style.header_resize_handle.width_px = width_px.max(1);
            }
            if let Some(height) = &v.height {
                self.style.header_resize_handle.height =
                    v1_header_mark_to_engine(height, self.style.header_resize_handle.height);
            }
            if let Some(hit_width_px) = v.hit_width_px {
                self.style.header_resize_handle.hit_width_px = hit_width_px.max(1);
            }
            if let Some(show_only_when_resizable) = v.show_only_when_resizable {
                self.style.header_resize_handle.show_only_when_resizable = show_only_when_resizable;
            }
        }
        if let Some(v) = &sc.icon_theme_slots {
            apply_icon_slot_patch(
                &mut self.style.icon_theme_slots.sort_ascending,
                &v.sort_ascending,
            );
            apply_icon_slot_patch(
                &mut self.style.icon_theme_slots.sort_descending,
                &v.sort_descending,
            );
            apply_icon_slot_patch(&mut self.style.icon_theme_slots.sort_none, &v.sort_none);
            apply_icon_slot_patch(
                &mut self.style.icon_theme_slots.tree_expanded,
                &v.tree_expanded,
            );
            apply_icon_slot_patch(
                &mut self.style.icon_theme_slots.tree_collapsed,
                &v.tree_collapsed,
            );
            apply_icon_slot_patch(&mut self.style.icon_theme_slots.menu, &v.menu);
            apply_icon_slot_patch(&mut self.style.icon_theme_slots.filter, &v.filter);
            apply_icon_slot_patch(
                &mut self.style.icon_theme_slots.filter_active,
                &v.filter_active,
            );
            apply_icon_slot_patch(&mut self.style.icon_theme_slots.columns, &v.columns);
            apply_icon_slot_patch(&mut self.style.icon_theme_slots.drag_handle, &v.drag_handle);
            apply_icon_slot_patch(
                &mut self.style.icon_theme_slots.checkbox_checked,
                &v.checkbox_checked,
            );
            apply_icon_slot_patch(
                &mut self.style.icon_theme_slots.checkbox_unchecked,
                &v.checkbox_unchecked,
            );
            apply_icon_slot_patch(
                &mut self.style.icon_theme_slots.checkbox_indeterminate,
                &v.checkbox_indeterminate,
            );
        }
        if let Some(v) = &sc.icon_theme_defaults {
            if let Some(text_style) = &v.text_style {
                apply_icon_text_style_patch(
                    &mut self.style.icon_theme_defaults.text_style,
                    text_style,
                );
            }
            if let Some(layout) = &v.layout {
                apply_icon_layout_patch(&mut self.style.icon_theme_defaults.layout, layout);
            }
        }
        if let Some(v) = &sc.icon_theme_slot_styles {
            let default_layout = self.style.icon_theme_defaults.layout;
            apply_icon_slot_style_patch(
                &mut self.style.icon_theme_slot_styles.sort_ascending,
                &v.sort_ascending,
                default_layout,
            );
            apply_icon_slot_style_patch(
                &mut self.style.icon_theme_slot_styles.sort_descending,
                &v.sort_descending,
                default_layout,
            );
            apply_icon_slot_style_patch(
                &mut self.style.icon_theme_slot_styles.sort_none,
                &v.sort_none,
                default_layout,
            );
            apply_icon_slot_style_patch(
                &mut self.style.icon_theme_slot_styles.tree_expanded,
                &v.tree_expanded,
                default_layout,
            );
            apply_icon_slot_style_patch(
                &mut self.style.icon_theme_slot_styles.tree_collapsed,
                &v.tree_collapsed,
                default_layout,
            );
            apply_icon_slot_style_patch(
                &mut self.style.icon_theme_slot_styles.menu,
                &v.menu,
                default_layout,
            );
            apply_icon_slot_style_patch(
                &mut self.style.icon_theme_slot_styles.filter,
                &v.filter,
                default_layout,
            );
            apply_icon_slot_style_patch(
                &mut self.style.icon_theme_slot_styles.filter_active,
                &v.filter_active,
                default_layout,
            );
            apply_icon_slot_style_patch(
                &mut self.style.icon_theme_slot_styles.columns,
                &v.columns,
                default_layout,
            );
            apply_icon_slot_style_patch(
                &mut self.style.icon_theme_slot_styles.drag_handle,
                &v.drag_handle,
                default_layout,
            );
            apply_icon_slot_style_patch(
                &mut self.style.icon_theme_slot_styles.checkbox_checked,
                &v.checkbox_checked,
                default_layout,
            );
            apply_icon_slot_style_patch(
                &mut self.style.icon_theme_slot_styles.checkbox_unchecked,
                &v.checkbox_unchecked,
                default_layout,
            );
            apply_icon_slot_style_patch(
                &mut self.style.icon_theme_slot_styles.checkbox_indeterminate,
                &v.checkbox_indeterminate,
                default_layout,
            );
        }
        if let Some(img) = &sc.checkbox_checked_picture {
            self.style.checkbox_checked_picture = if img.data.is_empty() {
                None
            } else {
                Some(img.data.clone())
            };
        }
        if let Some(img) = &sc.checkbox_unchecked_picture {
            self.style.checkbox_unchecked_picture = if img.data.is_empty() {
                None
            } else {
                Some(img.data.clone())
            };
        }
        if let Some(img) = &sc.checkbox_indeterminate_picture {
            self.style.checkbox_indeterminate_picture = if img.data.is_empty() {
                None
            } else {
                Some(img.data.clone())
            };
        }
        if let Some(v) = sc.show_sort_numbers {
            self.style.show_sort_numbers = v;
        }
        if let Some(v) = sc.fill_handle_color {
            self.style.fill_handle_color = v;
        }
        if let Some(v) = sc.apply_scope {
            self.apply_scope = v;
        }
        if let Some(v) = sc.custom_render {
            self.custom_render = v;
        }
        // Sort pictures live on SortState
        if let Some(img) = &sc.sort_ascending_picture {
            self.sort_state.sort_ascending_picture = if img.data.is_empty() {
                None
            } else {
                Some(img.data.clone())
            };
        }
        if let Some(img) = &sc.sort_descending_picture {
            self.sort_state.sort_descending_picture = if img.data.is_empty() {
                None
            } else {
                Some(img.data.clone())
            };
        }
        // Node pictures live on OutlineState
        if let Some(img) = &sc.node_open_picture {
            self.outline.node_open_picture = if img.data.is_empty() {
                None
            } else {
                Some(img.data.clone())
            };
        }
        if let Some(img) = &sc.node_closed_picture {
            self.outline.node_closed_picture = if img.data.is_empty() {
                None
            } else {
                Some(img.data.clone())
            };
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
        if let Some(v) = sel.selection_visibility {
            self.selection.selection_visibility = v;
        }
        if let Some(v) = sel.allow_selection {
            self.allow_selection = v;
        }
        if let Some(v) = sel.header_click_select {
            self.header_click_select = v;
        }
        if let Some(v) = sel.show_fill_handle {
            self.selection.show_fill_handle = v;
        }
        self.mark_dirty();
    }

    fn apply_edit_config(&mut self, ec: &v1::EditConfig) {
        if let Some(v) = ec.edit_trigger {
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
        if let Some(v) = ec.edit_max_length {
            self.edit_max_length = v;
        }
        if let Some(v) = &ec.edit_mask {
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
        if let Some(v) = ic.allow_user_resizing {
            self.allow_user_resizing = v;
        }
        if let Some(v) = ic.allow_user_freezing {
            self.allow_user_freezing = v;
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
        if let Some(v) = ic.header_features {
            self.header_features = v;
        }
        self.mark_dirty();
    }

    fn apply_render_config(&mut self, rc: &v1::RenderConfig) {
        if let Some(v) = rc.renderer_mode {
            self.renderer_mode = v;
        }
        if let Some(v) = rc.debug_overlay {
            self.debug_overlay = v;
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
            format_string: Some(self.format_string.clone()),
            word_wrap: Some(self.word_wrap),
            ellipsis: Some(self.ellipsis_mode),
            text_overflow: Some(self.text_overflow),
        }
    }

    fn get_style_config(&self) -> v1::StyleConfig {
        v1::StyleConfig {
            appearance: Some(self.style.appearance),
            back_color: Some(self.style.back_color),
            fore_color: Some(self.style.fore_color),
            back_color_fixed: Some(self.style.back_color_fixed),
            fore_color_fixed: Some(self.style.fore_color_fixed),
            back_color_frozen: Some(self.style.back_color_frozen),
            fore_color_frozen: Some(self.style.fore_color_frozen),
            back_color_sel: Some(self.style.back_color_sel),
            fore_color_sel: Some(self.style.fore_color_sel),
            back_color_bkg: Some(self.style.back_color_bkg),
            back_color_alternate: Some(self.style.back_color_alternate),
            grid_lines: Some(self.style.grid_lines),
            grid_lines_fixed: Some(self.style.grid_lines_fixed),
            grid_color: Some(self.style.grid_color),
            grid_color_fixed: Some(self.style.grid_color_fixed),
            grid_line_width: Some(self.style.grid_line_width),
            text_effect: Some(self.style.text_effect),
            text_effect_fixed: Some(self.style.text_effect_fixed),
            font_name: Some(self.style.font_name.clone()),
            font_size: Some(self.style.font_size),
            font_bold: Some(self.style.font_bold),
            font_italic: Some(self.style.font_italic),
            font_underline: Some(self.style.font_underline),
            font_strikethrough: Some(self.style.font_strikethrough),
            font_width: Some(self.style.font_width),
            sheet_border: Some(self.style.sheet_border),
            progress_color: Some(self.style.progress_color),
            image_over_text: Some(self.style.image_over_text),
            background_image: if self.style.background_image.is_empty() {
                None
            } else {
                Some(self.style.background_image.clone())
            },
            background_image_alignment: Some(self.style.background_image_alignment),
            text_render_mode: Some(self.style.text_render_mode),
            text_hinting_mode: Some(self.style.text_hinting_mode),
            text_pixel_snap: Some(self.style.text_pixel_snap),
            cell_padding: Some(engine_padding_to_v1(self.style.cell_padding)),
            fixed_cell_padding: Some(engine_padding_to_v1(self.style.fixed_cell_padding)),
            header_separator: Some(v1::HeaderSeparatorStyle {
                enabled: Some(self.style.header_separator.enabled),
                color: Some(self.style.header_separator.color),
                width_px: Some(self.style.header_separator.width_px.max(1)),
                height: Some(engine_header_mark_to_v1(self.style.header_separator.height)),
                skip_merged: Some(self.style.header_separator.skip_merged),
            }),
            header_resize_handle: Some(v1::HeaderResizeHandleStyle {
                enabled: Some(self.style.header_resize_handle.enabled),
                color: Some(self.style.header_resize_handle.color),
                width_px: Some(self.style.header_resize_handle.width_px.max(1)),
                height: Some(engine_header_mark_to_v1(
                    self.style.header_resize_handle.height,
                )),
                hit_width_px: Some(self.style.header_resize_handle.hit_width_px.max(1)),
                show_only_when_resizable: Some(
                    self.style.header_resize_handle.show_only_when_resizable,
                ),
            }),
            icon_theme_slots: Some(v1::IconThemeSlots {
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
                checkbox_indeterminate: self.style.icon_theme_slots.checkbox_indeterminate.clone(),
            }),
            checkbox_checked_picture: self.style.checkbox_checked_picture.as_ref().map(|d| {
                v1::ImageData {
                    data: d.clone(),
                    format: "png".into(),
                }
            }),
            checkbox_unchecked_picture: self.style.checkbox_unchecked_picture.as_ref().map(|d| {
                v1::ImageData {
                    data: d.clone(),
                    format: "png".into(),
                }
            }),
            checkbox_indeterminate_picture: self.style.checkbox_indeterminate_picture.as_ref().map(
                |d| v1::ImageData {
                    data: d.clone(),
                    format: "png".into(),
                },
            ),
            icon_theme_defaults: Some(v1::IconThemeDefaults {
                text_style: Some(icon_text_style_to_v1(
                    &self.style.icon_theme_defaults.text_style,
                )),
                layout: Some(icon_layout_to_v1(self.style.icon_theme_defaults.layout)),
            }),
            icon_theme_slot_styles: Some(v1::IconThemeSlotStyles {
                sort_ascending: icon_slot_style_to_v1(
                    &self.style.icon_theme_slot_styles.sort_ascending,
                ),
                sort_descending: icon_slot_style_to_v1(
                    &self.style.icon_theme_slot_styles.sort_descending,
                ),
                sort_none: icon_slot_style_to_v1(&self.style.icon_theme_slot_styles.sort_none),
                tree_expanded: icon_slot_style_to_v1(
                    &self.style.icon_theme_slot_styles.tree_expanded,
                ),
                tree_collapsed: icon_slot_style_to_v1(
                    &self.style.icon_theme_slot_styles.tree_collapsed,
                ),
                menu: icon_slot_style_to_v1(&self.style.icon_theme_slot_styles.menu),
                filter: icon_slot_style_to_v1(&self.style.icon_theme_slot_styles.filter),
                filter_active: icon_slot_style_to_v1(
                    &self.style.icon_theme_slot_styles.filter_active,
                ),
                columns: icon_slot_style_to_v1(&self.style.icon_theme_slot_styles.columns),
                drag_handle: icon_slot_style_to_v1(&self.style.icon_theme_slot_styles.drag_handle),
                checkbox_checked: icon_slot_style_to_v1(
                    &self.style.icon_theme_slot_styles.checkbox_checked,
                ),
                checkbox_unchecked: icon_slot_style_to_v1(
                    &self.style.icon_theme_slot_styles.checkbox_unchecked,
                ),
                checkbox_indeterminate: icon_slot_style_to_v1(
                    &self.style.icon_theme_slot_styles.checkbox_indeterminate,
                ),
            }),
            show_sort_numbers: Some(self.style.show_sort_numbers),
            fill_handle_color: Some(self.style.fill_handle_color),
            apply_scope: Some(self.apply_scope),
            custom_render: Some(self.custom_render),
            sort_ascending_picture: self.sort_state.sort_ascending_picture.as_ref().map(|d| {
                v1::ImageData {
                    data: d.clone(),
                    format: "png".into(),
                }
            }),
            sort_descending_picture: self.sort_state.sort_descending_picture.as_ref().map(|d| {
                v1::ImageData {
                    data: d.clone(),
                    format: "png".into(),
                }
            }),
            node_open_picture: self
                .outline
                .node_open_picture
                .as_ref()
                .map(|d| v1::ImageData {
                    data: d.clone(),
                    format: "png".into(),
                }),
            node_closed_picture: self
                .outline
                .node_closed_picture
                .as_ref()
                .map(|d| v1::ImageData {
                    data: d.clone(),
                    format: "png".into(),
                }),
        }
    }

    fn get_selection_config(&self) -> v1::SelectionConfig {
        v1::SelectionConfig {
            mode: Some(self.selection.mode),
            focus_border: Some(self.selection.focus_border),
            selection_visibility: Some(self.selection.selection_visibility),
            allow_selection: Some(self.allow_selection),
            header_click_select: Some(self.header_click_select),
            show_fill_handle: Some(self.selection.show_fill_handle),
        }
    }

    fn get_edit_config(&self) -> v1::EditConfig {
        v1::EditConfig {
            edit_trigger: Some(self.edit_trigger_mode),
            tab_behavior: Some(self.tab_behavior),
            dropdown_trigger: Some(self.dropdown_trigger),
            dropdown_search: Some(self.dropdown_search),
            edit_max_length: Some(self.edit_max_length),
            edit_mask: Some(self.edit_mask.clone()),
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
        v1::InteractionConfig {
            allow_user_resizing: Some(self.allow_user_resizing),
            allow_user_freezing: Some(self.allow_user_freezing),
            type_ahead: Some(self.type_ahead_mode),
            type_ahead_delay: Some(self.type_ahead_delay),
            auto_size_mouse: Some(self.auto_size_mouse),
            auto_size_mode: Some(self.auto_size_mode),
            auto_resize: Some(self.auto_resize),
            drag_mode: Some(self.drag.drag_mode),
            drop_mode: Some(self.drag.drop_mode),
            header_features: Some(self.header_features),
        }
    }

    fn get_render_config(&self) -> v1::RenderConfig {
        v1::RenderConfig {
            renderer_mode: Some(self.renderer_mode),
            debug_overlay: Some(self.debug_overlay),
            animation_enabled: Some(self.animation.enabled),
            animation_duration_ms: Some(self.animation.duration_ms),
            text_layout_cache_cap: Some(self.text_layout_cache_cap.min(i32::MAX as usize) as i32),
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
                if let Some(v) = def.alignment {
                    cp.alignment = v;
                }
                if let Some(v) = def.fixed_alignment {
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
                if let Some(v) = def.sort {
                    cp.sort_order = v;
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
                if let Some(v) = &def.cell_padding {
                    let base = cp.cell_padding.unwrap_or(grid_cell_padding);
                    cp.cell_padding = Some(apply_padding_patch(base, v));
                }
                if let Some(v) = &def.fixed_cell_padding {
                    let base = cp
                        .fixed_cell_padding
                        .or(cp.cell_padding)
                        .unwrap_or(grid_fixed_padding);
                    cp.fixed_cell_padding = Some(apply_padding_patch(base, v));
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

    /// Batch-set cell values, styles, checked state, and pictures.
    pub fn update_cells(&mut self, updates: &[v1::CellUpdate]) {
        for u in updates {
            let row = u.row;
            let col = u.col;
            if row < 0 || row >= self.rows || col < 0 || col >= self.cols {
                continue;
            }

            // Value
            if let Some(cv) = &u.value {
                if let Some(val) = &cv.value {
                    match val {
                        v1::cell_value::Value::Text(t) => {
                            self.cells.set_text(row, col, t.clone());
                        }
                        v1::cell_value::Value::Number(n) => {
                            self.cells.set_value(row, col, CellValueData::Number(*n));
                            self.cells.set_text(row, col, n.to_string());
                        }
                        v1::cell_value::Value::Flag(b) => {
                            self.cells.set_value(row, col, CellValueData::Bool(*b));
                        }
                        v1::cell_value::Value::Data(d) => {
                            self.cells
                                .set_value(row, col, CellValueData::Bytes(d.clone()));
                        }
                    }
                }
            }

            // Style — merge incoming fields into existing override
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

            // Checked
            if let Some(c) = u.checked {
                let cell = self.cells.get_mut(row, col);
                cell.extra_mut().checked = c;
            }

            // Picture
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

            // Picture alignment
            if let Some(pa) = u.picture_alignment {
                let cell = self.cells.get_mut(row, col);
                cell.extra_mut().picture_alignment = pa;
            }

            // Button picture
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

            // Dropdown items
            if let Some(cl) = &u.dropdown_items {
                let cell = self.cells.get_mut(row, col);
                cell.extra_mut().dropdown_items = cl.clone();
            }

            // Cell-level sticky overrides
            if u.sticky_row.is_some() || u.sticky_col.is_some() {
                let sr = u.sticky_row.unwrap_or(0);
                let sc = u.sticky_col.unwrap_or(0);
                self.set_cell_sticky(row, col, sr, sc);
            }
        }
        self.mark_dirty();
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
    ) -> Vec<v1::CellData> {
        let r1 = row1.max(0).min(self.rows - 1);
        let r2 = row2.max(0).min(self.rows - 1);
        let c1 = col1.max(0).min(self.cols - 1);
        let c2 = col2.max(0).min(self.cols - 1);

        let mut result = Vec::new();
        for row in r1..=r2 {
            for col in c1..=c2 {
                let text = self.cells.get_text(row, col);
                let value = if text.is_empty() {
                    None
                } else {
                    Some(v1::CellValue {
                        value: Some(v1::cell_value::Value::Text(text.to_string())),
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
                    value,
                    style,
                    checked,
                });
            }
        }
        result
    }
}

// ═══════════════════════════════════════════════════════════════════════════
// Conversion helpers: v2 proto ↔ engine types
// ═══════════════════════════════════════════════════════════════════════════

/// Convert a v2 `CellStyleOverride` proto to the engine's `CellStyleOverride`.
///
/// Unlike v1, v2 uses proper `Option<T>` — no sentinel-value heuristics needed.
pub fn v2_cell_style_to_engine(s: &v1::CellStyleOverride) -> style::CellStyleOverride {
    style::CellStyleOverride {
        back_color: s.back_color,
        fore_color: s.fore_color,
        alignment: s.alignment,
        text_effect: s.text_effect,
        font_name: s.font_name.clone(),
        font_size: s.font_size,
        font_bold: s.font_bold,
        font_italic: s.font_italic,
        font_underline: s.font_underline,
        font_strikethrough: s.font_strikethrough,
        font_width: s.font_width,
        border: s.border,
        border_color: s.border_color,
        border_top: s.border_top,
        border_right: s.border_right,
        border_bottom: s.border_bottom,
        border_left: s.border_left,
        border_top_color: s.border_top_color,
        border_right_color: s.border_right_color,
        border_bottom_color: s.border_bottom_color,
        border_left_color: s.border_left_color,
        padding: s
            .padding
            .as_ref()
            .map(|p| apply_padding_patch(style::CellPadding::default(), p)),
        shrink_to_fit: s.shrink_to_fit,
    }
}

/// Convert the engine's `CellStyleOverride` to a v2 proto `CellStyleOverride`.
pub fn engine_cell_style_to_v2(s: &style::CellStyleOverride) -> v1::CellStyleOverride {
    v1::CellStyleOverride {
        back_color: s.back_color,
        fore_color: s.fore_color,
        alignment: s.alignment,
        text_effect: s.text_effect,
        font_name: s.font_name.clone(),
        font_size: s.font_size,
        font_bold: s.font_bold,
        font_italic: s.font_italic,
        font_underline: s.font_underline,
        font_strikethrough: s.font_strikethrough,
        font_width: s.font_width,
        progress_color: None,
        progress_percent: None,
        border: s.border,
        border_color: s.border_color,
        border_top: s.border_top,
        border_right: s.border_right,
        border_bottom: s.border_bottom,
        border_left: s.border_left,
        border_top_color: s.border_top_color,
        border_right_color: s.border_right_color,
        border_bottom_color: s.border_bottom_color,
        border_left_color: s.border_left_color,
        padding: s.padding.map(engine_padding_to_v1),
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
                back_color: Some(0xFF112233),
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

        assert_eq!(config.style.as_ref().unwrap().back_color, Some(0xAABBCCDD));
        assert_eq!(config.editing.as_ref().unwrap().edit_trigger, Some(2));
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
                alignment: Some(4),
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
                cell_padding: Some(v1::CellPadding {
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
            cell_padding: Some(v1::CellPadding {
                left: Some(7),
                right: Some(9),
                ..Default::default()
            }),
            fixed_cell_padding: Some(v1::CellPadding {
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
                style: Some(v1::CellStyleOverride {
                    back_color: Some(0xFF0000FF),
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
    fn get_cells_range() {
        let mut grid = test_grid();
        grid.cells.set_text(1, 1, "A".to_string());
        grid.cells.set_text(1, 2, "B".to_string());
        grid.cells.set_text(2, 1, "C".to_string());

        let cells = grid.get_cells(1, 1, 2, 2, false, false);
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
        let engine_style = style::CellStyleOverride {
            back_color: Some(0xFF112233),
            font_bold: Some(true),
            border: Some(1),
            padding: Some(style::CellPadding {
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
            layout: Some(v1::LayoutConfig {
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
        assert_eq!(
            config.layout.as_ref().unwrap().text_overflow,
            Some(true)
        );
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

    // ── shrink_to_fit style tests ──────────────────────────────────

    #[test]
    fn shrink_to_fit_roundtrip() {
        let engine_style = style::CellStyleOverride {
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
        let engine_style = style::CellStyleOverride {
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
        let s = style::CellStyleOverride {
            shrink_to_fit: Some(true),
            ..Default::default()
        };
        assert!(!s.is_empty());

        // is_empty should return true when all fields are None
        let empty = style::CellStyleOverride::default();
        assert!(empty.is_empty());

        // merge_from should overwrite shrink_to_fit
        let mut base = style::CellStyleOverride::default();
        let patch = style::CellStyleOverride {
            shrink_to_fit: Some(true),
            ..Default::default()
        };
        base.merge_from(&patch);
        assert_eq!(base.shrink_to_fit, Some(true));

        // merge_from with None should not overwrite
        let noop = style::CellStyleOverride::default();
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
            style: Some(v1::CellStyleOverride {
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
            layout: Some(v1::LayoutConfig {
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
