use crate::proto::volvoxgrid::v1 as pb;

pub const DEFAULT_ROW_INDICATOR_WIDTH: i32 = 35;
pub const DEFAULT_COL_INDICATOR_ROW_HEIGHT: i32 = 24;

#[derive(Clone, Debug)]
pub struct RowIndicatorSlotState {
    pub kind: i32,
    pub width_px: i32,
    pub visible: bool,
    pub custom_key: String,
    pub data: Vec<u8>,
}

impl Default for RowIndicatorSlotState {
    fn default() -> Self {
        Self {
            kind: pb::RowIndicatorSlotKind::RowIndicatorSlotNone as i32,
            width_px: 0,
            visible: true,
            custom_key: String::new(),
            data: Vec::new(),
        }
    }
}

#[derive(Clone, Debug)]
pub struct RowIndicatorState {
    pub visible: bool,
    pub width_px: i32,
    pub mode_bits: u32,
    pub back_color: Option<u32>,
    pub fore_color: Option<u32>,
    pub grid_lines: Option<i32>,
    pub grid_color: Option<u32>,
    pub auto_size: bool,
    pub allow_resize: bool,
    pub allow_select: bool,
    pub allow_reorder: bool,
    pub slots: Vec<RowIndicatorSlotState>,
}

impl Default for RowIndicatorState {
    fn default() -> Self {
        Self {
            visible: false,
            width_px: DEFAULT_ROW_INDICATOR_WIDTH,
            mode_bits: 0,
            back_color: None,
            fore_color: None,
            grid_lines: None,
            grid_color: None,
            auto_size: false,
            allow_resize: false,
            allow_select: false,
            allow_reorder: false,
            slots: Vec::new(),
        }
    }
}

impl RowIndicatorState {
    pub fn resolved_width_px(&self) -> i32 {
        if !self.visible {
            return 0;
        }
        let slot_sum: i32 = self
            .slots
            .iter()
            .filter(|slot| slot.visible)
            .map(|slot| slot.width_px.max(0))
            .sum();
        if slot_sum > 0 {
            slot_sum
        } else {
            self.width_px.max(1)
        }
    }

    pub fn has_mode(&self, mode: pb::RowIndicatorMode) -> bool {
        self.mode_bits & (mode as u32) != 0
    }
}

#[derive(Clone, Debug)]
pub struct ColIndicatorRowDefState {
    pub index: i32,
    pub height_px: i32,
}

impl Default for ColIndicatorRowDefState {
    fn default() -> Self {
        Self {
            index: 0,
            height_px: DEFAULT_COL_INDICATOR_ROW_HEIGHT,
        }
    }
}

#[derive(Clone, Debug)]
pub struct ColIndicatorCellState {
    pub row1: i32,
    pub row2: i32,
    pub col1: i32,
    pub col2: i32,
    pub text: String,
    pub mode_bits: u32,
    pub custom_key: String,
    pub data: Vec<u8>,
}

impl Default for ColIndicatorCellState {
    fn default() -> Self {
        Self {
            row1: 0,
            row2: 0,
            col1: 0,
            col2: 0,
            text: String::new(),
            mode_bits: 0,
            custom_key: String::new(),
            data: Vec::new(),
        }
    }
}

#[derive(Clone, Debug)]
pub struct ColIndicatorState {
    pub visible: bool,
    pub default_row_height_px: i32,
    pub band_rows: i32,
    pub mode_bits: u32,
    pub back_color: Option<u32>,
    pub fore_color: Option<u32>,
    pub grid_lines: Option<i32>,
    pub grid_color: Option<u32>,
    pub auto_size: bool,
    pub allow_resize: bool,
    pub allow_reorder: bool,
    pub allow_menu: bool,
    pub row_defs: Vec<ColIndicatorRowDefState>,
    pub cells: Vec<ColIndicatorCellState>,
}

impl Default for ColIndicatorState {
    fn default() -> Self {
        Self {
            visible: false,
            default_row_height_px: DEFAULT_COL_INDICATOR_ROW_HEIGHT,
            band_rows: 0,
            mode_bits: 0,
            back_color: None,
            fore_color: None,
            grid_lines: None,
            grid_color: None,
            auto_size: false,
            allow_resize: false,
            allow_reorder: false,
            allow_menu: false,
            row_defs: Vec::new(),
            cells: Vec::new(),
        }
    }
}

impl ColIndicatorState {
    pub fn row_count(&self) -> i32 {
        let defs = self
            .row_defs
            .iter()
            .map(|row| row.index + 1)
            .max()
            .unwrap_or(0);
        let cells = self
            .cells
            .iter()
            .map(|cell| cell.row2.max(cell.row1) + 1)
            .max()
            .unwrap_or(0);
        let synthesized = if self.mode_bits
            & (pb::ColIndicatorCellMode::ColIndicatorCellHeaderText as u32)
            != 0
        {
            1
        } else {
            0
        };
        self.band_rows.max(defs).max(cells).max(synthesized)
    }

    pub fn row_height_px(&self, row: i32) -> i32 {
        self.row_defs
            .iter()
            .find(|def| def.index == row)
            .map(|def| def.height_px.max(1))
            .unwrap_or_else(|| self.default_row_height_px.max(1))
    }

    pub fn resolved_height_px(&self) -> i32 {
        if !self.visible {
            return 0;
        }
        let rows = self.row_count();
        if rows <= 0 {
            return self.default_row_height_px.max(1);
        }
        (0..rows).map(|row| self.row_height_px(row)).sum()
    }

    pub fn has_mode(&self, mode: pb::ColIndicatorCellMode) -> bool {
        self.mode_bits & (mode as u32) != 0
    }
}

#[derive(Clone, Debug, Default)]
pub struct CornerIndicatorState {
    pub visible: bool,
    pub mode_bits: u32,
    pub back_color: Option<u32>,
    pub fore_color: Option<u32>,
    pub custom_key: String,
    pub data: Vec<u8>,
}

#[derive(Clone, Debug, Default)]
pub struct IndicatorBandsState {
    pub row_start: RowIndicatorState,
    pub row_end: RowIndicatorState,
    pub col_top: ColIndicatorState,
    pub col_bottom: ColIndicatorState,
    pub corner_top_start: CornerIndicatorState,
    pub corner_top_end: CornerIndicatorState,
    pub corner_bottom_start: CornerIndicatorState,
    pub corner_bottom_end: CornerIndicatorState,
}

impl IndicatorBandsState {
    pub fn start_width(&self) -> i32 {
        self.row_start.resolved_width_px()
    }

    pub fn end_width(&self) -> i32 {
        self.row_end.resolved_width_px()
    }

    pub fn top_height(&self) -> i32 {
        self.col_top.resolved_height_px()
    }

    pub fn bottom_height(&self) -> i32 {
        self.col_bottom.resolved_height_px()
    }
}
