use crate::proto::volvoxgrid::v1 as pb;

/// Insets inside a cell's draw/edit bounds, in pixels.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Padding {
    pub left: i32,
    pub top: i32,
    pub right: i32,
    pub bottom: i32,
}

impl Default for Padding {
    fn default() -> Self {
        Self {
            left: 6,
            top: 2,
            right: 6,
            bottom: 2,
        }
    }
}

impl Padding {
    pub fn clamped_non_negative(self) -> Self {
        Self {
            left: self.left.max(0),
            top: self.top.max(0),
            right: self.right.max(0),
            bottom: self.bottom.max(0),
        }
    }

    pub fn horizontal(self) -> i32 {
        self.left + self.right
    }

    pub fn vertical(self) -> i32 {
        self.top + self.bottom
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub enum HeaderMarkHeight {
    Ratio(f32),
    Px(i32),
}

impl Default for HeaderMarkHeight {
    fn default() -> Self {
        Self::Ratio(0.5)
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct HeaderSeparator {
    pub enabled: bool,
    pub color: u32,
    pub width_px: i32,
    pub height: HeaderMarkHeight,
    pub skip_merged: bool,
}

impl Default for HeaderSeparator {
    fn default() -> Self {
        Self {
            enabled: false,
            color: 0xFFC9D2DE,
            width_px: 1,
            height: HeaderMarkHeight::default(),
            skip_merged: true,
        }
    }
}

#[derive(Clone, Copy, Debug, PartialEq)]
pub struct HeaderResizeHandle {
    pub enabled: bool,
    pub color: u32,
    pub width_px: i32,
    pub height: HeaderMarkHeight,
    pub hit_width_px: i32,
    pub show_only_when_resizable: bool,
}

impl Default for HeaderResizeHandle {
    fn default() -> Self {
        Self {
            enabled: false,
            color: 0xFFC9D2DE,
            width_px: 1,
            height: HeaderMarkHeight::default(),
            hit_width_px: 6,
            show_only_when_resizable: true,
        }
    }
}

#[derive(Clone, Debug, Default)]
pub struct IconSlots {
    pub sort_ascending: Option<String>,
    pub sort_descending: Option<String>,
    pub sort_none: Option<String>,
    pub tree_expanded: Option<String>,
    pub tree_collapsed: Option<String>,
    pub menu: Option<String>,
    pub filter: Option<String>,
    pub filter_active: Option<String>,
    pub columns: Option<String>,
    pub drag_handle: Option<String>,
    pub checkbox_checked: Option<String>,
    pub checkbox_unchecked: Option<String>,
    pub checkbox_indeterminate: Option<String>,
}

impl IconSlots {
    pub fn heap_size_bytes(&self) -> usize {
        self.sort_ascending.as_ref().map_or(0, String::capacity)
            + self.sort_descending.as_ref().map_or(0, String::capacity)
            + self.sort_none.as_ref().map_or(0, String::capacity)
            + self.tree_expanded.as_ref().map_or(0, String::capacity)
            + self.tree_collapsed.as_ref().map_or(0, String::capacity)
            + self.menu.as_ref().map_or(0, String::capacity)
            + self.filter.as_ref().map_or(0, String::capacity)
            + self.filter_active.as_ref().map_or(0, String::capacity)
            + self.columns.as_ref().map_or(0, String::capacity)
            + self.drag_handle.as_ref().map_or(0, String::capacity)
            + self.checkbox_checked.as_ref().map_or(0, String::capacity)
            + self.checkbox_unchecked.as_ref().map_or(0, String::capacity)
            + self
                .checkbox_indeterminate
                .as_ref()
                .map_or(0, String::capacity)
    }
}

#[derive(Clone, Debug, Default)]
pub struct IconFontStyle {
    pub font_name: Option<String>,
    pub font_names: Vec<String>,
    pub font_size: Option<f32>,
    pub font_bold: Option<bool>,
    pub font_italic: Option<bool>,
    pub color: Option<u32>,
}

impl IconFontStyle {
    pub fn heap_size_bytes(&self) -> usize {
        self.font_name.as_ref().map_or(0, String::capacity)
            + self.font_names.capacity() * std::mem::size_of::<String>()
            + self.font_names.iter().map(String::capacity).sum::<usize>()
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct IconLayout {
    pub align: i32,
    pub gap_px: i32,
}

impl Default for IconLayout {
    fn default() -> Self {
        Self {
            align: pb::IconAlign::InlineEnd as i32,
            gap_px: 4,
        }
    }
}

#[derive(Clone, Debug, Default)]
pub struct IconDefaults {
    pub text_style: IconFontStyle,
    pub layout: IconLayout,
}

#[derive(Clone, Debug, Default)]
pub struct IconSlotStyle {
    pub text_style: IconFontStyle,
    pub layout: Option<IconLayout>,
}

impl IconSlotStyle {
    pub fn heap_size_bytes(&self) -> usize {
        self.text_style.heap_size_bytes()
    }
}

#[derive(Clone, Debug, Default)]
pub struct IconSlotStyles {
    pub sort_ascending: Option<IconSlotStyle>,
    pub sort_descending: Option<IconSlotStyle>,
    pub sort_none: Option<IconSlotStyle>,
    pub tree_expanded: Option<IconSlotStyle>,
    pub tree_collapsed: Option<IconSlotStyle>,
    pub menu: Option<IconSlotStyle>,
    pub filter: Option<IconSlotStyle>,
    pub filter_active: Option<IconSlotStyle>,
    pub columns: Option<IconSlotStyle>,
    pub drag_handle: Option<IconSlotStyle>,
    pub checkbox_checked: Option<IconSlotStyle>,
    pub checkbox_unchecked: Option<IconSlotStyle>,
    pub checkbox_indeterminate: Option<IconSlotStyle>,
}

impl IconSlotStyles {
    pub fn heap_size_bytes(&self) -> usize {
        let slots = [
            self.sort_ascending.as_ref(),
            self.sort_descending.as_ref(),
            self.sort_none.as_ref(),
            self.tree_expanded.as_ref(),
            self.tree_collapsed.as_ref(),
            self.menu.as_ref(),
            self.filter.as_ref(),
            self.filter_active.as_ref(),
            self.columns.as_ref(),
            self.drag_handle.as_ref(),
            self.checkbox_checked.as_ref(),
            self.checkbox_unchecked.as_ref(),
            self.checkbox_indeterminate.as_ref(),
        ];
        slots
            .into_iter()
            .flatten()
            .map(IconSlotStyle::heap_size_bytes)
            .sum()
    }
}

pub(crate) fn proto_border_to_parts(border: Option<&pb::Border>) -> (Option<i32>, Option<u32>) {
    match border {
        Some(border) => (border.style, border.color),
        None => (None, None),
    }
}

pub(crate) fn proto_borders_to_parts(
    borders: Option<&pb::Borders>,
) -> (
    Option<i32>,
    Option<u32>,
    Option<i32>,
    Option<u32>,
    Option<i32>,
    Option<u32>,
    Option<i32>,
    Option<u32>,
    Option<i32>,
    Option<u32>,
) {
    let Some(borders) = borders else {
        return (None, None, None, None, None, None, None, None, None, None);
    };

    let (all_style, all_color) = proto_border_to_parts(borders.all.as_ref());
    let (top_style, top_color) = proto_border_to_parts(borders.top.as_ref());
    let (right_style, right_color) = proto_border_to_parts(borders.right.as_ref());
    let (bottom_style, bottom_color) = proto_border_to_parts(borders.bottom.as_ref());
    let (left_style, left_color) = proto_border_to_parts(borders.left.as_ref());

    (
        all_style,
        all_color,
        top_style,
        top_color,
        right_style,
        right_color,
        bottom_style,
        bottom_color,
        left_style,
        left_color,
    )
}

pub(crate) fn parts_to_proto_border(style: Option<i32>, color: Option<u32>) -> Option<pb::Border> {
    if style.is_none() && color.is_none() {
        None
    } else {
        Some(pb::Border { style, color })
    }
}

pub(crate) fn parts_to_proto_borders(
    all_style: Option<i32>,
    all_color: Option<u32>,
    top_style: Option<i32>,
    top_color: Option<u32>,
    right_style: Option<i32>,
    right_color: Option<u32>,
    bottom_style: Option<i32>,
    bottom_color: Option<u32>,
    left_style: Option<i32>,
    left_color: Option<u32>,
) -> Option<pb::Borders> {
    let all = parts_to_proto_border(all_style, all_color);
    let top = parts_to_proto_border(top_style, top_color);
    let right = parts_to_proto_border(right_style, right_color);
    let bottom = parts_to_proto_border(bottom_style, bottom_color);
    let left = parts_to_proto_border(left_style, left_color);

    if all.is_none() && top.is_none() && right.is_none() && bottom.is_none() && left.is_none() {
        None
    } else {
        Some(pb::Borders {
            all,
            top,
            right,
            bottom,
            left,
        })
    }
}

/// Shared highlight visual style used by selection, hover and edit references.
#[derive(Clone, Debug, Default)]
pub struct HighlightStyle {
    pub back_color: Option<u32>,
    pub fore_color: Option<u32>,
    pub border: Option<i32>,
    pub border_color: Option<u32>,
    pub border_top: Option<i32>,
    pub border_right: Option<i32>,
    pub border_bottom: Option<i32>,
    pub border_left: Option<i32>,
    pub border_top_color: Option<u32>,
    pub border_right_color: Option<u32>,
    pub border_bottom_color: Option<u32>,
    pub border_left_color: Option<u32>,
    pub fill_handle: Option<i32>,
    pub fill_handle_color: Option<u32>,
}

impl HighlightStyle {
    pub fn from_proto(src: Option<&pb::HighlightStyle>) -> Self {
        let Some(src) = src else {
            return Self::default();
        };
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
        ) = proto_borders_to_parts(src.borders.as_ref());
        Self {
            back_color: src.background,
            fore_color: src.foreground,
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
            fill_handle: src.fill_handle,
            fill_handle_color: src.fill_handle_color,
        }
    }

    pub fn to_proto(&self) -> pb::HighlightStyle {
        pb::HighlightStyle {
            background: self.back_color,
            foreground: self.fore_color,
            borders: parts_to_proto_borders(
                self.border,
                self.border_color,
                self.border_top,
                self.border_top_color,
                self.border_right,
                self.border_right_color,
                self.border_bottom,
                self.border_bottom_color,
                self.border_left,
                self.border_left_color,
            ),
            fill_handle: self.fill_handle,
            fill_handle_color: self.fill_handle_color,
        }
    }

    pub fn merge_from(&mut self, other: &HighlightStyle) {
        if other.back_color.is_some() {
            self.back_color = other.back_color;
        }
        if other.fore_color.is_some() {
            self.fore_color = other.fore_color;
        }
        if other.border.is_some() {
            self.border = other.border;
        }
        if other.border_color.is_some() {
            self.border_color = other.border_color;
        }
        if other.border_top.is_some() {
            self.border_top = other.border_top;
        }
        if other.border_right.is_some() {
            self.border_right = other.border_right;
        }
        if other.border_bottom.is_some() {
            self.border_bottom = other.border_bottom;
        }
        if other.border_left.is_some() {
            self.border_left = other.border_left;
        }
        if other.border_top_color.is_some() {
            self.border_top_color = other.border_top_color;
        }
        if other.border_right_color.is_some() {
            self.border_right_color = other.border_right_color;
        }
        if other.border_bottom_color.is_some() {
            self.border_bottom_color = other.border_bottom_color;
        }
        if other.border_left_color.is_some() {
            self.border_left_color = other.border_left_color;
        }
        if other.fill_handle.is_some() {
            self.fill_handle = other.fill_handle;
        }
        if other.fill_handle_color.is_some() {
            self.fill_handle_color = other.fill_handle_color;
        }
    }
}

/// Grid-level style state (maps to GridStyle proto message)
#[derive(Clone, Debug)]
pub struct GridStyleState {
    pub appearance: i32,
    pub back_color: u32,
    pub fore_color: u32,
    pub back_color_fixed: u32,
    pub fore_color_fixed: u32,
    pub back_color_frozen: u32,
    pub fore_color_frozen: u32,
    pub back_color_bkg: u32,
    pub back_color_alternate: u32,
    pub grid_lines: i32,
    pub grid_lines_fixed: i32,
    pub grid_color: u32,
    pub grid_color_fixed: u32,
    pub grid_line_width: i32,
    pub text_effect: i32,
    pub text_effect_fixed: i32,
    pub font_name: String,
    pub font_size: f32,
    pub font_bold: bool,
    pub font_italic: bool,
    pub font_underline: bool,
    pub font_strikethrough: bool,
    pub font_stretch: f32,
    pub sheet_border: u32,
    pub progress_color: u32,
    pub image_over_text: bool,
    pub background_image: Vec<u8>,
    pub background_image_alignment: i32,
    pub text_render_mode: i32,
    pub text_hinting_mode: i32,
    pub text_pixel_snap: bool,
    pub tree_color: u32,
    pub cell_padding: Padding,
    pub fixed_cell_padding: Padding,
    pub header_separator: HeaderSeparator,
    pub header_resize_handle: HeaderResizeHandle,
    pub icon_theme_slots: IconSlots,
    pub icon_theme_defaults: IconDefaults,
    pub icon_theme_slot_styles: IconSlotStyles,
    pub checkbox_checked_picture: Option<Vec<u8>>,
    pub checkbox_unchecked_picture: Option<Vec<u8>>,
    pub checkbox_indeterminate_picture: Option<Vec<u8>>,
    /// When true and multiple sort keys are active, draw priority numbers (1,2,3…)
    /// next to sort indicators in column headers.
    pub show_sort_numbers: bool,
}

impl Default for GridStyleState {
    fn default() -> Self {
        Self {
            appearance: 0,
            back_color: 0xFFFFFFFF,           // white
            fore_color: 0xFF000000,           // black
            back_color_fixed: 0xFFC0C0C0,     // light gray
            fore_color_fixed: 0xFF000000,     // black
            back_color_frozen: 0xFFFFFFFF,    // white
            fore_color_frozen: 0xFF000000,    // black
            back_color_bkg: 0xFFFFFFFF,       // white
            back_color_alternate: 0x00000000, // transparent (disabled)
            grid_lines: pb::GridLineStyle::GridlineSolid as i32,
            grid_lines_fixed: pb::GridLineStyle::GridlineInset as i32,
            grid_color: 0xFFC0C0C0,       // light gray
            grid_color_fixed: 0xFFC0C0C0, // light gray
            grid_line_width: 1,
            text_effect: pb::TextEffect::None as i32,
            text_effect_fixed: pb::TextEffect::None as i32,
            // Empty means "use platform default font family". This avoids
            // hard-coding a Windows-only face (Segoe UI) that may not exist
            // on Android/Linux and would render text as blank.
            font_name: String::new(),
            font_size: 11.0,
            font_bold: false,
            font_italic: false,
            font_underline: false,
            font_strikethrough: false,
            font_stretch: 0.0,
            sheet_border: 0,
            progress_color: 0,
            image_over_text: false,
            background_image: Vec::new(),
            background_image_alignment: pb::ImageAlignment::ImgAlignLeftTop as i32,
            text_render_mode: pb::TextRenderMode::TextRenderAuto as i32,
            text_hinting_mode: pb::TextHintingMode::TextHintAuto as i32,
            text_pixel_snap: false,
            tree_color: 0xFF808080, // gray
            cell_padding: Padding::default(),
            fixed_cell_padding: Padding::default(),
            header_separator: HeaderSeparator::default(),
            header_resize_handle: HeaderResizeHandle::default(),
            icon_theme_slots: IconSlots::default(),
            icon_theme_defaults: IconDefaults::default(),
            icon_theme_slot_styles: IconSlotStyles::default(),
            checkbox_checked_picture: None,
            checkbox_unchecked_picture: None,
            checkbox_indeterminate_picture: None,
            show_sort_numbers: false,
        }
    }
}

impl GridStyleState {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn heap_size_bytes(&self) -> usize {
        self.font_name.capacity()
            + self.background_image.capacity()
            + self.icon_theme_slots.heap_size_bytes()
            + self.icon_theme_defaults.text_style.heap_size_bytes()
            + self.icon_theme_slot_styles.heap_size_bytes()
            + self
                .checkbox_checked_picture
                .as_ref()
                .map_or(0, Vec::capacity)
            + self
                .checkbox_unchecked_picture
                .as_ref()
                .map_or(0, Vec::capacity)
            + self
                .checkbox_indeterminate_picture
                .as_ref()
                .map_or(0, Vec::capacity)
    }
}

/// Per-cell style override (only stores overrides, not full style)
#[derive(Clone, Debug, Default)]
pub struct CellStylePatch {
    pub back_color: Option<u32>,
    pub fore_color: Option<u32>,
    pub alignment: Option<i32>,
    pub text_effect: Option<i32>,
    pub font_name: Option<String>,
    pub font_size: Option<f32>,
    pub font_bold: Option<bool>,
    pub font_italic: Option<bool>,
    pub font_underline: Option<bool>,
    pub font_strikethrough: Option<bool>,
    pub font_stretch: Option<f32>,
    pub border: Option<i32>,
    pub border_color: Option<u32>,
    pub border_top: Option<i32>,
    pub border_right: Option<i32>,
    pub border_bottom: Option<i32>,
    pub border_left: Option<i32>,
    pub border_top_color: Option<u32>,
    pub border_right_color: Option<u32>,
    pub border_bottom_color: Option<u32>,
    pub border_left_color: Option<u32>,
    pub padding: Option<Padding>,
    pub shrink_to_fit: Option<bool>,
}

impl CellStylePatch {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn heap_size_bytes(&self) -> usize {
        self.font_name.as_ref().map_or(0, String::capacity)
    }

    pub fn is_empty(&self) -> bool {
        self.back_color.is_none()
            && self.fore_color.is_none()
            && self.alignment.is_none()
            && self.text_effect.is_none()
            && self.font_name.is_none()
            && self.font_size.is_none()
            && self.font_bold.is_none()
            && self.font_italic.is_none()
            && self.font_underline.is_none()
            && self.font_strikethrough.is_none()
            && self.font_stretch.is_none()
            && self.border.is_none()
            && self.border_color.is_none()
            && self.border_top.is_none()
            && self.border_right.is_none()
            && self.border_bottom.is_none()
            && self.border_left.is_none()
            && self.border_top_color.is_none()
            && self.border_right_color.is_none()
            && self.border_bottom_color.is_none()
            && self.border_left_color.is_none()
            && self.padding.is_none()
            && self.shrink_to_fit.is_none()
    }

    /// Merge `other` into `self`: any `Some` field in `other` overwrites `self`.
    /// Fields that are `None` in `other` are left unchanged in `self`.
    pub fn merge_from(&mut self, other: &CellStylePatch) {
        if other.back_color.is_some() {
            self.back_color = other.back_color;
        }
        if other.fore_color.is_some() {
            self.fore_color = other.fore_color;
        }
        if other.alignment.is_some() {
            self.alignment = other.alignment;
        }
        if other.text_effect.is_some() {
            self.text_effect = other.text_effect;
        }
        if other.font_name.is_some() {
            self.font_name = other.font_name.clone();
        }
        if other.font_size.is_some() {
            self.font_size = other.font_size;
        }
        if other.font_bold.is_some() {
            self.font_bold = other.font_bold;
        }
        if other.font_italic.is_some() {
            self.font_italic = other.font_italic;
        }
        if other.font_underline.is_some() {
            self.font_underline = other.font_underline;
        }
        if other.font_strikethrough.is_some() {
            self.font_strikethrough = other.font_strikethrough;
        }
        if other.font_stretch.is_some() {
            self.font_stretch = other.font_stretch;
        }
        if other.border.is_some() {
            self.border = other.border;
        }
        if other.border_color.is_some() {
            self.border_color = other.border_color;
        }
        if other.border_top.is_some() {
            self.border_top = other.border_top;
        }
        if other.border_right.is_some() {
            self.border_right = other.border_right;
        }
        if other.border_bottom.is_some() {
            self.border_bottom = other.border_bottom;
        }
        if other.border_left.is_some() {
            self.border_left = other.border_left;
        }
        if other.border_top_color.is_some() {
            self.border_top_color = other.border_top_color;
        }
        if other.border_right_color.is_some() {
            self.border_right_color = other.border_right_color;
        }
        if other.border_bottom_color.is_some() {
            self.border_bottom_color = other.border_bottom_color;
        }
        if other.border_left_color.is_some() {
            self.border_left_color = other.border_left_color;
        }
        if other.padding.is_some() {
            self.padding = other.padding;
        }
        if other.shrink_to_fit.is_some() {
            self.shrink_to_fit = other.shrink_to_fit;
        }
    }

    /// Resolve this override against the grid-level style to get final back color.
    /// Priority: cell override > selected > alternate > frozen > fixed > grid default
    pub fn resolve_back_color(
        &self,
        grid_style: &GridStyleState,
        is_fixed: bool,
        is_frozen: bool,
        is_selected: bool,
        is_alternate: bool,
        selected_back_color: u32,
    ) -> u32 {
        if let Some(color) = self.back_color {
            return color;
        }
        if is_selected {
            return selected_back_color;
        }
        if is_alternate && grid_style.back_color_alternate != 0x00000000 {
            return grid_style.back_color_alternate;
        }
        if is_frozen {
            return grid_style.back_color_frozen;
        }
        if is_fixed {
            return grid_style.back_color_fixed;
        }
        grid_style.back_color
    }

    /// Resolve this override against the grid-level style to get final fore color.
    /// Priority: cell override > selected > frozen > fixed > grid default
    pub fn resolve_fore_color(
        &self,
        grid_style: &GridStyleState,
        is_fixed: bool,
        is_frozen: bool,
        is_selected: bool,
        selected_fore_color: u32,
    ) -> u32 {
        if let Some(color) = self.fore_color {
            return color;
        }
        if is_selected {
            return selected_fore_color;
        }
        if is_frozen {
            return grid_style.fore_color_frozen;
        }
        if is_fixed {
            return grid_style.fore_color_fixed;
        }
        grid_style.fore_color
    }
}
