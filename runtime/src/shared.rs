#![allow(dead_code)]

use volvoxgrid_engine::proto::volvoxgrid::v1::*;

type Grid = volvoxgrid_engine::grid::VolvoxGrid;

pub(crate) struct CreateGridSpec {
    pub rows: i32,
    pub cols: i32,
    pub fixed_rows: i32,
    pub fixed_cols: i32,
    pub scale: f32,
    pub apply_default_indicator_bands: bool,
}

pub(crate) fn create_grid_spec(request: &CreateRequest) -> CreateGridSpec {
    let config = request.config.as_ref();
    let layout = config.and_then(|c| c.layout.as_ref());
    CreateGridSpec {
        rows: layout.and_then(|l| l.rows).unwrap_or(10),
        cols: layout.and_then(|l| l.cols).unwrap_or(5),
        fixed_rows: layout.and_then(|l| l.fixed_rows).unwrap_or(0),
        fixed_cols: layout.and_then(|l| l.fixed_cols).unwrap_or(0),
        scale: if request.scale > 0.01 {
            request.scale
        } else {
            1.0
        },
        apply_default_indicator_bands: config.and_then(|c| c.indicators.as_ref()).is_none(),
    }
}

pub(crate) const DEFAULT_COL_INDICATOR_MODES: [i32; 2] = [
    ColIndicatorCellMode::ColIndicatorCellHeaderText as i32,
    ColIndicatorCellMode::ColIndicatorCellSortGlyph as i32,
];

fn default_row_indicator_slots() -> Vec<volvoxgrid_engine::indicator::RowIndicatorSlotState> {
    vec![
        volvoxgrid_engine::indicator::RowIndicatorSlotState::new(
            RowIndicatorSlotKind::RowIndicatorSlotCurrent,
            18,
        ),
        volvoxgrid_engine::indicator::RowIndicatorSlotState::new(
            RowIndicatorSlotKind::RowIndicatorSlotSelection,
            17,
        ),
    ]
}

pub(crate) fn ensure_default_row_indicator_slots(grid: &mut Grid) {
    if grid.indicator_bands.row_start.slots.is_empty() {
        grid.indicator_bands.row_start.slots = default_row_indicator_slots();
    }
}

pub(crate) fn apply_default_indicator_bands(grid: &mut Grid) {
    grid.indicator_bands.row_start.visible = false;
    grid.indicator_bands.row_start.width_px =
        volvoxgrid_engine::indicator::DEFAULT_ROW_INDICATOR_WIDTH;
    grid.indicator_bands.row_start.auto_size = true;
    ensure_default_row_indicator_slots(grid);

    grid.indicator_bands.col_top.visible = true;
    if grid.indicator_bands.col_top.band_rows <= 0 {
        grid.indicator_bands.col_top.band_rows = 1;
    }
    if grid.indicator_bands.col_top.default_row_height_px <= 0 {
        grid.indicator_bands.col_top.default_row_height_px =
            volvoxgrid_engine::indicator::DEFAULT_COL_INDICATOR_ROW_HEIGHT;
    }
    grid.indicator_bands.col_top.cell_modes = DEFAULT_COL_INDICATOR_MODES.to_vec();
    grid.layout.invalidate();
    grid.dirty = true;
}

pub(crate) fn configure(grid: &mut Grid, request: &ConfigureRequest) -> ConfigureResponse {
    if let Some(config) = &request.config {
        grid.apply_config(config);
    }
    ConfigureResponse {}
}

pub(crate) fn define_columns(
    grid: &mut Grid,
    request: &DefineColumnsRequest,
) -> DefineColumnsResponse {
    grid.define_columns(&request.columns);
    DefineColumnsResponse {}
}

pub(crate) fn define_rows(grid: &mut Grid, request: &DefineRowsRequest) -> DefineRowsResponse {
    grid.define_rows(&request.rows);
    DefineRowsResponse {}
}

pub(crate) fn insert_rows(grid: &mut Grid, request: &InsertRowsRequest) -> InsertRowsResponse {
    let count = request.count.max(1);
    let old_rows = grid.rows;
    let index = if request.index < 0 { -1 } else { request.index };
    let first_row = if index < 0 || index >= old_rows {
        old_rows
    } else {
        index
    };
    for i in 0..count {
        let text = request
            .text
            .get(i as usize)
            .map(|s| s.as_str())
            .unwrap_or("");
        let at_row = if index < 0 { -1 } else { index + i };
        grid.add_item(text, at_row);
    }
    InsertRowsResponse {
        inserted_count: count,
        new_row_count: grid.rows,
        first_row,
    }
}

pub(crate) fn remove_rows(grid: &mut Grid, request: &RemoveRowsRequest) -> RemoveRowsResponse {
    let old_rows = grid.rows;
    let count = request.count.max(1);
    for _ in 0..count {
        let row = request.index;
        if row < grid.fixed_rows || row >= grid.rows {
            break;
        }
        grid.remove_item(row);
    }
    RemoveRowsResponse {
        removed_count: old_rows.saturating_sub(grid.rows),
        new_row_count: grid.rows,
    }
}

pub(crate) fn move_column(grid: &mut Grid, request: &MoveColumnRequest) -> MoveColumnResponse {
    if request.col >= 0
        && request.col < grid.cols
        && request.position >= 0
        && request.position < grid.cols
    {
        grid.move_col_by_positions(request.col, request.position);
    }
    MoveColumnResponse {}
}

pub(crate) fn update_cells(grid: &mut Grid, request: &UpdateCellsRequest) -> WriteResult {
    grid.write_cells(&request.cells, request.atomic)
}

pub(crate) fn get_cells(grid: &mut Grid, request: &GetCellsRequest) -> CellsResponse {
    CellsResponse {
        cells: grid.get_cells(
            request.row1,
            request.col1,
            request.row2,
            request.col2,
            request.include_style,
            request.include_checked,
            request.include_typed,
            request.include_barcode_status,
            request.include_rich_text,
        ),
    }
}

pub(crate) fn load_table(grid: &mut Grid, request: &LoadTableRequest) -> WriteResult {
    grid.load_table(request.rows, request.cols, &request.values, request.atomic)
}

pub(crate) fn load_data(grid: &mut Grid, request: &LoadDataRequest) -> LoadDataResult {
    volvoxgrid_engine::load::load_data(grid, &request.data, request.options.as_ref())
}

pub(crate) fn append_data(grid: &mut Grid, request: &AppendDataRequest) -> LoadDataResult {
    volvoxgrid_engine::load::append_data(grid, &request.data, request.options.as_ref())
}

pub(crate) fn clear(grid: &mut Grid, request: &ClearRequest) -> ClearResponse {
    let before = grid.cells.len() as i32;
    grid.clear_region(request.scope, request.region);
    let after = grid.cells.len() as i32;
    ClearResponse {
        cleared_count: before.saturating_sub(after),
    }
}

pub(crate) fn selection_range_tuples(grid: &Grid) -> Vec<(i32, i32, i32, i32)> {
    grid.selection.all_ranges(grid.rows, grid.cols)
}

pub(crate) fn proto_ranges_from_tuples(ranges: &[(i32, i32, i32, i32)]) -> Vec<CellRange> {
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

pub(crate) fn selection_ranges_proto(grid: &Grid) -> Vec<CellRange> {
    let ranges = selection_range_tuples(grid);
    proto_ranges_from_tuples(&ranges)
}

pub(crate) fn selection_state_proto(grid: &mut Grid) -> SelectionState {
    grid.ensure_layout();
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
}

pub(crate) fn select(grid: &mut Grid, request: &SelectRequest) -> SelectResponse {
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
        grid.ensure_layout();
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
    SelectResponse {
        selection: Some(selection_state_proto(grid)),
    }
}

pub(crate) fn show_cell(grid: &mut Grid, request: &ShowCellRequest) -> ShowCellResponse {
    grid.ensure_layout();
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
    ShowCellResponse {
        top_row: grid.top_row(),
        left_col: grid.left_col(),
    }
}

pub(crate) fn set_top_row(grid: &mut Grid, request: &SetRowRequest) -> SetTopRowResponse {
    grid.set_top_row(request.row);
    SetTopRowResponse {
        top_row: grid.top_row(),
    }
}

pub(crate) fn set_left_col(grid: &mut Grid, request: &SetColRequest) -> SetLeftColResponse {
    grid.set_left_col(request.col);
    SetLeftColResponse {
        left_col: grid.left_col(),
    }
}

pub(crate) fn subtotal(grid: &mut Grid, request: &SubtotalRequest) -> SubtotalResult {
    let subtotal_font = request
        .font
        .as_ref()
        .map(volvoxgrid_engine::config::v1_font_to_cell_style_patch);
    let rows = volvoxgrid_engine::outline::subtotal_with_font(
        grid,
        request.aggregate,
        request.group_on_col,
        request.aggregate_col,
        &request.caption,
        request.background,
        request.foreground,
        request.add_outline,
        subtotal_font.as_ref(),
    );
    SubtotalResult { rows }
}

pub(crate) fn auto_size(grid: &mut Grid, request: &AutoSizeRequest) -> AutoSizeResponse {
    grid.ensure_layout();
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
    AutoSizeResponse {}
}

pub(crate) fn outline(grid: &mut Grid, request: &OutlineRequest) -> OutlineResponse {
    volvoxgrid_engine::outline::outline(grid, request.level);
    OutlineResponse {}
}

pub(crate) fn get_node(grid: &mut Grid, request: &GetNodeRequest) -> NodeInfo {
    let row = if let Some(relation) = request.relation {
        volvoxgrid_engine::outline::get_node_row(grid, request.row, relation)
    } else {
        request.row
    };
    let (level, outline_level, is_expanded, child_count, parent_row, first_child, last_child) =
        volvoxgrid_engine::outline::get_node(grid, row);
    let _ = level;
    NodeInfo {
        row,
        level: outline_level,
        is_expanded,
        child_count,
        parent_row,
        first_child,
        last_child,
    }
}

pub(crate) fn find(grid: &mut Grid, request: &FindRequest) -> FindResponse {
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
}

pub(crate) fn aggregate(grid: &mut Grid, request: &AggregateRequest) -> AggregateResponse {
    let value = volvoxgrid_engine::search::aggregate(
        grid,
        request.aggregate,
        request.row1,
        request.col1,
        request.row2,
        request.col2,
    );
    AggregateResponse { value }
}

pub(crate) fn get_merged_range(grid: &mut Grid, request: &GetMergedRangeRequest) -> CellRange {
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
}

pub(crate) fn merge_cells(grid: &mut Grid, request: &MergeCellsRequest) -> MergeCellsResponse {
    let range = request.range.clone().unwrap_or_default();
    let (row1, row2) = (range.row1.min(range.row2), range.row1.max(range.row2));
    let (col1, col2) = (range.col1.min(range.col2), range.col1.max(range.col2));
    grid.merged_regions.add_merge(row1, col1, row2, col2);
    grid.layout.invalidate();
    grid.mark_dirty();
    MergeCellsResponse {
        merged: Some(CellRange {
            row1,
            col1,
            row2,
            col2,
        }),
    }
}

pub(crate) fn unmerge_cells(
    grid: &mut Grid,
    request: &UnmergeCellsRequest,
) -> UnmergeCellsResponse {
    let range = request.range.clone().unwrap_or_default();
    let before = grid.merged_regions.all_ranges().len() as i32;
    grid.merged_regions
        .remove_overlapping(range.row1, range.col1, range.row2, range.col2);
    grid.layout.invalidate();
    grid.mark_dirty();
    let after = grid.merged_regions.all_ranges().len() as i32;
    UnmergeCellsResponse {
        unmerged_count: before.saturating_sub(after),
    }
}

pub(crate) fn get_merged_regions(grid: &mut Grid) -> MergedRegionsResponse {
    MergedRegionsResponse {
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
    }
}

pub(crate) fn get_memory_usage(grid: &mut Grid) -> MemoryUsageResponse {
    grid.memory_usage()
}

pub(crate) fn clipboard(grid: &mut Grid, request: &ClipboardCommand) -> ClipboardResponse {
    match request.command.as_ref() {
        Some(clipboard_command::Command::Copy(_)) => {
            let (text, rich_data) = volvoxgrid_engine::clipboard::copy(grid);
            ClipboardResponse { text, rich_data }
        }
        Some(clipboard_command::Command::Cut(_)) => {
            let (text, rich_data) = volvoxgrid_engine::clipboard::cut(grid);
            ClipboardResponse { text, rich_data }
        }
        Some(clipboard_command::Command::Paste(p)) => {
            if !p.text.is_empty() {
                volvoxgrid_engine::clipboard::paste(grid, &p.text);
            }
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
    }
}

pub(crate) fn export(grid: &mut Grid, request: &ExportRequest) -> ExportResponse {
    let data = volvoxgrid_engine::save::save_grid(grid, request.format, request.scope);
    ExportResponse {
        data,
        format: request.format,
    }
}

pub(crate) fn print(grid: &mut Grid, request: &PrintRequest) -> PrintResponse {
    grid.ensure_layout();
    let orientation = request.orientation.unwrap_or(0);
    let pages = volvoxgrid_engine::print::print_grid(
        grid,
        orientation,
        request.margin_left.unwrap_or(50),
        request.margin_top.unwrap_or(50),
        request.margin_right.unwrap_or(50),
        request.margin_bottom.unwrap_or(50),
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
}

pub(crate) fn archive(grid: &mut Grid, request: &ArchiveRequest) -> ArchiveResponse {
    let (data, names) =
        volvoxgrid_engine::save::archive(grid, &request.name, request.action, &request.data);
    ArchiveResponse { data, names }
}

pub(crate) fn resize_viewport(
    grid: &mut Grid,
    request: &ResizeViewportRequest,
) -> ResizeViewportResponse {
    grid.resize_viewport(request.width, request.height);
    ResizeViewportResponse {
        viewport_width: grid.viewport_width,
        viewport_height: grid.viewport_height,
    }
}

pub(crate) fn set_redraw(grid: &mut Grid, request: &SetRedrawRequest) -> SetRedrawResponse {
    let was_off = !grid.redraw;
    grid.redraw = request.enabled;
    if request.enabled {
        if was_off {
            grid.animation.suppress_next = true;
            grid.animation.clear();
        }
        grid.mark_dirty();
    }
    SetRedrawResponse {}
}

pub(crate) fn refresh(grid: &mut Grid) -> RefreshResponse {
    grid.layout.invalidate();
    grid.mark_dirty();
    RefreshResponse {}
}

pub(crate) fn truncate_to_char_count(input: &str, max_chars: i32) -> String {
    if max_chars <= 0 {
        return input.to_string();
    }
    input.chars().take(max_chars as usize).collect()
}

pub(crate) fn normalize_committed_edit_text(
    grid: &mut Grid,
    row: i32,
    col: i32,
    new_text: &str,
) -> String {
    let mut committed = truncate_to_char_count(new_text, grid.edit_max_length);

    if let Some(dropdown) = grid.configured_dropdown(row, col) {
        if let Some(mapped) = volvoxgrid_engine::edit::translate_dropdown_display_to_value_typed(
            &dropdown, &committed,
        ) {
            committed = mapped;
        }
    } else if col >= 0 && (col as usize) < grid.columns.len() {
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

pub(crate) fn apply_committed_edit_text(
    grid: &mut Grid,
    row: i32,
    col: i32,
    old_text: String,
    committed: String,
) {
    grid.cells.set_text(row, col, committed.clone());
    grid.sync_explicit_progress_from_text(row, col);

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
    if !active_combo.is_empty() {
        grid.events
            .push(volvoxgrid_engine::event::GridEventData::DropdownClosed);
    }
    grid.mark_dirty();
}

pub(crate) fn begin_edit_session_core_opts(
    grid: &mut Grid,
    row: i32,
    col: i32,
    force: bool,
    emit_before_event: bool,
    emit_dropdown_event: bool,
    select_all: Option<bool>,
    caret_end: Option<bool>,
    seed_text: Option<String>,
    formula_mode: Option<bool>,
) {
    if !grid.can_begin_edit(row, col, force) {
        return;
    }

    let is_boolean_checkbox = row >= grid.fixed_rows
        && row < grid.rows
        && col >= 0
        && col < grid.cols
        && !grid.row_props.get(&row).map_or(false, |rp| rp.is_subtotal)
        && grid.get_col_props(col).map_or(false, |cp| {
            cp.data_type == ColumnDataType::ColumnDataBoolean as i32
        });
    if is_boolean_checkbox {
        return;
    }

    let dropdown = grid.active_dropdown(row, col);
    let has_dropdown = dropdown.is_some();
    if emit_before_event {
        grid.events
            .push(volvoxgrid_engine::event::GridEventData::BeforeEdit { row, col });
    }

    let stored_text = grid.cells.get_text(row, col).to_string();
    let display_text = grid.get_display_text(row, col);
    grid.edit.start_edit_with_options(
        row,
        col,
        &display_text,
        select_all,
        caret_end,
        seed_text.as_deref(),
        formula_mode,
    );
    grid.edit.configure_compose(
        grid.effective_engine_compose_enabled(),
        grid.effective_compose_method(),
    );
    if let Some(dropdown) = dropdown.as_ref() {
        grid.edit.parse_dropdown(dropdown);
    } else {
        let combo_list = grid.active_dropdown_list(row, col);
        grid.edit.parse_dropdown_items(&combo_list);
    }
    if has_dropdown {
        for i in 0..grid.edit.dropdown_count() {
            if (!stored_text.is_empty() && grid.edit.get_dropdown_data(i) == stored_text)
                || grid.edit.get_dropdown_item(i) == display_text
            {
                grid.edit.set_dropdown_index(i);
                break;
            }
        }
    }

    if has_dropdown {
        if emit_dropdown_event {
            if let Some(event) = grid.before_dropdown_open_event(row, col) {
                grid.events.push(event);
            }
        }
        grid.events
            .push(volvoxgrid_engine::event::GridEventData::DropdownOpened);
    }
    grid.events
        .push(volvoxgrid_engine::event::GridEventData::StartEdit { row, col });
}

pub(crate) fn apply_edit_start_options(
    grid: &mut Grid,
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

pub(crate) fn edit_state_proto(grid: &mut Grid) -> EditState {
    if grid.edit.is_active() && !grid.layout.valid {
        grid.ensure_layout();
    }
    let (x, y, width, height) = if grid.edit.is_active() {
        grid.cell_screen_rect(grid.edit.edit_row, grid.edit.edit_col)
            .map(|(x, y, w, h)| (x as f32, y as f32, w as f32, h as f32))
            .unwrap_or((0.0, 0.0, 0.0, 0.0))
    } else {
        (0.0, 0.0, 0.0, 0.0)
    };

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
        x,
        y,
        width,
        height,
        max_length: grid.edit_max_length,
    }
}

pub(crate) fn expand_sort_request_columns(
    grid: &Grid,
    sort_columns: &[SortColumn],
) -> Vec<(i32, i32)> {
    let mut sort_keys = Vec::new();

    for sc in sort_columns {
        let merged = volvoxgrid_engine::sort::merge_sort_spec(
            volvoxgrid_engine::sort::SORT_NONE,
            sc.order,
            sc.r#type,
        );
        if merged == volvoxgrid_engine::sort::SORT_NONE {
            continue;
        }
        if sc.col >= 0 && sc.col < grid.cols {
            sort_keys.push((sc.col, merged));
        }
    }

    sort_keys
}
