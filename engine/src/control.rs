/// Explicit accessory/control metadata for a cell.
#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub enum CellControl {
    #[default]
    None,
    DropdownButton,
    EllipsisButton,
}
