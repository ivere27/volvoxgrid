use crate::proto::volvoxgrid::v1 as pb;

pub const DEFAULT_ROW_INDICATOR_WIDTH: i32 = 35;
pub const DEFAULT_COL_INDICATOR_ROW_HEIGHT: i32 = 24;

pub fn col_indicator_modes_contain(modes: &[i32], mode: pb::ColIndicatorCellMode) -> bool {
    modes.contains(&(mode as i32))
}

pub fn primary_col_indicator_mode(modes: &[i32]) -> i32 {
    modes
        .iter()
        .copied()
        .find(|mode| *mode != pb::ColIndicatorCellMode::ColIndicatorCellNone as i32)
        .unwrap_or(pb::ColIndicatorCellMode::ColIndicatorCellNone as i32)
}

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

impl RowIndicatorSlotState {
    pub fn new(kind: pb::RowIndicatorSlotKind, width_px: i32) -> Self {
        Self {
            kind: kind as i32,
            width_px: width_px.max(0),
            ..Self::default()
        }
    }
}

#[derive(Clone, Debug)]
pub struct RowIndicatorState {
    pub visible: bool,
    pub width_px: i32,
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
            back_color: None,
            fore_color: None,
            grid_lines: None,
            grid_color: None,
            auto_size: true,
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

    pub fn fit_slots_to_width(&mut self) {
        let visible: Vec<usize> = self
            .slots
            .iter()
            .enumerate()
            .filter_map(|(index, slot)| slot.visible.then_some(index))
            .collect();
        if visible.is_empty() {
            return;
        }
        let target_width = self.width_px.max(visible.len() as i32);
        let current_sum: i32 = visible
            .iter()
            .map(|&index| self.slots[index].width_px.max(1))
            .sum();
        if current_sum <= 0 {
            return;
        }

        let mut remaining_width = target_width;
        let mut remaining_sum = current_sum;
        for (position, &index) in visible.iter().enumerate() {
            let current = self.slots[index].width_px.max(1);
            let remaining_slots = (visible.len() - position - 1) as i32;
            let next_width = if remaining_slots == 0 {
                remaining_width
            } else {
                ((target_width as i64 * current as i64) / current_sum as i64)
                    .max(1)
                    .min((remaining_width - remaining_slots).max(1) as i64) as i32
            };
            self.slots[index].width_px = next_width.max(1);
            remaining_width = (remaining_width - next_width).max(remaining_slots);
            remaining_sum -= current;
            if remaining_sum <= 0 {
                break;
            }
        }
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
    pub modes: Option<Vec<i32>>,
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
            modes: None,
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
    pub cell_modes: Vec<i32>,
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
            cell_modes: Vec::new(),
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
        let synthesized = if self.has_mode(pb::ColIndicatorCellMode::ColIndicatorCellHeaderText) {
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
        col_indicator_modes_contain(&self.cell_modes, mode)
    }

    pub fn effective_modes_for_cell<'a>(&'a self, cell: &'a ColIndicatorCellState) -> &'a [i32] {
        cell.modes.as_deref().unwrap_or(&self.cell_modes)
    }
}

#[derive(Clone, Debug)]
pub struct CornerIndicatorSlotState {
    pub kind: i32,
    pub width_px: i32,
    pub visible: bool,
    pub custom_key: String,
    pub data: Vec<u8>,
    pub label_text: String,
}

impl Default for CornerIndicatorSlotState {
    fn default() -> Self {
        Self {
            kind: pb::CornerIndicatorSlotKind::CornerSlotNone as i32,
            width_px: 0,
            visible: true,
            custom_key: String::new(),
            data: Vec::new(),
            label_text: String::new(),
        }
    }
}

impl CornerIndicatorSlotState {
    pub fn new(kind: pb::CornerIndicatorSlotKind, width_px: i32) -> Self {
        Self {
            kind: kind as i32,
            width_px: width_px.max(0),
            ..Self::default()
        }
    }
}

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct IndicatorColors {
    pub background: Option<u32>,
    pub foreground: Option<u32>,
    pub grid: Option<u32>,
    pub button_background: Option<u32>,
    pub button_foreground: Option<u32>,
    pub button_border: Option<u32>,
    pub button_hover_background: Option<u32>,
    pub button_hover_foreground: Option<u32>,
    pub button_hover_border: Option<u32>,
    pub button_pressed_background: Option<u32>,
    pub button_pressed_foreground: Option<u32>,
    pub button_pressed_border_dark: Option<u32>,
    pub button_pressed_border_light: Option<u32>,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct IndicatorButtonTheme {
    pub background: Option<u32>,
    pub foreground: u32,
    pub border: Option<u32>,
    pub hover_background: u32,
    pub hover_foreground: u32,
    pub hover_border: Option<u32>,
    pub pressed_background: u32,
    pub pressed_foreground: u32,
    pub pressed_border_dark: u32,
    pub pressed_border_light: u32,
    pub pressed_text_offset: i32,
}

pub fn normalize_indicator_appearance(appearance: i32) -> i32 {
    match appearance {
        a if a == pb::IndicatorAppearance::Classic as i32 => a,
        a if a == pb::IndicatorAppearance::Flat as i32 => a,
        a if a == pb::IndicatorAppearance::Modern as i32 => a,
        _ => pb::IndicatorAppearance::Classic as i32,
    }
}

pub fn resolve_indicator_button_theme(
    appearance: i32,
    colors: IndicatorColors,
    fore_color: u32,
    grid_color: u32,
) -> IndicatorButtonTheme {
    let appearance = normalize_indicator_appearance(appearance);
    let foreground = colors
        .button_foreground
        .or(colors.foreground)
        .unwrap_or(fore_color);
    let hover_foreground = colors.button_hover_foreground.unwrap_or(foreground);
    let pressed_foreground = colors.button_pressed_foreground.unwrap_or(foreground);

    if appearance == pb::IndicatorAppearance::Flat as i32 {
        let border = colors.button_border.unwrap_or(grid_color);
        let hover_border = colors.button_hover_border.unwrap_or(border);
        return IndicatorButtonTheme {
            background: colors.button_background,
            foreground,
            border: colors.button_border,
            hover_background: colors.button_hover_background.unwrap_or(0xFFDADADA),
            hover_foreground,
            hover_border: Some(hover_border),
            pressed_background: colors.button_pressed_background.unwrap_or(0xFFC7C7C7),
            pressed_foreground,
            pressed_border_dark: colors.button_pressed_border_dark.unwrap_or(border),
            pressed_border_light: colors.button_pressed_border_light.unwrap_or(border),
            pressed_text_offset: 0,
        };
    }

    if appearance == pb::IndicatorAppearance::Modern as i32 {
        let border = colors.button_border.unwrap_or(0xFF5B8DEF);
        let hover_border = colors.button_hover_border.unwrap_or(border);
        return IndicatorButtonTheme {
            background: colors.button_background,
            foreground,
            border: colors.button_border,
            hover_background: colors.button_hover_background.unwrap_or(0xFFEAF3FF),
            hover_foreground,
            hover_border: Some(hover_border),
            pressed_background: colors.button_pressed_background.unwrap_or(0xFFDCEBFF),
            pressed_foreground,
            pressed_border_dark: colors.button_pressed_border_dark.unwrap_or(border),
            pressed_border_light: colors.button_pressed_border_light.unwrap_or(border),
            pressed_text_offset: 0,
        };
    }

    IndicatorButtonTheme {
        background: colors.button_background,
        foreground,
        border: colors.button_border,
        hover_background: colors.button_hover_background.unwrap_or(0xFFE5E5E5),
        hover_foreground,
        hover_border: colors.button_hover_border.or(Some(0xFF808080)),
        pressed_background: colors.button_pressed_background.unwrap_or(0xFFD0D0D0),
        pressed_foreground,
        pressed_border_dark: colors.button_pressed_border_dark.unwrap_or(0xFF707070),
        pressed_border_light: colors.button_pressed_border_light.unwrap_or(0xFFFFFFFF),
        pressed_text_offset: 1,
    }
}

#[derive(Clone, Debug, Default)]
pub struct CornerIndicatorState {
    pub visible: bool,
    pub back_color: Option<u32>,
    pub fore_color: Option<u32>,
    pub custom_key: String,
    pub data: Vec<u8>,
    pub slots: Vec<CornerIndicatorSlotState>,
}

#[derive(Clone, Debug, Default)]
pub struct IndicatorBandsState {
    pub appearance: i32,
    pub colors: IndicatorColors,
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
