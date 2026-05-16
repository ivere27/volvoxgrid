//! Built-in visual themes.
//!
//! Each theme returns a `v1::GridConfig` containing the four visual
//! sub-configs that a theme owns:
//!   * `StyleConfig`      — cell / region / header / sheet colors, grid lines,
//!                          border appearance.
//!   * `SelectionConfig`  — selection / hover / active-cell / indicator-row /
//!                          indicator-column highlight styles + focus border.
//!                          (Mode/visibility/allow are **not** theme concerns.)
//!   * `ScrollBarConfig`  — scrollbar appearance + colors. Carried inside
//!                          `ScrollConfig`.
//!   * `IndicatorsConfig` — indicator appearance + colors.
//!                          (Slot layouts are structural, not theme.)
//!
//! The returned `GridConfig` is fed back through `apply_config` so the theme
//! re-uses the same per-field apply machinery as a user-authored config.
//! `theme_preset` is intentionally left unset to avoid recursion.

use crate::proto::volvoxgrid::v1;

/// Returns a `GridConfig` whose visual sub-fields are populated for `preset`.
/// `THEME_NONE` returns an empty config (no-op).
pub fn palette_for(preset: v1::ThemePreset) -> v1::GridConfig {
    match preset {
        v1::ThemePreset::ThemeNone => v1::GridConfig::default(),
        v1::ThemePreset::ThemeClassic => classic(),
        v1::ThemePreset::ThemeLight => light(),
        v1::ThemePreset::ThemeDark => dark(),
        v1::ThemePreset::ThemeHighContrast => high_contrast(),
        v1::ThemePreset::ThemeMonokai => monokai(),
        v1::ThemePreset::ThemeAmber => amber(),
    }
}

fn highlight(background: u32, foreground: u32) -> v1::HighlightStyle {
    v1::HighlightStyle {
        background: Some(background),
        foreground: Some(foreground),
        ..Default::default()
    }
}

fn hover(row_back: u32, column_back: u32, cell_back: u32) -> v1::HoverConfig {
    v1::HoverConfig {
        row: Some(true),
        column: Some(false),
        cell: Some(true),
        row_style: Some(v1::HighlightStyle {
            background: Some(row_back),
            ..Default::default()
        }),
        column_style: Some(v1::HighlightStyle {
            background: Some(column_back),
            ..Default::default()
        }),
        cell_style: Some(v1::HighlightStyle {
            background: Some(cell_back),
            ..Default::default()
        }),
    }
}

fn border(style: v1::BorderStyle, color: u32) -> v1::Border {
    v1::Border {
        style: Some(style as i32),
        color: Some(color),
    }
}

fn borders_all(style: v1::BorderStyle, color: u32) -> v1::Borders {
    v1::Borders {
        all: Some(border(style, color)),
        ..Default::default()
    }
}

fn scrollbar(appearance: v1::ScrollBarAppearance, colors: v1::ScrollBarColors) -> v1::ScrollConfig {
    v1::ScrollConfig {
        scroll_bar: Some(v1::ScrollBarConfig {
            appearance: Some(appearance as i32),
            colors: Some(colors),
            ..Default::default()
        }),
        ..Default::default()
    }
}

fn amber() -> v1::GridConfig {
    let body_back = 0xFFFFFFFFu32;
    let body_fore = 0xFF1C1917u32;
    let canvas_back = 0xFFFAFAF9u32;
    let alt_row = 0xFFF5F5F4u32;
    let header_back = 0xFFFAFAF9u32;
    let indicator_fore = 0xFF44403Cu32;
    let grid_line = 0xFFE7E5E4u32;
    let fixed_grid_line = 0xFFD6D3D1u32;
    let selection_back = 0xFFD97706u32;
    let selection_fore = 0xFFFFFFFFu32;
    let accent = 0xFFF59E0Bu32;
    let active_back = 0x22000000u32;
    let hover_row = 0x10D97706u32;
    let hover_col = 0x10D97706u32;
    let hover_cell = 0x1AD97706u32;

    v1::GridConfig {
        style: Some(v1::StyleConfig {
            background: Some(body_back),
            foreground: Some(body_fore),
            alternate_background: Some(alt_row),
            progress_color: Some(accent),
            grid_lines: Some(v1::GridLines {
                style: Some(v1::GridLineStyle::GridlineSolid as i32),
                color: Some(grid_line),
                ..Default::default()
            }),
            fixed: Some(v1::RegionStyle {
                background: Some(alt_row),
                foreground: Some(indicator_fore),
                grid_lines: Some(v1::GridLines {
                    style: Some(v1::GridLineStyle::GridlineSolid as i32),
                    color: Some(fixed_grid_line),
                    ..Default::default()
                }),
                ..Default::default()
            }),
            frozen: Some(v1::RegionStyle {
                background: Some(body_back),
                foreground: Some(body_fore),
                grid_lines: Some(v1::GridLines {
                    style: Some(v1::GridLineStyle::GridlineSolid as i32),
                    color: Some(fixed_grid_line),
                    ..Default::default()
                }),
                ..Default::default()
            }),
            header: Some(v1::HeaderStyle {
                separator: Some(v1::HeaderSeparator {
                    enabled: Some(true),
                    color: Some(fixed_grid_line),
                    width: Some(1),
                    ..Default::default()
                }),
                resize_handle: Some(v1::HeaderResizeHandle {
                    enabled: Some(true),
                    color: Some(fixed_grid_line),
                    width: Some(1),
                    hit_width: Some(6),
                    ..Default::default()
                }),
            }),
            sheet_background: Some(canvas_back),
            sheet_border: Some(fixed_grid_line),
            appearance: Some(v1::BorderAppearance::Flat as i32),
            ..Default::default()
        }),
        selection: Some(v1::SelectionConfig {
            style: Some(v1::HighlightStyle {
                background: Some(selection_back),
                foreground: Some(selection_fore),
                fill_handle: Some(v1::FillHandlePosition::FillHandleNone as i32),
                fill_handle_color: Some(accent),
                ..Default::default()
            }),
            active_cell_style: Some(v1::HighlightStyle {
                background: Some(active_back),
                foreground: Some(selection_fore),
                borders: Some(borders_all(v1::BorderStyle::BorderThick, accent)),
                ..Default::default()
            }),
            indicator_row_style: Some(v1::HighlightStyle {
                background: Some(header_back),
                foreground: Some(indicator_fore),
                ..Default::default()
            }),
            indicator_col_style: Some(v1::HighlightStyle {
                background: Some(header_back),
                foreground: Some(indicator_fore),
                ..Default::default()
            }),
            hover: Some(v1::HoverConfig {
                row: Some(true),
                column: Some(false),
                cell: Some(true),
                row_style: Some(v1::HighlightStyle {
                    background: Some(hover_row),
                    ..Default::default()
                }),
                column_style: Some(v1::HighlightStyle {
                    background: Some(hover_col),
                    ..Default::default()
                }),
                cell_style: Some(v1::HighlightStyle {
                    background: Some(hover_cell),
                    borders: Some(borders_all(v1::BorderStyle::BorderThin, accent)),
                    ..Default::default()
                }),
            }),
            ..Default::default()
        }),
        scrolling: Some(scrollbar(
            v1::ScrollBarAppearance::ScrollbarAppearanceOverlay,
            v1::ScrollBarColors {
                thumb: Some(0x80F59E0B),
                thumb_hover: Some(0xB0F59E0B),
                thumb_active: Some(selection_back),
                track: Some(0x00000000),
                arrow: Some(indicator_fore),
                border: Some(0x00000000),
            },
        )),
        indicators: Some(v1::IndicatorsConfig {
            appearance: Some(v1::IndicatorAppearance::Modern as i32),
            colors: Some(v1::IndicatorColors {
                background: Some(header_back),
                foreground: Some(indicator_fore),
                grid: Some(fixed_grid_line),
                button_hover_background: Some(hover_cell),
                button_hover_foreground: Some(selection_back),
                ..Default::default()
            }),
            ..Default::default()
        }),
        ..Default::default()
    }
}

fn classic() -> v1::GridConfig {
    let body_back = 0xFFFFFFFFu32;
    let body_fore = 0xFF000000u32;
    let fixed_back = 0xFFC0C0C0u32;
    let fixed_fore = 0xFF000000u32;
    let grid_line = 0xFFC0C0C0u32;
    let selection_back = 0xFF0078D4u32; // system blue
    let selection_fore = 0xFFFFFFFFu32;
    let accent = selection_back;

    v1::GridConfig {
        style: Some(v1::StyleConfig {
            background: Some(body_back),
            foreground: Some(body_fore),
            alternate_background: Some(0x00000000), // off
            progress_color: Some(accent),
            grid_lines: Some(v1::GridLines {
                color: Some(grid_line),
                ..Default::default()
            }),
            fixed: Some(v1::RegionStyle {
                background: Some(fixed_back),
                foreground: Some(fixed_fore),
                ..Default::default()
            }),
            sheet_background: Some(body_back),
            sheet_border: Some(fixed_back),
            appearance: Some(v1::BorderAppearance::Raised as i32),
            ..Default::default()
        }),
        selection: Some(v1::SelectionConfig {
            style: Some(highlight(selection_back, selection_fore)),
            active_cell_style: Some(highlight(selection_back, selection_fore)),
            indicator_row_style: Some(v1::HighlightStyle {
                background: Some(fixed_back),
                ..Default::default()
            }),
            indicator_col_style: Some(v1::HighlightStyle {
                background: Some(fixed_back),
                ..Default::default()
            }),
            hover: Some(hover(0x00000000, 0x00000000, 0x00000000)),
            ..Default::default()
        }),
        scrolling: Some(scrollbar(
            v1::ScrollBarAppearance::ScrollbarAppearanceClassic,
            v1::ScrollBarColors {
                thumb: Some(fixed_back),
                thumb_hover: Some(0xFFB0B0B0),
                thumb_active: Some(0xFFA0A0A0),
                track: Some(0xFFE0E0E0),
                arrow: Some(body_fore),
                border: Some(fixed_back),
            },
        )),
        indicators: Some(v1::IndicatorsConfig {
            appearance: Some(v1::IndicatorAppearance::Classic as i32),
            colors: Some(v1::IndicatorColors {
                background: Some(fixed_back),
                foreground: Some(fixed_fore),
                grid: Some(grid_line),
                ..Default::default()
            }),
            ..Default::default()
        }),
        ..Default::default()
    }
}

fn light() -> v1::GridConfig {
    let body_back = 0xFFFFFFFFu32;
    let body_fore = 0xFF111827u32;
    let alt_row = 0xFFF9FAFBu32;
    let header_back = 0xFFF9FAFBu32;
    let header_fore = 0xFF111827u32;
    let grid_line = 0xFFE5E7EBu32;
    let fixed_grid_line = 0xFFD1D5DBu32;
    let indicator_fore = 0xFF6B7280u32;
    let selection_back = 0xFF6366F1u32;
    let selection_fore = 0xFFFFFFFFu32;
    let accent = 0xFF818CF8u32;
    let active_back = 0x22000000u32;
    let hover_row = 0x106366F1u32;
    let hover_col = 0x106366F1u32;
    let hover_cell = 0x1E818CF8u32;

    v1::GridConfig {
        style: Some(v1::StyleConfig {
            background: Some(body_back),
            foreground: Some(body_fore),
            alternate_background: Some(alt_row),
            progress_color: Some(accent),
            grid_lines: Some(v1::GridLines {
                color: Some(grid_line),
                ..Default::default()
            }),
            fixed: Some(v1::RegionStyle {
                background: Some(header_back),
                foreground: Some(header_fore),
                grid_lines: Some(v1::GridLines {
                    color: Some(fixed_grid_line),
                    ..Default::default()
                }),
                ..Default::default()
            }),
            sheet_background: Some(0xFFFAFAFBu32),
            sheet_border: Some(fixed_grid_line),
            appearance: Some(v1::BorderAppearance::Flat as i32),
            ..Default::default()
        }),
        selection: Some(v1::SelectionConfig {
            style: Some(highlight(selection_back, selection_fore)),
            active_cell_style: Some(v1::HighlightStyle {
                background: Some(active_back),
                foreground: Some(0xFFFFFFFFu32),
                ..Default::default()
            }),
            indicator_row_style: Some(v1::HighlightStyle {
                background: Some(header_back),
                foreground: Some(indicator_fore),
                ..Default::default()
            }),
            indicator_col_style: Some(v1::HighlightStyle {
                background: Some(header_back),
                foreground: Some(indicator_fore),
                ..Default::default()
            }),
            hover: Some(hover(hover_row, hover_col, hover_cell)),
            ..Default::default()
        }),
        scrolling: Some(scrollbar(
            v1::ScrollBarAppearance::ScrollbarAppearanceOverlay,
            v1::ScrollBarColors {
                thumb: Some(0x80818CF8),
                thumb_hover: Some(0xB0818CF8),
                thumb_active: Some(0xFF6366F1),
                track: Some(0x00000000),
                arrow: Some(indicator_fore),
                border: Some(0x00000000),
            },
        )),
        indicators: Some(v1::IndicatorsConfig {
            appearance: Some(v1::IndicatorAppearance::Modern as i32),
            colors: Some(v1::IndicatorColors {
                background: Some(header_back),
                foreground: Some(indicator_fore),
                grid: Some(fixed_grid_line),
                button_hover_background: Some(hover_cell),
                button_hover_foreground: Some(selection_back),
                ..Default::default()
            }),
            ..Default::default()
        }),
        ..Default::default()
    }
}

fn dark() -> v1::GridConfig {
    let body_back = 0xFF1E1E1Eu32;
    let body_fore = 0xFFE5E7EBu32;
    let alt_row = 0xFF252526u32;
    let header_back = 0xFF2D2D30u32;
    let header_fore = 0xFFE5E7EBu32;
    let grid_line = 0xFF3E3E42u32;
    let fixed_grid_line = 0xFF505055u32;
    let indicator_fore = 0xFF9CA3AFu32;
    let selection_back = 0xFF264F78u32;
    let selection_fore = 0xFFFFFFFFu32;
    let accent = 0xFF569CD6u32;
    let active_back = 0x33FFFFFFu32;
    let hover_row = 0x14569CD6u32;
    let hover_col = 0x14569CD6u32;
    let hover_cell = 0x28569CD6u32;

    v1::GridConfig {
        style: Some(v1::StyleConfig {
            background: Some(body_back),
            foreground: Some(body_fore),
            alternate_background: Some(alt_row),
            progress_color: Some(accent),
            grid_lines: Some(v1::GridLines {
                color: Some(grid_line),
                ..Default::default()
            }),
            fixed: Some(v1::RegionStyle {
                background: Some(header_back),
                foreground: Some(header_fore),
                grid_lines: Some(v1::GridLines {
                    color: Some(fixed_grid_line),
                    ..Default::default()
                }),
                ..Default::default()
            }),
            sheet_background: Some(body_back),
            sheet_border: Some(fixed_grid_line),
            appearance: Some(v1::BorderAppearance::Flat as i32),
            ..Default::default()
        }),
        selection: Some(v1::SelectionConfig {
            style: Some(highlight(selection_back, selection_fore)),
            active_cell_style: Some(v1::HighlightStyle {
                background: Some(active_back),
                foreground: Some(0xFFFFFFFFu32),
                ..Default::default()
            }),
            indicator_row_style: Some(v1::HighlightStyle {
                background: Some(header_back),
                foreground: Some(indicator_fore),
                ..Default::default()
            }),
            indicator_col_style: Some(v1::HighlightStyle {
                background: Some(header_back),
                foreground: Some(indicator_fore),
                ..Default::default()
            }),
            hover: Some(hover(hover_row, hover_col, hover_cell)),
            ..Default::default()
        }),
        scrolling: Some(scrollbar(
            v1::ScrollBarAppearance::ScrollbarAppearanceModern,
            v1::ScrollBarColors {
                thumb: Some(0x80569CD6),
                thumb_hover: Some(0xB0569CD6),
                thumb_active: Some(0xFF569CD6),
                track: Some(0xFF252526),
                arrow: Some(indicator_fore),
                border: Some(0x00000000),
            },
        )),
        indicators: Some(v1::IndicatorsConfig {
            appearance: Some(v1::IndicatorAppearance::Modern as i32),
            colors: Some(v1::IndicatorColors {
                background: Some(header_back),
                foreground: Some(indicator_fore),
                grid: Some(fixed_grid_line),
                button_hover_background: Some(hover_cell),
                button_hover_foreground: Some(accent),
                ..Default::default()
            }),
            ..Default::default()
        }),
        ..Default::default()
    }
}

fn high_contrast() -> v1::GridConfig {
    let black = 0xFF000000u32;
    let white = 0xFFFFFFFFu32;
    let yellow = 0xFFFFFF00u32;
    let cyan = 0xFF00FFFFu32;
    let hover_alpha = 0x4000FFFFu32;

    v1::GridConfig {
        style: Some(v1::StyleConfig {
            background: Some(black),
            foreground: Some(white),
            alternate_background: Some(0x00000000), // off
            progress_color: Some(yellow),
            grid_lines: Some(v1::GridLines {
                color: Some(white),
                ..Default::default()
            }),
            fixed: Some(v1::RegionStyle {
                background: Some(black),
                foreground: Some(white),
                grid_lines: Some(v1::GridLines {
                    color: Some(white),
                    ..Default::default()
                }),
                ..Default::default()
            }),
            sheet_background: Some(black),
            sheet_border: Some(white),
            appearance: Some(v1::BorderAppearance::Flat as i32),
            ..Default::default()
        }),
        selection: Some(v1::SelectionConfig {
            style: Some(highlight(yellow, black)),
            active_cell_style: Some(highlight(yellow, black)),
            indicator_row_style: Some(v1::HighlightStyle {
                background: Some(black),
                foreground: Some(white),
                ..Default::default()
            }),
            indicator_col_style: Some(v1::HighlightStyle {
                background: Some(black),
                foreground: Some(white),
                ..Default::default()
            }),
            hover: Some(hover(hover_alpha, hover_alpha, cyan)),
            ..Default::default()
        }),
        scrolling: Some(scrollbar(
            v1::ScrollBarAppearance::ScrollbarAppearanceClassic,
            v1::ScrollBarColors {
                thumb: Some(white),
                thumb_hover: Some(yellow),
                thumb_active: Some(yellow),
                track: Some(black),
                arrow: Some(white),
                border: Some(white),
            },
        )),
        indicators: Some(v1::IndicatorsConfig {
            appearance: Some(v1::IndicatorAppearance::Classic as i32),
            colors: Some(v1::IndicatorColors {
                background: Some(black),
                foreground: Some(white),
                grid: Some(white),
                ..Default::default()
            }),
            ..Default::default()
        }),
        ..Default::default()
    }
}

fn monokai() -> v1::GridConfig {
    let body_back = 0xFF272822u32;
    let body_fore = 0xFFF8F8F2u32;
    let alt_row = 0xFF2D2E27u32;
    let header_back = 0xFF3E3D32u32;
    let header_fore = 0xFFF8F8F2u32;
    let grid_line = 0xFF49483Eu32;
    let fixed_grid_line = 0xFF5A594Bu32;
    let indicator_fore = 0xFF75715Eu32;
    let selection_back = 0xFF75715Eu32;
    let selection_fore = 0xFFF8F8F2u32;
    let accent = 0xFFF92672u32; // pink
    let cyan = 0xFF66D9EFu32;
    let active_back = 0x33F92672u32;
    let hover_row = 0x14F92672u32;
    let hover_col = 0x1466D9EFu32;
    let hover_cell = 0x28F92672u32;

    v1::GridConfig {
        style: Some(v1::StyleConfig {
            background: Some(body_back),
            foreground: Some(body_fore),
            alternate_background: Some(alt_row),
            progress_color: Some(accent),
            grid_lines: Some(v1::GridLines {
                color: Some(grid_line),
                ..Default::default()
            }),
            fixed: Some(v1::RegionStyle {
                background: Some(header_back),
                foreground: Some(header_fore),
                grid_lines: Some(v1::GridLines {
                    color: Some(fixed_grid_line),
                    ..Default::default()
                }),
                ..Default::default()
            }),
            sheet_background: Some(body_back),
            sheet_border: Some(fixed_grid_line),
            appearance: Some(v1::BorderAppearance::Flat as i32),
            ..Default::default()
        }),
        selection: Some(v1::SelectionConfig {
            style: Some(highlight(selection_back, selection_fore)),
            active_cell_style: Some(v1::HighlightStyle {
                background: Some(active_back),
                foreground: Some(body_fore),
                ..Default::default()
            }),
            indicator_row_style: Some(v1::HighlightStyle {
                background: Some(header_back),
                foreground: Some(indicator_fore),
                ..Default::default()
            }),
            indicator_col_style: Some(v1::HighlightStyle {
                background: Some(header_back),
                foreground: Some(indicator_fore),
                ..Default::default()
            }),
            hover: Some(hover(hover_row, hover_col, hover_cell)),
            ..Default::default()
        }),
        scrolling: Some(scrollbar(
            v1::ScrollBarAppearance::ScrollbarAppearanceOverlay,
            v1::ScrollBarColors {
                thumb: Some(0x80F92672),
                thumb_hover: Some(0xB0F92672),
                thumb_active: Some(0xFFF92672),
                track: Some(0x00000000),
                arrow: Some(indicator_fore),
                border: Some(0x00000000),
            },
        )),
        indicators: Some(v1::IndicatorsConfig {
            appearance: Some(v1::IndicatorAppearance::Modern as i32),
            colors: Some(v1::IndicatorColors {
                background: Some(header_back),
                foreground: Some(indicator_fore),
                grid: Some(fixed_grid_line),
                button_hover_background: Some(hover_cell),
                button_hover_foreground: Some(cyan),
                ..Default::default()
            }),
            ..Default::default()
        }),
        ..Default::default()
    }
}
