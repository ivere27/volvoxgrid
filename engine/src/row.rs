/// Per-row properties (only stored for rows that have non-default values)
#[derive(Clone, Debug)]
pub struct RowProps {
    pub outline_level: i32,
    pub is_subtotal: bool,
    pub subtotal_caption_col: i32,
    pub is_collapsed: bool,
    pub span: bool, // span enabled for this row
    pub status: RowStatus,
    /// Arbitrary user data per row (RowData property).
    pub user_data: Option<Vec<u8>>,
    /// Structural pin position: 0=none, 1=top, 2=bottom.
    pub pin: i32,
}

#[derive(Clone, Debug, PartialEq, Eq)]
pub struct RowStatus {
    pub domain: String,
    pub code: i32,
}

impl RowStatus {
    pub fn new(domain: impl Into<String>, code: i32) -> Self {
        Self {
            domain: domain.into(),
            code,
        }
    }

    pub fn from_proto(status: &crate::proto::volvoxgrid::v1::RowStatus) -> Self {
        Self::new(status.domain.clone(), status.code)
    }

    pub fn to_proto(&self) -> crate::proto::volvoxgrid::v1::RowStatus {
        crate::proto::volvoxgrid::v1::RowStatus {
            domain: self.domain.clone(),
            code: self.code,
        }
    }
}

impl Default for RowStatus {
    fn default() -> Self {
        Self::new("", 0)
    }
}

impl Default for RowProps {
    fn default() -> Self {
        Self {
            outline_level: 0,
            is_subtotal: false,
            subtotal_caption_col: -1,
            is_collapsed: false,
            span: false,
            status: RowStatus::default(),
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
        self.status.domain.capacity() + self.user_data.as_ref().map_or(0, Vec::capacity)
    }
}
