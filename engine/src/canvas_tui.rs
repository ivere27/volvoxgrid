use crate::canvas::{
    alignment_components, layer, parse_progress_percent, resolve_alignment, RenderResult,
};
use crate::control::CellControl;
use crate::grid::VolvoxGrid;
use crate::proto::volvoxgrid::v1 as pb;
use crate::sort::sort_order_is_ascending;
use unicode_width::{UnicodeWidthChar, UnicodeWidthStr};

pub const TUI_ATTR_BOLD: u8 = 1;
pub const TUI_ATTR_ITALIC: u8 = 1 << 1;
pub const TUI_ATTR_UNDERLINE: u8 = 1 << 2;
pub const TUI_ATTR_REVERSE: u8 = 1 << 3;
pub const TUI_COLOR_RESET: u32 = 0x0100_0000;
pub const TUI_COLOR_RESET_BG: u32 = TUI_COLOR_RESET;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum TuiBackgroundMode {
    #[default]
    Opaque,
    Transparent,
}

#[repr(C, packed)]
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct TuiCell {
    pub codepoint: u32,
    pub fg: u32,
    pub bg: u32,
    pub attr: u8,
}

impl TuiCell {
    pub const CONTINUATION: u32 = 0;

    pub const fn new(ch: char, fg: u32, bg: u32, attr: u8) -> Self {
        Self {
            codepoint: ch as u32,
            fg,
            bg,
            attr,
        }
    }

    pub const fn continuation(fg: u32, bg: u32, attr: u8) -> Self {
        Self {
            codepoint: Self::CONTINUATION,
            fg,
            bg,
            attr,
        }
    }

    pub fn ch(self) -> char {
        char::from_u32(self.codepoint).unwrap_or(' ')
    }

    pub fn is_continuation(self) -> bool {
        self.codepoint == Self::CONTINUATION
    }
}

#[derive(Clone, Copy, Debug, Default)]
pub struct TuiRenderer {
    background_mode: TuiBackgroundMode,
}

#[derive(Clone, Copy, Debug, Default, PartialEq)]
pub struct TuiScrollbarGeometry {
    pub visible: bool,
    pub scrollbar_col: i32,
    pub track_start_row: i32,
    pub track_rows: i32,
    pub fixed_data_rows: i32,
    pub scroll_rows: i32,
    pub thumb_start: i32,
    pub thumb_size: i32,
    pub thumb_range: i32,
    pub max_scroll_y: f32,
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct TuiMouseXTranslation {
    pub hit_test_x: i32,
    pub col: i32,
    pub x_in_cell: i32,
    pub cell_width: i32,
}

#[derive(Clone, Copy, Debug, Default, Eq, PartialEq)]
pub struct TuiDropdownPopupGeometry {
    pub x: i32,
    pub y: i32,
    pub width: i32,
    pub height: i32,
    pub visible_count: i32,
    pub start: i32,
}

impl TuiRenderer {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn set_background_mode(&mut self, background_mode: TuiBackgroundMode) {
        self.background_mode = background_mode;
    }

    pub fn background_mode(&self) -> TuiBackgroundMode {
        self.background_mode
    }

    pub fn render(
        &mut self,
        grid: &mut VolvoxGrid,
        buffer: &mut [TuiCell],
        width: i32,
        height: i32,
        stride_cells: usize,
    ) -> RenderResult {
        render_grid_tui_with_background_mode(
            grid,
            buffer,
            width,
            height,
            stride_cells,
            self.background_mode,
        )
    }
}

#[derive(Clone, Copy, Debug)]
struct RenderColumn {
    col: i32,
    x: i32,
    width: i32,
    full_width: i32,
    crop: i32,
}

#[derive(Clone, Copy, Debug, Default)]
struct OutlineState {
    has_subtotal_nodes: bool,
    subtotal_level_floor: i32,
}

struct Surface<'a> {
    buffer: &'a mut [TuiCell],
    width: i32,
    height: i32,
    stride: usize,
}

impl<'a> Surface<'a> {
    fn new(buffer: &'a mut [TuiCell], width: i32, height: i32, stride: usize) -> Self {
        Self {
            buffer,
            width,
            height,
            stride,
        }
    }

    fn clear(&mut self, fg: u32, bg: u32) {
        let blank = TuiCell::new(' ', fg, bg, 0);
        for y in 0..self.height.max(0) {
            for x in 0..self.width.max(0) {
                self.put_cell(x, y, blank);
            }
        }
    }

    fn fill_row(&mut self, y: i32, fg: u32, bg: u32, attr: u8) {
        for x in 0..self.width.max(0) {
            self.put(x, y, ' ', fg, bg, attr);
        }
    }

    fn fill_span(&mut self, x: i32, y: i32, width: i32, fg: u32, bg: u32, attr: u8) {
        for dx in 0..width.max(0) {
            self.put(x + dx, y, ' ', fg, bg, attr);
        }
    }

    fn put(&mut self, x: i32, y: i32, ch: char, fg: u32, bg: u32, attr: u8) {
        self.put_cell(x, y, TuiCell::new(ch, fg, bg, attr));
    }

    fn put_cell(&mut self, x: i32, y: i32, cell: TuiCell) {
        if x < 0 || y < 0 || x >= self.width || y >= self.height {
            return;
        }
        let index = y as usize * self.stride + x as usize;
        if let Some(slot) = self.buffer.get_mut(index) {
            *slot = cell;
        }
    }

    fn get(&self, x: i32, y: i32) -> Option<TuiCell> {
        if x < 0 || y < 0 || x >= self.width || y >= self.height {
            return None;
        }
        self.buffer
            .get(y as usize * self.stride + x as usize)
            .copied()
    }
}

pub fn render_grid_tui(
    grid: &mut VolvoxGrid,
    buffer: &mut [TuiCell],
    width: i32,
    height: i32,
    stride_cells: usize,
) -> RenderResult {
    render_grid_tui_with_background_mode(
        grid,
        buffer,
        width,
        height,
        stride_cells,
        TuiBackgroundMode::Opaque,
    )
}

pub fn render_grid_tui_with_background_mode(
    grid: &mut VolvoxGrid,
    buffer: &mut [TuiCell],
    width: i32,
    height: i32,
    stride_cells: usize,
    background_mode: TuiBackgroundMode,
) -> RenderResult {
    if width <= 0 || height <= 0 {
        return ((0, 0, 0, 0), [0.0; layer::COUNT], [0; 4]);
    }
    let required = stride_cells.saturating_mul(height as usize);
    if stride_cells < width as usize || buffer.len() < required {
        return ((0, 0, 0, 0), [0.0; layer::COUNT], [0; 4]);
    }

    grid.ensure_layout();

    let default_fg = resolve_tui_terminal_color(background_mode, grid.style.fore_color);
    let default_bg = resolve_tui_canvas_bg(grid, background_mode);
    let mut surface = Surface::new(buffer, width, height, stride_cells);
    surface.clear(default_fg, default_bg);

    let row_indicator_width = resolve_row_indicator_width(grid);
    let show_scrollbar = tui_show_scrollbar(grid, width, height, row_indicator_width);
    let content_x = row_indicator_width;
    let content_width = (width - content_x - if show_scrollbar { 1 } else { 0 }).max(0);
    let columns = collect_columns(grid, content_x, content_width);
    let rows = collect_visible_rows(grid, height);
    let outline_state = outline_state(grid);

    render_header_row(
        grid,
        &mut surface,
        &columns,
        row_indicator_width,
        background_mode,
    );
    render_data_rows(
        grid,
        &mut surface,
        &columns,
        &rows,
        row_indicator_width,
        outline_state,
        background_mode,
    );
    render_active_dropdown_popup(grid, &mut surface, &columns, &rows, background_mode);
    if show_scrollbar {
        render_scrollbar(grid, &mut surface, width, height, background_mode);
    }

    (
        (0, 0, width, height),
        [0.0; layer::COUNT],
        [0, rows.len() as u32, columns.len() as u32, 0],
    )
}

fn tui_show_scrollbar(
    grid: &VolvoxGrid,
    width: i32,
    height: i32,
    row_indicator_width: i32,
) -> bool {
    width > row_indicator_width + 1
        && height > 1
        && grid.first_scrollable_row() < grid.rows
        && grid.scroll.max_scroll_y > 0.0
}

pub fn tui_row_indicator_width(grid: &VolvoxGrid) -> i32 {
    resolve_row_indicator_width(grid)
}

pub fn compute_tui_scrollbar_geometry(
    grid: &mut VolvoxGrid,
    width: i32,
    height: i32,
) -> TuiScrollbarGeometry {
    grid.ensure_layout();

    let track_start_row = 1;
    let track_rows = (height - track_start_row).max(0);
    let mut geometry = TuiScrollbarGeometry {
        scrollbar_col: width - 1,
        track_start_row,
        track_rows,
        max_scroll_y: grid.scroll.max_scroll_y,
        ..Default::default()
    };

    let row_indicator_width = resolve_row_indicator_width(grid);
    if !tui_show_scrollbar(grid, width, height, row_indicator_width) {
        return geometry;
    }

    let first_scrollable_row = grid.first_scrollable_row().clamp(0, grid.rows);
    let total_rows = (grid.rows - first_scrollable_row).max(0);
    if total_rows <= 0 {
        return geometry;
    }

    geometry.visible = true;
    geometry.fixed_data_rows = grid.frozen_rows.max(0).min(track_rows);
    geometry.scroll_rows = (track_rows - geometry.fixed_data_rows).max(0);

    let effective_scroll_rows = geometry.scroll_rows.max(1);
    geometry.thumb_size = if total_rows <= effective_scroll_rows {
        effective_scroll_rows
    } else {
        ((effective_scroll_rows * effective_scroll_rows) / total_rows).max(1)
    };
    let top_row = grid
        .layout
        .visible_rows(
            grid.scroll.scroll_y,
            effective_scroll_rows,
            first_scrollable_row,
        )
        .0
        .clamp(first_scrollable_row, grid.rows.saturating_sub(1));
    let scrollable_extent = (total_rows - effective_scroll_rows).max(1);
    geometry.thumb_range = (effective_scroll_rows - geometry.thumb_size).max(0);
    geometry.thumb_start =
        ((top_row - first_scrollable_row) * geometry.thumb_range) / scrollable_extent;
    geometry
}

pub fn compute_tui_dropdown_popup_geometry(
    grid: &VolvoxGrid,
    width: i32,
    height: i32,
) -> Option<TuiDropdownPopupGeometry> {
    if width <= 0 || height <= 0 || grid.host_dropdown_overlay || !grid.edit.is_active() {
        return None;
    }

    let row = grid.edit.edit_row;
    let col = grid.edit.edit_col;
    if row < 0 || col < 0 {
        return None;
    }

    let list = grid.active_dropdown_list(row, col);
    if list.is_empty() {
        return None;
    }

    let row_indicator_width = resolve_row_indicator_width(grid);
    let show_scrollbar = tui_show_scrollbar(grid, width, height, row_indicator_width);
    let content_x = row_indicator_width;
    let content_width = (width - content_x - if show_scrollbar { 1 } else { 0 }).max(0);
    if content_width <= 0 {
        return None;
    }

    let columns = collect_columns(grid, content_x, content_width);
    let rows = collect_visible_rows(grid, height);
    let column = columns.iter().find(|candidate| candidate.col == col)?;
    let row_slot = rows.iter().position(|candidate| *candidate == row)? as i32;

    let count = grid.edit.dropdown_count().max(0);
    if count <= 0 {
        return None;
    }

    let longest_item = (0..count)
        .map(|index| UnicodeWidthStr::width(grid.edit.get_dropdown_item(index)))
        .max()
        .unwrap_or(0) as i32;
    let popup_width = (column.width.max(longest_item + 2) + 2).min(width.max(0));
    if popup_width <= 2 {
        return None;
    }

    let visible_capacity = (height - 2).max(1);
    let visible_count = count.min(visible_capacity.min(8));
    let popup_height = visible_count + 2;
    let cell_y = row_slot + 1;
    let popup_x = column.x.min((width - popup_width).max(0)).max(0);
    let mut popup_y = cell_y + 1;

    if popup_y + popup_height > height {
        popup_y = cell_y - popup_height + 1;
    }
    if popup_y < 1 {
        popup_y = 1;
    }
    if popup_y + popup_height > height {
        popup_y = (height - popup_height).max(0);
    }

    let selected = grid.edit.dropdown_index;
    let mut start = 0;
    if selected >= visible_count {
        start = selected - visible_count + 1;
    }
    let max_start = (count - visible_count).max(0);
    if start > max_start {
        start = max_start;
    }

    Some(TuiDropdownPopupGeometry {
        x: popup_x,
        y: popup_y,
        width: popup_width,
        height: popup_height,
        visible_count,
        start,
    })
}

pub fn tui_dropdown_hit_index(
    grid: &VolvoxGrid,
    width: i32,
    height: i32,
    x: i32,
    y: i32,
) -> Option<i32> {
    let popup = compute_tui_dropdown_popup_geometry(grid, width, height)?;
    if x <= popup.x
        || x >= popup.x + popup.width - 1
        || y <= popup.y
        || y >= popup.y + popup.height - 1
    {
        return None;
    }

    let slot = y - popup.y - 1;
    if slot < 0 || slot >= popup.visible_count {
        return None;
    }

    let idx = popup.start + slot;
    let count = grid.edit.dropdown_count().max(0);
    if idx >= 0 && idx < count {
        Some(idx)
    } else {
        None
    }
}

pub fn translate_tui_mouse_x(
    grid: &mut VolvoxGrid,
    viewport_width: i32,
    viewport_height: i32,
    x: i32,
) -> i32 {
    translate_tui_mouse_x_for_hit(grid, viewport_width, viewport_height, x).hit_test_x
}

pub fn translate_tui_mouse_x_for_hit(
    grid: &mut VolvoxGrid,
    viewport_width: i32,
    viewport_height: i32,
    x: i32,
) -> TuiMouseXTranslation {
    let fallback = TuiMouseXTranslation {
        hit_test_x: x,
        col: -1,
        x_in_cell: 0,
        cell_width: 0,
    };
    if x < 0 || viewport_width <= 0 {
        return fallback;
    }

    grid.ensure_layout();

    let rendered_indicator_width = tui_row_indicator_width(grid);
    if rendered_indicator_width > 0 && x < rendered_indicator_width {
        return fallback;
    }

    let show_scrollbar = tui_show_scrollbar(
        grid,
        viewport_width,
        viewport_height,
        rendered_indicator_width,
    );
    if show_scrollbar && x >= viewport_width - 1 {
        return TuiMouseXTranslation {
            hit_test_x: viewport_width - 1,
            ..fallback
        };
    }

    let content_x = rendered_indicator_width;
    let content_width = (viewport_width - content_x - if show_scrollbar { 1 } else { 0 }).max(0);
    if content_width <= 0 || x < content_x {
        return fallback;
    }

    let columns = collect_columns(grid, content_x, content_width);
    let virtual_data_x = rendered_indicator_width;
    let fixed_col_end = (grid.fixed_cols + grid.frozen_cols).clamp(0, grid.cols);
    let scroll_x = grid.scroll.scroll_x as i32;
    let pinned_left_w = grid.pinned_left_width();
    let hit_test_x_for_effective_x = |col: i32, effective_x: i32| -> i32 {
        let local_x = if col < fixed_col_end {
            effective_x
        } else {
            effective_x - scroll_x + pinned_left_w
        };
        virtual_data_x + local_x
    };
    for (index, column) in columns.iter().enumerate() {
        if x >= column.x && x < column.x + column.width {
            let local_x = x - column.x;
            let source_visible_width = (grid.col_width(column.col).max(1) - column.crop).max(1);
            let logical_local_x = local_x.min(source_visible_width - 1);
            let effective_x = grid.layout.col_pos(column.col) + column.crop + logical_local_x;
            return TuiMouseXTranslation {
                hit_test_x: hit_test_x_for_effective_x(column.col, effective_x),
                col: column.col,
                x_in_cell: column.crop + local_x,
                cell_width: column.full_width.max(column.width),
            };
        }

        if let Some(next) = columns.get(index + 1) {
            let separator_x = column.x + column.width;
            if x == separator_x {
                let boundary_x = grid.layout.col_pos(next.col);
                return TuiMouseXTranslation {
                    hit_test_x: hit_test_x_for_effective_x(next.col, boundary_x),
                    col: next.col,
                    x_in_cell: next.crop,
                    cell_width: next.full_width.max(next.width),
                };
            }

            if x > separator_x && x < next.x {
                return TuiMouseXTranslation {
                    hit_test_x: hit_test_x_for_effective_x(next.col, grid.layout.col_pos(next.col)),
                    col: next.col,
                    x_in_cell: next.crop,
                    cell_width: next.full_width.max(next.width),
                };
            }
        }
    }

    fallback
}

pub fn tui_caret_index_from_display_click(
    grid: &VolvoxGrid,
    row: i32,
    col: i32,
    x_in_cell: i32,
    cell_width: i32,
) -> i32 {
    if row < 0 || row >= grid.rows || col < 0 || col >= grid.cols || cell_width <= 0 {
        return 0;
    }

    let text = grid.get_display_text(row, col);
    if text.is_empty() {
        return 0;
    }

    let style = grid.get_cell_style(row, col);
    let (halign, _) = alignment_components(resolve_alignment(grid, row, col, &style, ""));
    let show_dropdown = grid.resolved_cell_control(row, col) == CellControl::DropdownButton;
    let text_column = text_render_column(
        RenderColumn {
            col,
            x: 0,
            width: cell_width,
            full_width: cell_width,
            crop: 0,
        },
        show_dropdown,
    );
    let text_width = text_column.full_width.max(1);
    let x = x_in_cell.clamp(0, text_width - 1);
    caret_index_for_tui_text(&text, x, text_width, halign)
}

fn collect_columns(grid: &VolvoxGrid, start_x: i32, content_width: i32) -> Vec<RenderColumn> {
    if content_width <= 0 {
        return Vec::new();
    }

    let fixed_col_end = (grid.fixed_cols + grid.frozen_cols).clamp(0, grid.cols);
    let mut columns = Vec::new();
    let mut x = start_x;
    let content_right = start_x + content_width;

    for col in 0..fixed_col_end {
        if x >= content_right || grid.is_col_hidden(col) {
            continue;
        }
        let full_width = grid.col_width(col).max(1);
        let width = full_width.min(content_right - x);
        columns.push(RenderColumn {
            col,
            x,
            width,
            full_width,
            crop: 0,
        });
        x += width;
        if x < content_right {
            x += 1;
        }
    }

    if x >= content_right || fixed_col_end >= grid.cols {
        if grid.is_tui_mode() && grid.scroll.scroll_x <= 0.0 {
            expand_columns_to_fill(&mut columns, content_right);
        }
        return columns;
    }

    let scroll_window = (content_right - x).max(0);
    if scroll_window <= 0 {
        return columns;
    }

    let first_scrollable_col = fixed_col_end;
    let (first_visible_col, _) =
        grid.layout
            .visible_cols(grid.scroll.scroll_x, scroll_window, first_scrollable_col);
    let mut col = first_visible_col.clamp(first_scrollable_col, grid.cols - 1);
    let mut crop = (grid.scroll.scroll_x.round() as i32 - grid.layout.col_pos(col)).max(0);

    while col < grid.cols && x < content_right {
        if grid.is_col_hidden(col) {
            col += 1;
            continue;
        }
        let full_width = grid.col_width(col).max(1);
        let visible_width = (full_width - crop).max(0).min(content_right - x);
        if visible_width > 0 {
            columns.push(RenderColumn {
                col,
                x,
                width: visible_width,
                full_width,
                crop,
            });
            x += visible_width;
            if x < content_right {
                x += 1;
            }
        }
        col += 1;
        crop = 0;
    }

    if grid.is_tui_mode() && grid.scroll.scroll_x <= 0.0 && col >= grid.cols {
        expand_columns_to_fill(&mut columns, content_right);
    }

    columns
}

fn expand_columns_to_fill(columns: &mut [RenderColumn], content_right: i32) {
    if columns.is_empty() {
        return;
    }

    let start_x = columns[0].x;
    let separator_cells = columns.len().saturating_sub(1) as i32;
    let used_width: i32 = columns
        .iter()
        .map(|column| column.width.max(0))
        .sum::<i32>()
        + separator_cells;
    let extra = content_right - start_x - used_width;
    if extra <= 0 {
        return;
    }

    let total_weight: i32 = columns.iter().map(|column| column.full_width.max(1)).sum();
    if total_weight <= 0 {
        return;
    }

    let mut remaining_extra = extra;
    let mut remaining_weight = total_weight;
    for column in columns.iter_mut() {
        let weight = column.full_width.max(1);
        let add = if remaining_weight <= weight {
            remaining_extra
        } else {
            (remaining_extra * weight) / remaining_weight
        };
        column.width += add;
        column.full_width = column.full_width.max(column.width);
        remaining_extra -= add;
        remaining_weight -= weight;
    }

    let mut x = start_x;
    for column in columns.iter_mut() {
        column.x = x;
        x += column.width;
        if x < content_right {
            x += 1;
        }
    }
}

fn collect_visible_rows(grid: &VolvoxGrid, height: i32) -> Vec<i32> {
    if height <= 1 {
        return Vec::new();
    }

    let fixed_row_end = (grid.fixed_rows + grid.frozen_rows).clamp(0, grid.rows);
    let mut rows = Vec::new();
    for row in grid.fixed_rows.clamp(0, grid.rows)..fixed_row_end {
        if !grid.is_row_hidden(row) {
            rows.push(row);
        }
    }

    let available_scroll_rows = (height - 1 - rows.len() as i32).max(0);
    let first_scrollable_row = grid.first_scrollable_row().clamp(0, grid.rows);
    if available_scroll_rows > 0 && first_scrollable_row < grid.rows {
        let (first_visible_row, _) = grid.layout.visible_rows(
            grid.scroll.scroll_y,
            available_scroll_rows,
            first_scrollable_row,
        );
        let mut row = first_visible_row.clamp(first_scrollable_row, grid.rows - 1);
        while row < grid.rows && rows.len() < (height - 1) as usize {
            if !grid.is_row_hidden(row) {
                rows.push(row);
            }
            row += 1;
        }
    }

    rows
}

fn resolve_row_indicator_width(grid: &VolvoxGrid) -> i32 {
    let band = &grid.indicator_bands.row_start;
    if !band.visible {
        return 0;
    }

    if !band.slots.is_empty() {
        let slots = band.slots.iter().filter(|slot| slot.visible).count().max(1) as i32;
        return (slots * 3 + 1).clamp(2, 12);
    }

    let mut width = 2;
    if band.has_mode(pb::RowIndicatorMode::RowIndicatorNumbers) {
        width = ((grid.rows - grid.fixed_rows).max(1).to_string().len() as i32 + 1).clamp(3, 10);
    }
    if band.has_mode(pb::RowIndicatorMode::RowIndicatorCurrent)
        || band.has_mode(pb::RowIndicatorMode::RowIndicatorSelection)
        || band.has_mode(pb::RowIndicatorMode::RowIndicatorCheckbox)
        || band.has_mode(pb::RowIndicatorMode::RowIndicatorEditing)
        || band.has_mode(pb::RowIndicatorMode::RowIndicatorExpander)
    {
        width = width.max(4);
    }
    width.max(2)
}

fn outline_state(grid: &VolvoxGrid) -> OutlineState {
    OutlineState {
        has_subtotal_nodes: grid.row_props.values().any(|rp| rp.is_subtotal),
        subtotal_level_floor: first_subtotal_level(grid),
    }
}

fn render_header_row(
    grid: &VolvoxGrid,
    surface: &mut Surface<'_>,
    columns: &[RenderColumn],
    row_indicator_width: i32,
    background_mode: TuiBackgroundMode,
) {
    let fixed_fg = resolve_tui_terminal_color(background_mode, grid.style.fore_color_fixed);
    let fixed_bg = resolve_tui_terminal_color(background_mode, grid.style.back_color_fixed);
    surface.fill_row(0, fixed_fg, fixed_bg, TUI_ATTR_BOLD);

    if row_indicator_width > 0 {
        let band_bg = row_indicator_back_color(grid, background_mode);
        let band_fg = row_indicator_fore_color(grid, background_mode);
        surface.fill_span(
            0,
            0,
            row_indicator_width.saturating_sub(1),
            band_fg,
            band_bg,
            0,
        );
        surface.put(
            row_indicator_width - 1,
            0,
            '║',
            resolve_tui_terminal_color(background_mode, grid.style.grid_color_fixed),
            band_bg,
            TUI_ATTR_BOLD,
        );
    }

    for (index, column) in columns.iter().enumerate() {
        let highlighted = should_highlight_col_indicator(grid, column.col);
        let (fg, bg, mut attr) = if highlighted {
            (
                rgb24(selection_fore_color(grid)),
                rgb24(selection_back_color(grid)),
                TUI_ATTR_BOLD | TUI_ATTR_REVERSE,
            )
        } else {
            (fixed_fg, fixed_bg, TUI_ATTR_BOLD)
        };

        if column.col < grid.fixed_cols + grid.frozen_cols {
            attr |= TUI_ATTR_UNDERLINE;
        }

        let mut label = grid.column_header_text(column.col);
        if let Some(order) = grid
            .sort_state
            .sort_keys
            .iter()
            .find_map(|&(sort_col, sort_order)| (sort_col == column.col).then_some(sort_order))
        {
            if !label.is_empty() {
                label.push(' ');
            }
            label.push(if sort_order_is_ascending(order) {
                '▲'
            } else {
                '▼'
            });
        }

        write_cell_text(surface, *column, 0, &label, fg, bg, attr, 0);

        if let Some(next) = columns.get(index + 1) {
            let sep_x = column.x + column.width;
            if sep_x < surface.width {
                let sep = if column.col < grid.fixed_cols + grid.frozen_cols
                    && next.col >= grid.fixed_cols + grid.frozen_cols
                {
                    '║'
                } else {
                    '│'
                };
                surface.put(
                    sep_x,
                    0,
                    sep,
                    resolve_tui_terminal_color(background_mode, grid.style.grid_color_fixed),
                    bg,
                    TUI_ATTR_BOLD,
                );
            }
        }
    }
}

fn render_data_rows(
    grid: &VolvoxGrid,
    surface: &mut Surface<'_>,
    columns: &[RenderColumn],
    rows: &[i32],
    row_indicator_width: i32,
    outline_state: OutlineState,
    background_mode: TuiBackgroundMode,
) {
    if rows.is_empty() || columns.is_empty() {
        return;
    }

    for (index, &row) in rows.iter().enumerate() {
        let y = index as i32 + 1;
        if y >= surface.height {
            break;
        }
        if row_indicator_width > 0 {
            render_row_indicator_row(grid, surface, row, y, row_indicator_width, background_mode);
        }
        render_data_row(
            grid,
            surface,
            columns,
            rows,
            row,
            y,
            outline_state,
            background_mode,
        );
    }
}

fn render_data_row(
    grid: &VolvoxGrid,
    surface: &mut Surface<'_>,
    columns: &[RenderColumn],
    visible_rows: &[i32],
    row: i32,
    y: i32,
    outline_state: OutlineState,
    background_mode: TuiBackgroundMode,
) {
    let fixed_col_end = (grid.fixed_cols + grid.frozen_cols).clamp(0, grid.cols);
    let mut covered_until = -1;
    for (index, column) in columns.iter().enumerate() {
        if column.col <= covered_until {
            continue;
        }

        let mut render_column = *column;
        let mut style_row = row;
        let mut style_col = render_column.col;
        let mut merge_rows = None;
        if let Some((mr1, mc1, _mr2, mc2)) = grid.get_merged_range(row, column.col) {
            if column.col > mc1 && column.col <= mc2 {
                continue;
            }
            if column.col == mc1 {
                render_column = merged_render_column(grid, columns, index, mc1, mc2);
                covered_until = mc2;
            }
            style_row = mr1;
            style_col = mc1;
            merge_rows = Some((mr1, _mr2));
        }

        let style = grid.get_cell_style(style_row, style_col);
        let (halign, valign) =
            alignment_components(resolve_alignment(grid, style_row, style_col, &style, ""));
        let show_text = merge_rows.map_or(true, |(mr1, mr2)| {
            row == merged_text_row(visible_rows, mr1, mr2, valign)
        });
        let is_editing = show_text
            && grid.edit.is_active()
            && grid.edit.edit_row == style_row
            && grid.edit.edit_col == style_col;
        let is_selected = should_highlight_cell(grid, style_row, style_col) && !is_editing;
        let is_active =
            show_text && style_row == grid.selection.row && style_col == grid.selection.col;
        let is_fixed = style_row < grid.fixed_rows || style_col < grid.fixed_cols;
        let is_frozen = style_row < grid.fixed_rows + grid.frozen_rows || style_col < fixed_col_end;
        let is_alternate = style_row >= grid.fixed_rows && (style_row - grid.fixed_rows) % 2 != 0;
        let mut fg = resolve_tui_cell_fg(
            grid,
            &style,
            is_fixed,
            is_frozen,
            is_selected,
            background_mode,
        );
        let mut bg = resolve_tui_cell_bg(
            grid,
            &style,
            is_fixed,
            is_frozen,
            is_selected,
            is_alternate,
            background_mode,
        );
        let mut attr = style_attr(grid, &style, is_selected);

        if is_active && !is_editing {
            if let Some(active_fg) = grid.selection.active_cell_style.fore_color {
                fg = rgb24(active_fg);
            }
            if let Some(active_bg) = grid.selection.active_cell_style.back_color {
                bg = rgb24(active_bg);
            }
            attr |= TUI_ATTR_REVERSE;
        }

        if grid
            .get_row_props(style_row)
            .map_or(false, |rp| rp.is_subtotal)
        {
            attr |= TUI_ATTR_BOLD;
        }
        if grid.resolved_cell_interaction(style_row, style_col)
            == pb::CellInteraction::TextLink as i32
        {
            attr |= TUI_ATTR_UNDERLINE;
        }

        let mut text = if show_text {
            grid.get_display_text(style_row, style_col)
        } else {
            String::new()
        };
        let mut fitted_edit_text = None;
        if is_editing {
            text = grid.edit.edit_text.clone();
            fitted_edit_text = Some(fit_edit_text(
                &text,
                render_column.full_width,
                halign,
                grid.edit.current_caret_char().max(0) as usize,
            ));
        } else {
            let is_boolean_col = grid.get_col_props(style_col).map_or(false, |cp| {
                cp.data_type == pb::ColumnDataType::ColumnDataBoolean as i32
            });
            let checked_state = grid
                .cells
                .get(style_row, style_col)
                .map_or(pb::CheckedState::CheckedUnchecked as i32, |cell| {
                    cell.checked()
                });
            if show_text
                && cell_has_checkbox_visual(
                    grid,
                    style_row,
                    style_col,
                    is_boolean_col,
                    checked_state,
                )
            {
                text = checkbox_glyph(checked_state).to_string();
            } else if show_text {
                let prefix = outline_prefix(grid, style_row, style_col, outline_state);
                if !prefix.is_empty() {
                    text = format!("{prefix}{text}");
                }
            }
        }

        let show_dropdown = show_text
            && !is_editing
            && grid.resolved_cell_control(style_row, style_col) == CellControl::DropdownButton;
        let text_column = text_render_column(render_column, show_dropdown);

        if let Some(fitted) = fitted_edit_text.as_ref() {
            write_fitted_cell_text(surface, text_column, y, &fitted.text, fg, bg, attr);
            write_edit_selection(
                surface,
                text_column,
                y,
                &text,
                fitted.draw_x,
                grid.edit.sel_start,
                grid.edit.sel_length,
                attr | TUI_ATTR_REVERSE,
            );
        } else {
            write_cell_text(surface, text_column, y, &text, fg, bg, attr, halign);
        }
        apply_progress_fill(
            grid,
            surface,
            render_column,
            style_row,
            style_col,
            y,
            &text,
            is_selected,
        );
        if show_dropdown && render_column.width > 0 {
            surface.put(
                render_column.x + render_column.width - 1,
                y,
                '▾',
                fg,
                bg,
                attr,
            );
        }
        if grid.edit.sel_length <= 0 {
            if let Some(fitted) = fitted_edit_text.as_ref() {
                let visible_x = fitted.cursor_x - text_column.crop;
                if visible_x >= 0 && visible_x < text_column.width {
                    let cell_x = text_column.x + visible_x;
                    if let Some(cell) = surface.get(cell_x, y) {
                        surface.put(
                            cell_x,
                            y,
                            cell.ch(),
                            cell.fg,
                            cell.bg,
                            caret_attr(cell.attr),
                        );
                    }
                }
            }
        }

        if is_editing {
            draw_edit_frame(
                surface,
                render_column,
                y,
                resolve_tui_terminal_color(background_mode, grid.style.grid_color),
                bg,
            );
        }

        let next = columns
            .iter()
            .skip(index + 1)
            .find(|next| next.col > covered_until);
        if let Some(next) = next {
            let sep_x = render_column.x + render_column.width;
            if sep_x < surface.width
                && !separator_hidden_by_merge(grid, row, render_column.col, next.col)
            {
                let sep = if is_editing {
                    '┃'
                } else if render_column.col < fixed_col_end && next.col >= fixed_col_end {
                    '║'
                } else {
                    '│'
                };
                surface.put(
                    sep_x,
                    y,
                    sep,
                    resolve_tui_terminal_color(background_mode, grid.style.grid_color),
                    bg,
                    attr & TUI_ATTR_BOLD,
                );
            }
        }
    }
}

fn render_row_indicator_row(
    grid: &VolvoxGrid,
    surface: &mut Surface<'_>,
    row: i32,
    y: i32,
    row_indicator_width: i32,
    background_mode: TuiBackgroundMode,
) {
    if row_indicator_width <= 0 {
        return;
    }

    let selected = should_highlight_row_indicator(grid, row);
    let fg = if selected {
        rgb24(selection_fore_color(grid))
    } else {
        row_indicator_fore_color(grid, background_mode)
    };
    let bg = if selected {
        rgb24(selection_back_color(grid))
    } else {
        row_indicator_back_color(grid, background_mode)
    };
    let attr = if selected {
        TUI_ATTR_BOLD | TUI_ATTR_REVERSE
    } else {
        0
    };
    surface.fill_span(0, y, row_indicator_width.saturating_sub(1), fg, bg, attr);

    let label = row_indicator_label(grid, row);
    if !label.is_empty() && row_indicator_width > 1 {
        write_cell_text(
            surface,
            RenderColumn {
                col: -1,
                x: 0,
                width: row_indicator_width - 1,
                full_width: row_indicator_width - 1,
                crop: 0,
            },
            y,
            &label,
            fg,
            bg,
            attr,
            2,
        );
    }

    surface.put(
        row_indicator_width - 1,
        y,
        '║',
        resolve_tui_terminal_color(background_mode, grid.style.grid_color_fixed),
        bg,
        attr & TUI_ATTR_BOLD,
    );
}

fn merged_render_column(
    grid: &VolvoxGrid,
    columns: &[RenderColumn],
    start_index: usize,
    merge_start: i32,
    merge_end: i32,
) -> RenderColumn {
    let mut merged = columns[start_index];
    let mut right = merged.x + merged.width;
    for next in columns.iter().skip(start_index + 1) {
        if next.col > merge_end {
            break;
        }
        right = next.x + next.width;
    }

    let mut full_width = 0;
    let mut seen = false;
    for col in merge_start..=merge_end {
        if grid.is_col_hidden(col) {
            continue;
        }
        if seen {
            full_width += 1;
        }
        full_width += grid.col_width(col).max(1);
        seen = true;
    }

    merged.width = (right - merged.x).max(merged.width);
    if full_width > 0 {
        merged.full_width = full_width;
    }
    merged
}

fn merged_text_row(visible_rows: &[i32], merge_start: i32, merge_end: i32, valign: i32) -> i32 {
    let merge_end = merge_end.max(merge_start);
    let mut first_idx = None;
    let mut last_idx = 0usize;
    for (index, &visible_row) in visible_rows.iter().enumerate() {
        if visible_row < merge_start {
            continue;
        }
        if visible_row > merge_end {
            break;
        }
        if first_idx.is_none() {
            first_idx = Some(index);
        }
        last_idx = index;
    }

    if let Some(first_idx) = first_idx {
        let target_idx = match valign {
            0 => first_idx,
            2 => last_idx,
            _ => first_idx + (last_idx - first_idx) / 2,
        };
        return visible_rows[target_idx];
    }

    match valign {
        0 => merge_start,
        2 => merge_end,
        _ => merge_start + (merge_end - merge_start) / 2,
    }
}

fn separator_hidden_by_merge(grid: &VolvoxGrid, row: i32, left_col: i32, right_col: i32) -> bool {
    let left = grid.get_merged_range(row, left_col);
    left.is_some() && left == grid.get_merged_range(row, right_col)
}

fn text_render_column(column: RenderColumn, reserve_dropdown: bool) -> RenderColumn {
    if !reserve_dropdown || column.width <= 1 {
        return column;
    }

    let reserve = if column.width >= 3 { 2 } else { 1 };
    let width = column.width.saturating_sub(reserve);
    if width <= 0 {
        return RenderColumn { width: 0, ..column };
    }

    RenderColumn {
        width,
        full_width: column.full_width.saturating_sub(reserve).max(width),
        ..column
    }
}

fn apply_progress_fill(
    grid: &VolvoxGrid,
    surface: &mut Surface<'_>,
    column: RenderColumn,
    row: i32,
    col: i32,
    y: i32,
    text: &str,
    is_selected: bool,
) {
    if is_selected || column.width <= 0 {
        return;
    }

    let Some((percent, color)) = progress_fill_spec(grid, row, col, text) else {
        return;
    };
    let fill = ((column.width as f32) * percent).round() as i32;
    for dx in 0..fill.clamp(0, column.width) {
        if let Some(cell) = surface.get(column.x + dx, y) {
            surface.put(
                column.x + dx,
                y,
                cell.ch(),
                cell.fg,
                rgb24(color),
                cell.attr,
            );
        }
    }
}

fn progress_fill_spec(grid: &VolvoxGrid, row: i32, col: i32, text: &str) -> Option<(f32, u32)> {
    let col_progress = grid.get_col_props(col).map_or(0, |cp| cp.progress_color);
    let cell = grid.cells.get(row, col);

    if let Some(cell) = cell {
        if cell.progress_percent() > 0.0 {
            let color = if cell.progress_color() != 0 {
                cell.progress_color()
            } else if col_progress != 0 {
                col_progress
            } else {
                grid.style.progress_color
            };
            if color != 0 {
                return Some((cell.progress_percent().clamp(0.0, 1.0), color));
            }
        }
    }

    if col_progress != 0 {
        let percent = parse_progress_percent(text).clamp(0.0, 1.0);
        if percent > 0.0 {
            return Some((percent, col_progress));
        }
    }

    None
}

fn outline_prefix(grid: &VolvoxGrid, row: i32, col: i32, outline_state: OutlineState) -> String {
    if grid.outline.tree_indicator == pb::TreeIndicatorStyle::TreeIndicatorNone as i32
        || col != grid.outline.tree_column
        || row < grid.fixed_rows
    {
        return String::new();
    }

    let Some(props) = grid.get_row_props(row) else {
        return String::new();
    };

    if outline_state.has_subtotal_nodes {
        let visual_level = subtotal_visual_level(
            props.outline_level,
            props.is_subtotal,
            outline_state.subtotal_level_floor,
        );
        if props.is_subtotal && visual_level > 0 {
            let mut prefix = "  ".repeat(visual_level.saturating_sub(1) as usize);
            prefix.push(if props.is_collapsed { '▸' } else { '▾' });
            prefix.push(' ');
            return prefix;
        }
        if visual_level > 0 {
            let mut prefix = "  ".repeat(visual_level as usize);
            prefix.push(' ');
            return prefix;
        }
        return String::new();
    }

    if props.outline_level <= 0 {
        return String::new();
    }

    let mut prefix = "  ".repeat(props.outline_level.saturating_sub(1) as usize);
    if row_has_outline_children(grid, row, props.outline_level) {
        prefix.push(if props.is_collapsed { '▸' } else { '▾' });
        prefix.push(' ');
    } else if tree_style_shows_leaf(grid) {
        prefix.push('•');
        prefix.push(' ');
    } else {
        prefix.push_str("  ");
    }
    prefix
}

fn row_has_outline_children(grid: &VolvoxGrid, row: i32, level: i32) -> bool {
    for next_row in (row + 1)..grid.rows {
        let next_level = grid
            .get_row_props(next_row)
            .map_or(0, |rp| rp.outline_level);
        if next_level <= level {
            return false;
        }
        return true;
    }
    false
}

fn tree_style_shows_leaf(grid: &VolvoxGrid) -> bool {
    matches!(
        grid.outline.tree_indicator,
        x if x == pb::TreeIndicatorStyle::TreeIndicatorArrowsLeaf as i32
            || x == pb::TreeIndicatorStyle::TreeIndicatorConnectorsLeaf as i32
    )
}

fn first_subtotal_level(grid: &VolvoxGrid) -> i32 {
    grid.row_props
        .values()
        .filter(|rp| rp.is_subtotal)
        .map(|rp| rp.outline_level)
        .filter(|level| *level > 0)
        .min()
        .unwrap_or(0)
}

fn subtotal_visual_level(level: i32, is_subtotal: bool, subtotal_level_floor: i32) -> i32 {
    if is_subtotal {
        if level < 0 {
            0
        } else {
            (level - subtotal_level_floor + 1).max(1)
        }
    } else {
        (2 - subtotal_level_floor).max(1)
    }
}

fn row_indicator_back_color(grid: &VolvoxGrid, background_mode: TuiBackgroundMode) -> u32 {
    resolve_tui_terminal_color(
        background_mode,
        grid.indicator_bands
            .row_start
            .back_color
            .unwrap_or(grid.style.back_color_fixed),
    )
}

fn row_indicator_fore_color(grid: &VolvoxGrid, background_mode: TuiBackgroundMode) -> u32 {
    resolve_tui_terminal_color(
        background_mode,
        grid.indicator_bands
            .row_start
            .fore_color
            .unwrap_or(grid.style.fore_color_fixed),
    )
}

fn row_indicator_label(grid: &VolvoxGrid, row: i32) -> String {
    let band = &grid.indicator_bands.row_start;
    if band.has_mode(pb::RowIndicatorMode::RowIndicatorNumbers) {
        return (row - grid.fixed_rows + 1).max(1).to_string();
    }

    let mut label = String::new();
    if band.has_mode(pb::RowIndicatorMode::RowIndicatorCurrent) && row == grid.selection.row {
        label.push('▶');
    } else if band.has_mode(pb::RowIndicatorMode::RowIndicatorSelection)
        && should_highlight_row_indicator(grid, row)
    {
        label.push('•');
    }
    if band.has_mode(pb::RowIndicatorMode::RowIndicatorEditing)
        && grid.edit.is_active()
        && grid.edit.edit_row == row
    {
        if !label.is_empty() {
            label.push(' ');
        }
        label.push('✎');
    }
    if band.has_mode(pb::RowIndicatorMode::RowIndicatorExpander) {
        if let Some(props) = grid.get_row_props(row) {
            if !label.is_empty() {
                label.push(' ');
            }
            label.push(if props.is_collapsed { '+' } else { '-' });
        }
    }
    label
}

fn cell_has_checkbox_visual(
    grid: &VolvoxGrid,
    row: i32,
    col: i32,
    is_boolean_col: bool,
    checked_state: i32,
) -> bool {
    row >= grid.fixed_rows
        && row < grid.rows
        && col >= 0
        && col < grid.cols
        && !grid.get_row_props(row).map_or(false, |rp| rp.is_subtotal)
        && (is_boolean_col || checked_state != pb::CheckedState::CheckedUnchecked as i32)
}

fn checkbox_glyph(checked_state: i32) -> &'static str {
    match checked_state {
        x if x == pb::CheckedState::CheckedChecked as i32 => "[x]",
        x if x == pb::CheckedState::CheckedGrayed as i32 => "[-]",
        _ => "[ ]",
    }
}

fn draw_edit_frame(surface: &mut Surface<'_>, column: RenderColumn, y: i32, fg: u32, bg: u32) {
    let left_x = column.x - 1;
    if left_x >= 0 {
        surface.put(left_x, y, '┃', fg, bg, TUI_ATTR_BOLD);
    }

    let right_x = column.x + column.width;
    if right_x >= 0 && right_x < surface.width {
        surface.put(right_x, y, '┃', fg, bg, TUI_ATTR_BOLD);
    }
}

fn caret_attr(attr: u8) -> u8 {
    if attr & TUI_ATTR_REVERSE != 0 {
        attr & !TUI_ATTR_REVERSE
    } else {
        attr | TUI_ATTR_REVERSE
    }
}

#[derive(Clone, Debug, Default, PartialEq, Eq)]
struct FittedEditText {
    text: String,
    cursor_x: i32,
    draw_x: i32,
}

fn fit_edit_text(text: &str, width: i32, halign: i32, cursor_chars: usize) -> FittedEditText {
    if width <= 0 {
        return FittedEditText::default();
    }

    let text_width = UnicodeWidthStr::width(text) as i32;
    let cursor_chars = cursor_chars.min(text.chars().count());
    let caret_x = prefix_width(text, cursor_chars) as i32;
    let mut draw_x = match halign {
        1 => (width - text_width) / 2,
        2 => width - text_width,
        _ => 0,
    };
    let min_caret_x = 0;
    let max_caret_x = width;
    let caret_screen_x = draw_x + caret_x;
    if caret_screen_x < min_caret_x {
        draw_x += min_caret_x - caret_screen_x;
    } else if caret_screen_x > max_caret_x {
        draw_x -= caret_screen_x - max_caret_x;
    }

    let fitted = if draw_x > 0 {
        let mut padded = String::with_capacity(draw_x as usize + text.len());
        padded.push_str(&" ".repeat(draw_x as usize));
        padded.push_str(text);
        display_window(&padded, 0, width)
    } else {
        display_window(text, -draw_x, width)
    };
    let cursor_x = (draw_x + caret_x).clamp(0, width - 1);
    FittedEditText {
        text: fitted,
        cursor_x,
        draw_x,
    }
}

fn write_edit_selection(
    surface: &mut Surface<'_>,
    column: RenderColumn,
    y: i32,
    text: &str,
    draw_x: i32,
    sel_start: i32,
    sel_length: i32,
    selection_attr: u8,
) {
    if sel_length <= 0 || column.width <= 0 {
        return;
    }

    let total_chars = text.chars().count() as i32;
    let start = sel_start.clamp(0, total_chars);
    let end = (start + sel_length).clamp(start, total_chars);
    if end <= start {
        return;
    }

    let mut text_x = 0i32;
    for (index, ch) in text.chars().enumerate() {
        let ch_width = display_width_char(sanitize_char(ch)).max(1) as i32;
        let char_index = index as i32;
        if char_index >= start && char_index < end {
            for dx in 0..ch_width {
                let visible_x = draw_x + text_x + dx - column.crop;
                if visible_x >= 0 && visible_x < column.width {
                    let cell_x = column.x + visible_x;
                    if let Some(cell) = surface.get(cell_x, y) {
                        surface.put(cell_x, y, cell.ch(), cell.fg, cell.bg, selection_attr);
                    }
                }
            }
        }
        text_x += ch_width;
    }
}

fn readable_popup_fg(fg: u32, bg: u32, fallback: u32) -> u32 {
    if fg == bg {
        fallback
    } else {
        fg
    }
}

fn write_cell_text(
    surface: &mut Surface<'_>,
    column: RenderColumn,
    y: i32,
    text: &str,
    fg: u32,
    bg: u32,
    attr: u8,
    halign: i32,
) {
    let fitted = fit_text(text, column.full_width, halign);
    write_fitted_cell_text(surface, column, y, &fitted, fg, bg, attr);
}

fn write_fitted_cell_text(
    surface: &mut Surface<'_>,
    column: RenderColumn,
    y: i32,
    fitted: &str,
    fg: u32,
    bg: u32,
    attr: u8,
) {
    let visible = display_window(fitted, column.crop, column.width);
    write_display_text(surface, column, y, &visible, fg, bg, attr);
}

fn write_display_text(
    surface: &mut Surface<'_>,
    column: RenderColumn,
    y: i32,
    text: &str,
    fg: u32,
    bg: u32,
    attr: u8,
) {
    let mut x = 0i32;
    for ch in text.chars() {
        let ch = sanitize_char(ch);
        let char_width = display_width_char(ch).max(1) as i32;
        if x >= column.width {
            break;
        }
        surface.put(column.x + x, y, ch, fg, bg, attr);
        for dx in 1..char_width {
            if x + dx >= column.width {
                break;
            }
            surface.put_cell(column.x + x + dx, y, TuiCell::continuation(fg, bg, attr));
        }
        x += char_width;
    }
    while x < column.width {
        surface.put(column.x + x, y, ' ', fg, bg, attr);
        x += 1;
    }
}

fn render_scrollbar(
    grid: &mut VolvoxGrid,
    surface: &mut Surface<'_>,
    width: i32,
    height: i32,
    background_mode: TuiBackgroundMode,
) {
    let geometry = compute_tui_scrollbar_geometry(grid, width, height);
    if !geometry.visible {
        return;
    }

    for row in 0..geometry.track_rows {
        let y = geometry.track_start_row + row;
        let relative_scroll_row = row - geometry.fixed_data_rows;
        let ch = if relative_scroll_row >= 0
            && relative_scroll_row >= geometry.thumb_start
            && relative_scroll_row < geometry.thumb_start + geometry.thumb_size
        {
            '█'
        } else {
            '░'
        };
        surface.put(
            geometry.scrollbar_col,
            y,
            ch,
            resolve_tui_terminal_color(background_mode, grid.style.fore_color_fixed),
            resolve_tui_terminal_color(background_mode, grid.style.back_color_fixed),
            0,
        );
    }
}

fn render_active_dropdown_popup(
    grid: &VolvoxGrid,
    surface: &mut Surface<'_>,
    _columns: &[RenderColumn],
    _rows: &[i32],
    _background_mode: TuiBackgroundMode,
) {
    let Some(popup) = compute_tui_dropdown_popup_geometry(grid, surface.width, surface.height)
    else {
        return;
    };

    let selected = grid.edit.dropdown_index;
    let col = grid.edit.edit_col;

    let body_bg = rgb24(grid.style.back_color_bkg);
    let body_fg = readable_popup_fg(
        rgb24(grid.style.fore_color),
        body_bg,
        rgb24(grid.style.fore_color_fixed),
    );
    let border_fg = readable_popup_fg(rgb24(grid.style.fore_color_fixed), body_bg, body_fg);
    let border_bg = body_bg;
    let selected_fg = readable_popup_fg(
        rgb24(selection_fore_color(grid)),
        rgb24(selection_back_color(grid)),
        body_fg,
    );
    let selected_bg = rgb24(selection_back_color(grid));

    for dx in 1..popup.width - 1 {
        surface.put(popup.x + dx, popup.y, '─', border_fg, body_bg, 0);
        surface.put(
            popup.x + dx,
            popup.y + popup.height - 1,
            '─',
            border_fg,
            body_bg,
            0,
        );
    }
    surface.put(popup.x, popup.y, '┌', border_fg, body_bg, 0);
    surface.put(
        popup.x + popup.width - 1,
        popup.y,
        '┐',
        border_fg,
        body_bg,
        0,
    );
    surface.put(
        popup.x,
        popup.y + popup.height - 1,
        '└',
        border_fg,
        body_bg,
        0,
    );
    surface.put(
        popup.x + popup.width - 1,
        popup.y + popup.height - 1,
        '┘',
        border_fg,
        body_bg,
        0,
    );

    for slot in 0..popup.visible_count {
        let item_index = popup.start + slot;
        let y = popup.y + 1 + slot;
        let selected_item = item_index == selected;
        let fg = if selected_item { selected_fg } else { body_fg };
        let bg = if selected_item { selected_bg } else { body_bg };
        surface.put(popup.x, y, '│', border_fg, bg, 0);
        surface.put(popup.x + popup.width - 1, y, '│', border_fg, bg, 0);
        for dx in 1..popup.width - 1 {
            surface.put(popup.x + dx, y, ' ', fg, bg, 0);
        }
        write_cell_text(
            surface,
            RenderColumn {
                col,
                x: popup.x + 1,
                width: popup.width - 2,
                full_width: popup.width - 2,
                crop: 0,
            },
            y,
            grid.edit.get_dropdown_item(item_index),
            fg,
            bg,
            0,
            0,
        );
    }

    if popup.x > 0 {
        surface.put(popup.x - 1, popup.y, ' ', border_fg, border_bg, 0);
    }
}

fn should_highlight_cell(grid: &VolvoxGrid, row: i32, col: i32) -> bool {
    if grid.render_layer_mask & (1u64 << layer::SELECTION) == 0 {
        return false;
    }
    if row < grid.fixed_rows || col < grid.fixed_cols {
        return false;
    }
    if !selection_highlight_active(grid) {
        return false;
    }
    if grid.selection.mode == pb::SelectionMode::SelectionListbox as i32 {
        return row == grid.selection.row || grid.selection.selected_rows.contains(&row);
    }
    grid.is_cell_selected(row, col)
}

fn should_highlight_row_indicator(grid: &VolvoxGrid, row: i32) -> bool {
    if grid.render_layer_mask & (1u64 << layer::SELECTION) == 0 {
        return false;
    }
    if grid.selection.mode == pb::SelectionMode::SelectionListbox as i32 {
        if row == grid.selection.row {
            return true;
        }
        return selection_highlight_active(grid) && grid.selection.selected_rows.contains(&row);
    }
    if !selection_highlight_active(grid) {
        return false;
    }
    if grid.selection.mode == pb::SelectionMode::SelectionByColumn as i32 {
        return false;
    }
    grid.selection
        .all_ranges(grid.rows, grid.cols)
        .iter()
        .any(|&(row_lo, _, row_hi, _)| row >= row_lo && row <= row_hi)
}

fn should_highlight_col_indicator(grid: &VolvoxGrid, col: i32) -> bool {
    if grid.render_layer_mask & (1u64 << layer::SELECTION) == 0 {
        return false;
    }
    if !selection_highlight_active(grid) {
        return false;
    }
    if grid.selection.mode == pb::SelectionMode::SelectionByRow as i32
        || grid.selection.mode == pb::SelectionMode::SelectionListbox as i32
    {
        return false;
    }
    grid.selection
        .all_ranges(grid.rows, grid.cols)
        .iter()
        .any(|&(_, col_lo, _, col_hi)| col >= col_lo && col <= col_hi)
}

fn selection_highlight_active(grid: &VolvoxGrid) -> bool {
    match grid.selection.selection_visibility {
        v if v == pb::SelectionVisibility::SelectionVisAlways as i32 => true,
        v if v == pb::SelectionVisibility::SelectionVisWhenFocused as i32 => grid.has_focus,
        _ => false,
    }
}

fn selection_back_color(grid: &VolvoxGrid) -> u32 {
    grid.selection
        .selection_style
        .back_color
        .unwrap_or(0xFF000080)
}

fn selection_fore_color(grid: &VolvoxGrid) -> u32 {
    grid.selection
        .selection_style
        .fore_color
        .unwrap_or(0xFFFFFFFF)
}

fn resolve_tui_canvas_bg(grid: &VolvoxGrid, background_mode: TuiBackgroundMode) -> u32 {
    match background_mode {
        TuiBackgroundMode::Opaque => rgb24(grid.style.back_color_bkg),
        TuiBackgroundMode::Transparent => TUI_COLOR_RESET,
    }
}

fn resolve_tui_terminal_color(background_mode: TuiBackgroundMode, color: u32) -> u32 {
    match background_mode {
        TuiBackgroundMode::Opaque => rgb24(color),
        TuiBackgroundMode::Transparent => TUI_COLOR_RESET,
    }
}

fn resolve_tui_cell_fg(
    grid: &VolvoxGrid,
    style: &crate::style::CellStylePatch,
    is_fixed: bool,
    is_frozen: bool,
    is_selected: bool,
    background_mode: TuiBackgroundMode,
) -> u32 {
    if let Some(color) = style.fore_color {
        return rgb24(color);
    }
    if is_selected {
        return rgb24(selection_fore_color(grid));
    }
    if is_frozen {
        return resolve_tui_terminal_color(background_mode, grid.style.fore_color_frozen);
    }
    if is_fixed {
        return resolve_tui_terminal_color(background_mode, grid.style.fore_color_fixed);
    }
    resolve_tui_terminal_color(background_mode, grid.style.fore_color)
}

fn resolve_tui_cell_bg(
    grid: &VolvoxGrid,
    style: &crate::style::CellStylePatch,
    is_fixed: bool,
    is_frozen: bool,
    is_selected: bool,
    is_alternate: bool,
    background_mode: TuiBackgroundMode,
) -> u32 {
    if let Some(color) = style.back_color {
        return rgb24(color);
    }
    if is_selected {
        return rgb24(selection_back_color(grid));
    }
    if is_alternate && grid.style.back_color_alternate != 0x00000000 {
        return resolve_tui_terminal_color(background_mode, grid.style.back_color_alternate);
    }
    if is_frozen {
        return resolve_tui_terminal_color(background_mode, grid.style.back_color_frozen);
    }
    if is_fixed {
        return resolve_tui_terminal_color(background_mode, grid.style.back_color_fixed);
    }
    resolve_tui_terminal_color(background_mode, grid.style.back_color)
}

fn style_attr(grid: &VolvoxGrid, style: &crate::style::CellStylePatch, is_selected: bool) -> u8 {
    let mut attr = 0;
    if style.font_bold.unwrap_or(grid.style.font_bold) {
        attr |= TUI_ATTR_BOLD;
    }
    if style.font_italic.unwrap_or(grid.style.font_italic) {
        attr |= TUI_ATTR_ITALIC;
    }
    if style.font_underline.unwrap_or(grid.style.font_underline) {
        attr |= TUI_ATTR_UNDERLINE;
    }
    if is_selected {
        attr |= TUI_ATTR_REVERSE;
    }
    attr
}

fn fit_text(text: &str, width: i32, halign: i32) -> String {
    if width <= 0 {
        return String::new();
    }

    let trimmed = truncate_to_width(text, width as usize);
    let text_width = UnicodeWidthStr::width(trimmed.as_str());
    let total_width = width as usize;
    let pad = total_width.saturating_sub(text_width);
    let left_pad = match halign {
        1 => pad / 2,
        2 => pad,
        _ => 0,
    };
    let right_pad = pad.saturating_sub(left_pad);

    let mut out = String::new();
    out.push_str(&" ".repeat(left_pad));
    out.push_str(&trimmed);
    out.push_str(&" ".repeat(right_pad));
    out
}

fn caret_index_for_tui_text(text: &str, x: i32, width: i32, halign: i32) -> i32 {
    if width <= 0 || text.is_empty() {
        return 0;
    }

    let visible_text = truncate_to_width(text, width as usize);
    let text_width = UnicodeWidthStr::width(visible_text.as_str()) as i32;
    if text_width <= 0 {
        return 0;
    }

    let pad = width.saturating_sub(text_width);
    let left_pad = match halign {
        1 => pad / 2,
        2 => pad,
        _ => 0,
    };
    let relative_x = x - left_pad;
    if relative_x <= 0 {
        return 0;
    }
    if relative_x >= text_width {
        return visible_text.chars().count() as i32;
    }

    let mut display_x = 0i32;
    let mut index = 0i32;
    for ch in visible_text.chars() {
        let char_width = display_width_char(ch).max(1) as i32;
        let next_x = display_x + char_width;
        if relative_x < next_x {
            if relative_x - display_x < next_x - relative_x {
                return index;
            }
            return index + 1;
        }
        display_x = next_x;
        index += 1;
    }

    index
}

fn display_window(text: &str, skip: i32, take: i32) -> String {
    if take <= 0 {
        return String::new();
    }
    let skip = skip.max(0) as usize;
    let take = take.max(0) as usize;
    let mut out = String::new();
    let mut display_offset = 0usize;
    let mut written = 0usize;

    for ch in text.chars() {
        let ch = sanitize_char(ch);
        let char_width = display_width_char(ch);
        let next_offset = display_offset + char_width;
        if next_offset <= skip {
            display_offset = next_offset;
            continue;
        }
        if char_width == 0 {
            if display_offset >= skip {
                out.push(ch);
            }
            continue;
        }
        if written >= take {
            break;
        }
        if display_offset < skip || written + char_width > take {
            let partial = (take - written).min(char_width);
            out.push_str(&" ".repeat(partial));
            written += partial;
        } else {
            out.push(ch);
            written += char_width;
        }
        display_offset = next_offset;
    }

    if written < take {
        out.push_str(&" ".repeat(take - written));
    }

    out
}

fn truncate_to_width(text: &str, max_width: usize) -> String {
    let mut out = String::new();
    let mut width = 0usize;
    for ch in text.chars() {
        let ch = sanitize_char(ch);
        let char_width = display_width_char(ch);
        if width + char_width > max_width {
            break;
        }
        out.push(ch);
        width += char_width;
    }
    out
}

fn prefix_width(text: &str, chars: usize) -> usize {
    text.chars()
        .take(chars)
        .map(|ch| display_width_char(sanitize_char(ch)))
        .sum()
}

fn display_width_char(ch: char) -> usize {
    UnicodeWidthChar::width(ch).unwrap_or(0)
}

fn sanitize_char(ch: char) -> char {
    match ch {
        '\0'..='\u{1F}' if ch != ' ' => ' ',
        '\u{7F}' => ' ',
        _ => ch,
    }
}

fn rgb24(argb: u32) -> u32 {
    argb & 0x00FF_FFFF
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::grid::VolvoxGrid;
    use crate::proto::volvoxgrid::v1 as pb;

    fn row_text(buffer: &[TuiCell], stride: usize, row: usize, width: usize) -> String {
        (0..width)
            .filter_map(|col| buffer.get(row * stride + col).copied())
            .map(TuiCell::ch)
            .collect()
    }

    #[test]
    fn tui_cell_layout_is_packed() {
        assert_eq!(std::mem::size_of::<TuiCell>(), 13);
    }

    #[test]
    fn render_grid_tui_renders_headers_and_data() {
        let mut grid = VolvoxGrid::new(1, 18, 4, 3, 2, 1, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.has_focus = true;
        grid.columns[0].caption = "ID".to_string();
        grid.columns[1].caption = "Name".to_string();
        grid.set_col_width(0, 4);
        grid.set_col_width(1, 8);
        grid.cells.set_text(1, 0, "42".to_string());
        grid.cells.set_text(1, 1, "Alice".to_string());
        grid.cells.set_text(2, 0, "7".to_string());
        grid.cells.set_text(2, 1, "Bob".to_string());

        let mut buffer = vec![TuiCell::default(); 18 * 4];
        let result = render_grid_tui(&mut grid, &mut buffer, 18, 4, 18);

        assert_eq!(result.0, (0, 0, 18, 4));
        assert!(row_text(&buffer, 18, 0, 18).contains("ID"));
        assert!(row_text(&buffer, 18, 0, 18).contains("Name"));
        assert!(row_text(&buffer, 18, 1, 18).contains("42"));
        assert!(row_text(&buffer, 18, 1, 18).contains("Alice"));
    }

    #[test]
    fn collect_columns_expands_visible_columns_to_fill_tui_viewport() {
        let mut grid = VolvoxGrid::new(1, 16, 4, 1, 2, 0, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.set_col_width(0, 4);
        grid.set_col_width(1, 4);

        let columns = collect_columns(&grid, 0, 16);

        assert_eq!(columns.len(), 2);
        assert_eq!(columns[0].x, 0);
        assert_eq!(columns[1].x, columns[0].width + 1);
        assert_eq!(columns[1].x + columns[1].width, 16);
        assert!(columns[0].width > 4 || columns[1].width > 4);
    }

    #[test]
    fn collect_columns_does_not_expand_when_tui_is_horizontally_scrolled() {
        let mut grid = VolvoxGrid::new(1, 16, 4, 1, 2, 0, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.set_col_width(0, 4);
        grid.set_col_width(1, 4);
        grid.scroll.scroll_x = 1.0;

        let columns = collect_columns(&grid, 0, 16);

        assert_eq!(columns.len(), 2);
        assert_eq!(columns[0].width, 3);
        assert_eq!(columns[1].x + columns[1].width, 8);
    }

    #[test]
    fn render_grid_tui_uses_expanded_visual_width_for_cell_text() {
        let mut grid = VolvoxGrid::new(1, 8, 3, 1, 1, 0, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.columns[0].caption = "Value".to_string();
        grid.set_col_width(0, 4);
        grid.cells.set_text(0, 0, "abcdef".to_string());

        let mut buffer = vec![TuiCell::default(); 8 * 3];
        render_grid_tui(&mut grid, &mut buffer, 8, 3, 8);

        assert_eq!(row_text(&buffer, 8, 1, 8), "abcdef  ");
    }

    #[test]
    fn render_grid_tui_marks_edit_cursor() {
        let mut grid = VolvoxGrid::new(1, 12, 3, 2, 1, 1, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.columns[0].caption = "Value".to_string();
        grid.cells.set_text(1, 0, "seed".to_string());
        grid.edit.start_edit(1, 0, "seed");
        grid.edit.edit_text = "edit".to_string();
        grid.edit.sel_start = 2;
        grid.edit.sel_length = 0;
        grid.edit.sel_caret = 2;

        let mut buffer = vec![TuiCell::default(); 12 * 3];
        render_grid_tui(&mut grid, &mut buffer, 12, 3, 12);

        let edited_row = &buffer[12..24];
        assert!(edited_row
            .iter()
            .any(|cell| cell.attr & TUI_ATTR_REVERSE != 0));
        assert!(edited_row
            .iter()
            .any(|cell| cell.attr & TUI_ATTR_REVERSE == 0));
    }

    #[test]
    fn render_grid_tui_highlights_edit_selection_text_without_padding() {
        let mut grid = VolvoxGrid::new(1, 12, 3, 2, 1, 1, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.columns[0].caption = "Value".to_string();
        grid.cells.set_text(1, 0, "edit".to_string());
        grid.selection.row = 1;
        grid.selection.col = 0;
        grid.edit.start_edit(1, 0, "edit");

        let mut buffer = vec![TuiCell::default(); 12 * 3];
        render_grid_tui(&mut grid, &mut buffer, 12, 3, 12);

        let edited_row = &buffer[12..24];
        let selected_positions: Vec<usize> = edited_row
            .iter()
            .enumerate()
            .filter_map(|(index, cell)| (cell.attr & TUI_ATTR_REVERSE != 0).then_some(index))
            .collect();

        assert!(!selected_positions.is_empty());
        assert!(selected_positions.iter().all(|&index| index < 4));
        assert!(edited_row[4..]
            .iter()
            .all(|cell| cell.attr & TUI_ATTR_REVERSE == 0));
    }

    #[test]
    fn render_grid_tui_marks_edit_frame_with_heavy_borders() {
        let mut grid = VolvoxGrid::new(1, 20, 3, 3, 3, 1, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.columns[0].caption = "A".to_string();
        grid.columns[1].caption = "B".to_string();
        grid.columns[2].caption = "C".to_string();
        grid.set_col_width(0, 4);
        grid.set_col_width(1, 4);
        grid.set_col_width(2, 4);
        grid.cells.set_text(1, 0, "one".to_string());
        grid.cells.set_text(1, 1, "two".to_string());
        grid.cells.set_text(1, 2, "tri".to_string());
        grid.edit.start_edit(1, 1, "two");

        let mut buffer = vec![TuiCell::default(); 20 * 3];
        render_grid_tui(&mut grid, &mut buffer, 20, 3, 20);

        let row = row_text(&buffer, 20, 1, 20);
        assert!(row.contains('┃'));
        assert_eq!(row.matches('┃').count(), 2);
    }

    #[test]
    fn render_grid_tui_keeps_edit_caret_aligned_for_right_aligned_cells() {
        let mut grid = VolvoxGrid::new(1, 16, 3, 1, 1, 0, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.columns[0].caption = "Value".to_string();
        grid.columns[0].alignment = pb::Align::RightCenter as i32;
        grid.set_col_width(0, 6);
        grid.cells.set_text(0, 0, "12".to_string());
        grid.edit.start_edit(0, 0, "12");
        grid.edit.sel_start = 0;
        grid.edit.sel_length = 0;
        grid.edit.sel_caret = 0;

        let mut buffer = vec![TuiCell::default(); 16 * 3];
        render_grid_tui(&mut grid, &mut buffer, 16, 3, 16);

        let edited_cell = &buffer[16..32];
        let caret_positions: Vec<usize> = edited_cell
            .iter()
            .enumerate()
            .filter_map(|(index, cell)| (cell.attr & TUI_ATTR_REVERSE != 0).then_some(index))
            .collect();
        assert_eq!(caret_positions.len(), 1);
        assert!(caret_positions[0] >= 14);
    }

    #[test]
    fn render_grid_tui_scrolls_long_edit_text_with_caret() {
        let mut grid = VolvoxGrid::new(1, 8, 3, 1, 1, 0, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.columns[0].caption = "Value".to_string();
        grid.set_col_width(0, 4);
        grid.cells.set_text(0, 0, "abcdefghijkl".to_string());
        grid.edit.start_edit(0, 0, "abcdefghijkl");

        grid.edit.sel_start = 0;
        grid.edit.sel_length = 0;
        grid.edit.sel_caret = 0;
        let mut start_buffer = vec![TuiCell::default(); 8 * 3];
        render_grid_tui(&mut grid, &mut start_buffer, 8, 3, 8);
        let start_visible: String = start_buffer[8..16].iter().map(|cell| cell.ch()).collect();

        grid.edit.sel_start = 12;
        grid.edit.sel_length = 0;
        grid.edit.sel_caret = 12;
        let mut end_buffer = vec![TuiCell::default(); 8 * 3];
        render_grid_tui(&mut grid, &mut end_buffer, 8, 3, 8);
        let end_visible: String = end_buffer[8..16].iter().map(|cell| cell.ch()).collect();

        assert_eq!(start_visible, "abcdefgh");
        assert_eq!(end_visible, "efghijkl");
    }

    #[test]
    fn transparent_dropdown_popup_uses_explicit_readable_item_colors() {
        let mut grid = VolvoxGrid::new(1, 20, 6, 1, 1, 0, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.columns[0].caption = "Value".to_string();
        grid.columns[0].dropdown_items = "Alpha|Beta|Gamma".to_string();
        grid.set_col_width(0, 8);
        grid.cells.set_text(0, 0, "Alpha".to_string());
        grid.edit.start_edit(0, 0, "Alpha");
        grid.edit.parse_dropdown_items("Alpha|Beta|Gamma");
        grid.edit.set_dropdown_index(0);

        let mut buffer = vec![TuiCell::default(); 20 * 6];
        render_grid_tui_with_background_mode(
            &mut grid,
            &mut buffer,
            20,
            6,
            20,
            TuiBackgroundMode::Transparent,
        );

        let beta_cell = buffer
            .iter()
            .copied()
            .find(|cell| cell.ch() == 'B')
            .expect("beta popup cell");
        let beta_fg = beta_cell.fg;
        let beta_bg = beta_cell.bg;
        assert_ne!(beta_fg, TUI_COLOR_RESET);
        assert_ne!(beta_fg, beta_bg);
    }

    #[test]
    fn tui_dropdown_hit_index_uses_rendered_popup_coordinates() {
        let mut grid = VolvoxGrid::new(1, 20, 6, 2, 3, 0, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.columns[0].caption = "A".to_string();
        grid.columns[1].caption = "B".to_string();
        grid.columns[2].caption = "C".to_string();
        grid.columns[1].dropdown_items = "Alpha|Beta|Gamma".to_string();
        grid.set_col_width(0, 4);
        grid.set_col_width(1, 6);
        grid.set_col_width(2, 4);
        grid.cells.set_text(0, 1, "Alpha".to_string());
        grid.edit.start_edit(0, 1, "Alpha");
        grid.edit.parse_dropdown_items("Alpha|Beta|Gamma");
        grid.edit.set_dropdown_index(0);

        let mut buffer = vec![TuiCell::default(); 20 * 6];
        render_grid_tui(&mut grid, &mut buffer, 20, 6, 20);

        let popup = compute_tui_dropdown_popup_geometry(&grid, 20, 6).expect("popup");
        let hit = tui_dropdown_hit_index(&grid, 20, 6, popup.x + 2, popup.y + 2);
        assert_eq!(hit, Some(1));
    }

    #[test]
    fn render_grid_tui_keeps_edit_frame_for_wide_chars() {
        let mut grid = VolvoxGrid::new(1, 20, 3, 3, 3, 1, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.columns[0].caption = "A".to_string();
        grid.columns[1].caption = "B".to_string();
        grid.columns[2].caption = "C".to_string();
        grid.set_col_width(0, 3);
        grid.set_col_width(1, 2);
        grid.set_col_width(2, 3);
        grid.cells.set_text(1, 1, "가".to_string());
        grid.edit.start_edit(1, 1, "가");

        let mut buffer = vec![TuiCell::default(); 20 * 3];
        render_grid_tui(&mut grid, &mut buffer, 20, 3, 20);

        let row = row_text(&buffer, 20, 1, 20);
        assert!(row.contains('가'));
        assert_eq!(row.matches('┃').count(), 2);
    }

    #[test]
    fn render_grid_tui_renders_row_indicators_and_merged_subtotals() {
        let mut grid = VolvoxGrid::new(1, 30, 4, 2, 3, 0, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.columns[0].caption = "Name".to_string();
        grid.columns[1].caption = "Value".to_string();
        grid.set_col_width(0, 12);
        grid.set_col_width(1, 8);
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.mode_bits = pb::RowIndicatorMode::RowIndicatorNumbers as u32;
        grid.cells.set_text(0, 0, "North".to_string());
        grid.cells.set_text(0, 1, "1200".to_string());
        grid.cells.set_text(1, 0, "Grand Total".to_string());
        grid.cells.set_text(1, 1, "2400".to_string());
        grid.row_props.entry(1).or_default().is_subtotal = true;
        grid.merge_cells(1, 0, 1, 1);

        let mut buffer = vec![TuiCell::default(); 30 * 4];
        render_grid_tui(&mut grid, &mut buffer, 30, 4, 30);

        let row = row_text(&buffer, 30, 2, 30);
        assert!(row.contains("2║"));
        assert!(row.contains("Grand Total"));
        assert_eq!(row.chars().filter(|&ch| ch == '│').count(), 0);
    }

    #[test]
    fn render_grid_tui_blanks_covered_rows_for_vertical_spans() {
        let mut grid = VolvoxGrid::new(1, 24, 4, 3, 2, 1, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.columns[0].caption = "Q".to_string();
        grid.columns[1].caption = "City".to_string();
        grid.set_col_width(0, 6);
        grid.set_col_width(1, 10);
        grid.span.mode = pb::CellSpanMode::CellSpanByRow as i32;
        grid.span.span_cols.insert(0, true);
        grid.span.span_compare = pb::SpanCompareMode::SpanCompareNoCase as i32;

        grid.cells.set_text(1, 0, "Q1".to_string());
        grid.cells.set_text(1, 1, "Seoul".to_string());
        grid.cells.set_text(2, 0, "Q1".to_string());
        grid.cells.set_text(2, 1, "Busan".to_string());

        let mut buffer = vec![TuiCell::default(); 24 * 4];
        render_grid_tui(&mut grid, &mut buffer, 24, 4, 24);

        let first_row = row_text(&buffer, 24, 1, 24);
        let second_row = row_text(&buffer, 24, 2, 24);
        assert!(first_row.contains("Q1"));
        assert!(first_row.contains("Seoul"));
        assert!(!second_row.contains("Q1"));
        assert!(second_row.contains("Busan"));
    }

    #[test]
    fn render_grid_tui_centers_text_on_middle_row_for_three_row_spans() {
        let mut grid = VolvoxGrid::new(1, 24, 5, 4, 2, 1, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.columns[0].caption = "Q".to_string();
        grid.columns[1].caption = "City".to_string();
        grid.set_col_width(0, 6);
        grid.set_col_width(1, 10);
        grid.span.mode = pb::CellSpanMode::CellSpanByRow as i32;
        grid.span.span_cols.insert(0, true);
        grid.span.span_compare = pb::SpanCompareMode::SpanCompareNoCase as i32;

        grid.cells.set_text(1, 0, "Q1".to_string());
        grid.cells.set_text(1, 1, "Seoul".to_string());
        grid.cells.set_text(2, 0, "Q1".to_string());
        grid.cells.set_text(2, 1, "Busan".to_string());
        grid.cells.set_text(3, 0, "Q1".to_string());
        grid.cells.set_text(3, 1, "Daegu".to_string());

        let mut buffer = vec![TuiCell::default(); 24 * 5];
        render_grid_tui(&mut grid, &mut buffer, 24, 5, 24);

        let top_row = row_text(&buffer, 24, 1, 24);
        let middle_row = row_text(&buffer, 24, 2, 24);
        let bottom_row = row_text(&buffer, 24, 3, 24);
        assert!(!top_row.contains("Q1"));
        assert!(middle_row.contains("Q1"));
        assert!(!bottom_row.contains("Q1"));
        assert!(top_row.contains("Seoul"));
        assert!(middle_row.contains("Busan"));
        assert!(bottom_row.contains("Daegu"));
    }

    #[test]
    fn render_grid_tui_renders_outline_checkbox_dropdown_and_progress() {
        let mut grid = VolvoxGrid::new(1, 36, 4, 3, 4, 0, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.columns[0].caption = "Name".to_string();
        grid.columns[1].caption = "Flag".to_string();
        grid.columns[2].caption = "Status".to_string();
        grid.columns[3].caption = "Pct".to_string();
        grid.set_col_width(0, 12);
        grid.set_col_width(1, 5);
        grid.set_col_width(2, 8);
        grid.set_col_width(3, 6);
        grid.outline.tree_indicator = pb::TreeIndicatorStyle::TreeIndicatorArrowsLeaf as i32;
        grid.outline.tree_column = 0;
        grid.columns[1].data_type = pb::ColumnDataType::ColumnDataBoolean as i32;
        grid.columns[2].dropdown_items = "Active|Pending".to_string();
        grid.columns[3].progress_color = 0xFF22C55E;

        grid.cells.set_text(0, 0, "Folder".to_string());
        grid.row_props.entry(0).or_default().outline_level = 1;
        grid.row_props.entry(0).or_default().is_subtotal = true;

        grid.cells.set_text(1, 0, "Leaf".to_string());
        grid.row_props.entry(1).or_default().outline_level = 2;
        grid.cells.set_text(1, 1, "true".to_string());
        grid.cells.get_mut(1, 1).extra_mut().checked = pb::CheckedState::CheckedChecked as i32;
        grid.cells.set_text(1, 2, "Active".to_string());
        grid.cells.set_text(1, 3, "75".to_string());

        let mut buffer = vec![TuiCell::default(); 36 * 4];
        render_grid_tui(&mut grid, &mut buffer, 36, 4, 36);

        let folder_row = row_text(&buffer, 36, 1, 36);
        let leaf_row = row_text(&buffer, 36, 2, 36);
        assert!(folder_row.contains("▾ Folder"));
        assert!(leaf_row.contains("[x]"));
        assert!(leaf_row.contains("▾"));
        assert!(buffer[2 * 36..3 * 36]
            .iter()
            .copied()
            .any(|cell| cell.bg == 0x22C55E));
    }

    #[test]
    fn transparent_background_uses_terminal_default_for_canvas_and_plain_body_cells() {
        let mut grid = VolvoxGrid::new(1, 12, 4, 2, 1, 0, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.selection.selection_visibility = pb::SelectionVisibility::SelectionVisNone as i32;
        grid.columns[0].caption = "Value".to_string();
        grid.set_col_width(0, 6);
        grid.cells.set_text(0, 0, "Hi".to_string());
        grid.cells.set_text(1, 0, "Odd".to_string());
        grid.style.back_color_alternate = 0xFF334455;

        let mut buffer = vec![TuiCell::default(); 12 * 4];
        render_grid_tui_with_background_mode(
            &mut grid,
            &mut buffer,
            12,
            4,
            12,
            TuiBackgroundMode::Transparent,
        );

        let header_fg = buffer[0].fg;
        let header_bg = buffer[0].bg;
        let data_fg = buffer[12].fg;
        let data_bg = buffer[12].bg;
        let odd_row_bg = buffer[24].bg;
        let clear_bg = buffer[36].bg;
        assert_eq!(header_fg, TUI_COLOR_RESET);
        assert_eq!(header_bg, TUI_COLOR_RESET);
        assert_eq!(data_fg, TUI_COLOR_RESET);
        assert_eq!(data_bg, TUI_COLOR_RESET);
        assert_eq!(odd_row_bg, TUI_COLOR_RESET);
        assert_eq!(clear_bg, TUI_COLOR_RESET);
    }

    #[test]
    fn transparent_background_preserves_explicit_cell_backgrounds() {
        let mut grid = VolvoxGrid::new(1, 12, 3, 1, 1, 0, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.columns[0].caption = "Value".to_string();
        grid.set_col_width(0, 6);
        grid.cells.set_text(0, 0, "Hi".to_string());
        grid.selection.row = 0;
        grid.selection.col = 0;
        grid.selection.active_cell_style.back_color = Some(0xFFAA5500);

        let mut buffer = vec![TuiCell::default(); 12 * 3];
        render_grid_tui_with_background_mode(
            &mut grid,
            &mut buffer,
            12,
            3,
            12,
            TuiBackgroundMode::Transparent,
        );

        let active_bg = buffer[12].bg;
        assert_eq!(active_bg, 0x00AA5500);
    }

    #[test]
    fn translate_tui_mouse_x_preserves_compact_row_indicator_space() {
        let mut grid = VolvoxGrid::new(1, 18, 4, 3, 2, 0, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.mode_bits = pb::RowIndicatorMode::RowIndicatorNumbers as u32;
        grid.indicator_bands.row_start.width_px = 8;
        grid.set_col_width(0, 4);
        grid.set_col_width(1, 8);

        assert_eq!(translate_tui_mouse_x(&mut grid, 18, 4, 0), 0);
        assert_eq!(translate_tui_mouse_x(&mut grid, 18, 4, 1), 1);
        assert_eq!(translate_tui_mouse_x(&mut grid, 18, 4, 2), 2);
        assert_eq!(translate_tui_mouse_x(&mut grid, 18, 4, 3), 3);
    }

    #[test]
    fn translate_tui_mouse_x_removes_visual_column_separators() {
        let mut grid = VolvoxGrid::new(1, 18, 4, 3, 2, 0, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.indicator_bands.row_start.visible = true;
        grid.indicator_bands.row_start.mode_bits = pb::RowIndicatorMode::RowIndicatorNumbers as u32;
        grid.indicator_bands.row_start.width_px = 8;
        grid.set_col_width(0, 4);
        grid.set_col_width(1, 8);

        // Rendered layout: 3-char indicator, 4-char col0, 1-char separator, 8-char col1.
        assert_eq!(translate_tui_mouse_x(&mut grid, 18, 4, 3), 3);
        assert_eq!(translate_tui_mouse_x(&mut grid, 18, 4, 6), 6);
        assert_eq!(translate_tui_mouse_x(&mut grid, 18, 4, 7), 7);
        assert_eq!(translate_tui_mouse_x(&mut grid, 18, 4, 8), 7);
        assert_eq!(translate_tui_mouse_x(&mut grid, 18, 4, 9), 8);
    }

    #[test]
    fn translate_tui_mouse_x_keeps_expanded_cell_body_on_source_column() {
        let mut grid = VolvoxGrid::new(1, 16, 4, 2, 2, 0, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.indicator_bands.col_top.visible = true;
        grid.indicator_bands.col_top.default_row_height_px = 1;
        grid.indicator_bands.col_top.band_rows = 1;
        grid.set_col_width(0, 4);
        grid.set_col_width(1, 4);
        grid.cells.set_text(0, 0, "abcdef".to_string());
        grid.ensure_layout();

        let columns = collect_columns(&grid, 0, 16);
        assert_eq!(columns.len(), 2);
        assert!(columns[0].width > grid.col_width(0));

        let terminal_x = columns[0].x + columns[0].width - 1;
        let translation = translate_tui_mouse_x_for_hit(&mut grid, 16, 4, terminal_x);
        let hit = crate::input::hit_test(&mut grid, translation.hit_test_x as f32, 1.0);

        assert_eq!(hit.row, 0);
        assert_eq!(hit.col, 0);
        assert_eq!(translation.col, 0);
        assert!(translation.x_in_cell >= grid.col_width(0));
        assert_eq!(
            tui_caret_index_from_display_click(
                &grid,
                hit.row,
                hit.col,
                translation.x_in_cell,
                translation.cell_width,
            ),
            6
        );
    }

    #[test]
    fn compute_tui_scrollbar_geometry_matches_rendered_thumb() {
        let mut grid = VolvoxGrid::new(1, 12, 6, 20, 1, 0, 0);
        grid.set_renderer_mode(pb::RendererMode::RendererTui as i32);
        grid.set_col_width(0, 10);

        let geometry = compute_tui_scrollbar_geometry(&mut grid, 12, 6);
        assert!(geometry.visible);
        assert_eq!(geometry.scrollbar_col, 11);
        assert_eq!(geometry.track_start_row, 1);

        let mut buffer = vec![TuiCell::default(); 12 * 6];
        render_grid_tui(&mut grid, &mut buffer, 12, 6, 12);

        for row in 0..geometry.track_rows {
            let y = geometry.track_start_row + row;
            let index = y as usize * 12 + geometry.scrollbar_col as usize;
            let relative_scroll_row = row - geometry.fixed_data_rows;
            let expected = if relative_scroll_row >= 0
                && relative_scroll_row >= geometry.thumb_start
                && relative_scroll_row < geometry.thumb_start + geometry.thumb_size
            {
                '█'
            } else {
                '░'
            };
            assert_eq!(buffer[index].ch(), expected);
        }
    }
}
