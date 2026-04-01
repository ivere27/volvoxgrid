/// Per-row properties (only stored for rows that have non-default values)
#[derive(Clone, Debug)]
pub struct RowProps {
    pub outline_level: i32,
    pub is_subtotal: bool,
    pub subtotal_caption_col: i32,
    pub is_collapsed: bool,
    pub span: bool,  // span enabled for this row
    pub status: i32, // 0=unchanged, 1=added, 2=modified, 3=deleted
    /// Arbitrary user data per row (RowData property).
    pub user_data: Option<Vec<u8>>,
    /// Structural pin position: 0=none, 1=top, 2=bottom.
    pub pin: i32,
}

impl Default for RowProps {
    fn default() -> Self {
        Self {
            outline_level: 0,
            is_subtotal: false,
            subtotal_caption_col: -1,
            is_collapsed: false,
            span: false,
            status: 0,
            user_data: None,
            pin: 0,
        }
    }
}

impl RowProps {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn heap_size_bytes(&self) -> usize {
        self.user_data.as_ref().map_or(0, Vec::capacity)
    }
}
