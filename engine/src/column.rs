use crate::style::Padding;

/// Per-column properties
#[derive(Clone, Debug)]
pub struct ColumnProps {
    pub caption: String,
    pub alignment: i32,
    pub fixed_alignment: i32,
    pub format: String,
    pub data_type: i32,
    pub indent: i32,
    pub key: String,
    pub sort_order: i32,
    /// True when sort metadata was explicitly set through ColumnDef.sort.
    pub sort_defined: bool,
    pub edit_mask: String,
    pub dropdown_items: String,
    pub image_list: Vec<Vec<u8>>,
    pub span: bool,
    pub hidden: bool,
    pub width_min: i32,
    pub width_max: i32,
    /// When non-zero, cells in this column auto-derive progress_percent from
    /// their text value (e.g. "75%" → 0.75) and render a data-bar with
    /// this color.  Removes the need for per-cell progress setup in hosts.
    pub progress_color: u32,
    /// Arbitrary user data per column (ColData property).
    pub user_data: Option<Vec<u8>>,
    /// Visual sticky edge: 0=none, 3=LEFT, 4=RIGHT.
    pub sticky: i32,
    /// Optional per-column text insets for non-fixed cells.
    pub cell_padding: Option<Padding>,
    /// Optional per-column text insets for fixed/header cells.
    pub fixed_cell_padding: Option<Padding>,
    /// Whether null/empty writes are allowed for this column.
    pub nullable: bool,
    /// Inbound coercion behavior (`v1::CoercionMode` value).
    pub coercion_mode: i32,
    /// Error handling behavior (`v1::WriteErrorMode` value).
    pub error_mode: i32,
}

impl Default for ColumnProps {
    fn default() -> Self {
        Self {
            caption: String::new(),
            alignment: 9,
            fixed_alignment: 1, // left-center
            format: String::new(),
            data_type: 0,
            indent: 0,
            key: String::new(),
            sort_order: 0,
            sort_defined: false,
            edit_mask: String::new(),
            dropdown_items: String::new(),
            image_list: Vec::new(),
            span: false,
            hidden: false,
            width_min: 0,
            width_max: 0,
            progress_color: 0,
            user_data: None,
            sticky: 0,
            cell_padding: None,
            fixed_cell_padding: None,
            nullable: true,
            coercion_mode: 0,
            error_mode: 0,
        }
    }
}

impl ColumnProps {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn heap_size_bytes(&self) -> usize {
        let mut bytes = 0usize;
        bytes += self.caption.capacity();
        bytes += self.format.capacity();
        bytes += self.key.capacity();
        bytes += self.edit_mask.capacity();
        bytes += self.dropdown_items.capacity();
        bytes += self.image_list.capacity() * std::mem::size_of::<Vec<u8>>();
        for image in &self.image_list {
            bytes += image.capacity();
        }
        if let Some(data) = &self.user_data {
            bytes += data.capacity();
        }
        bytes
    }
}
