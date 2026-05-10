use std::collections::{HashMap, HashSet};

use crate::grid::VolvoxGrid;
use crate::proto::volvoxgrid::v1 as pb;
use crate::row::{RowProps, RowStatus};

const NO_ROW: i32 = -1;
// Approximate per-entry hash table overhead used for heap reporting only. Rust
// does not expose RawTable bucket accounting, so keep the estimate named.
const HASHMAP_BUCKET_OVERHEAD_BYTES: usize = 16;
const HASHSET_BUCKET_OVERHEAD_BYTES: usize = 8;

fn usize_to_i32_saturating(value: usize) -> i32 {
    if value > i32::MAX as usize {
        i32::MAX
    } else {
        value as i32
    }
}

fn string_heap_bytes(value: &Option<String>) -> usize {
    value.as_ref().map_or(0, String::capacity)
}

fn bytes_heap_bytes(value: &Option<Vec<u8>>) -> usize {
    value.as_ref().map_or(0, Vec::capacity)
}

#[derive(Debug, Clone, PartialEq, Eq)]
pub enum TreeError {
    InvalidArgument(String),
    NotFound(String),
    DuplicateNodeId(String),
    MissingParent { node_id: String, parent_id: String },
    Cycle(String),
}

impl std::fmt::Display for TreeError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            TreeError::InvalidArgument(message) => f.write_str(message),
            TreeError::NotFound(node_id) => write!(f, "tree node not found: {node_id}"),
            TreeError::DuplicateNodeId(node_id) => write!(f, "duplicate tree node id: {node_id}"),
            TreeError::MissingParent { node_id, parent_id } => {
                write!(
                    f,
                    "tree node {node_id} references missing parent {parent_id}"
                )
            }
            TreeError::Cycle(node_id) => write!(f, "tree cycle detected at node {node_id}"),
        }
    }
}

impl std::error::Error for TreeError {}

pub fn error_code(error: &TreeError) -> i32 {
    match error {
        TreeError::NotFound(_) => pb::ErrorCode::ErrorNotFound as i32,
        TreeError::InvalidArgument(_)
        | TreeError::DuplicateNodeId(_)
        | TreeError::MissingParent { .. }
        | TreeError::Cycle(_) => pb::ErrorCode::ErrorInvalidArgument as i32,
    }
}

#[derive(Clone, Debug)]
struct TreeNodeRecord {
    id: String,
    parent: Option<usize>,
    children: Vec<usize>,
    row: Option<pb::RowDef>,
    cells: Vec<pb::NodeCellUpdate>,
    children_state: i32,
    icon_name: Option<String>,
    icon_name_open: Option<String>,
    data: Option<Vec<u8>>,
    expanded: bool,
    level: i32,
    visible_ordinal: Option<usize>,
}

impl TreeNodeRecord {
    fn from_proto(mut node: pb::TreeNode, collapse_initial: bool) -> Self {
        Self {
            id: node.node_id,
            parent: None,
            children: Vec::new(),
            row: node.row.take(),
            cells: node.cells,
            children_state: node.children_state,
            icon_name: node.icon_name,
            icon_name_open: node.icon_name_open,
            data: node.data,
            expanded: !collapse_initial,
            level: 0,
            visible_ordinal: None,
        }
    }

    fn has_materialized_children(&self) -> bool {
        !self.children.is_empty()
    }

    fn may_have_children(&self) -> bool {
        self.has_materialized_children()
            || matches!(
                self.children_state,
                x if x == pb::NodeChildrenState::NodeChildrenUnloaded as i32
                    || x == pb::NodeChildrenState::NodeChildrenLoading as i32
                    || x == pb::NodeChildrenState::NodeChildrenError as i32
            )
    }

    fn heap_size_bytes(&self) -> usize {
        let mut bytes = self.id.capacity();
        bytes += self.children.capacity() * std::mem::size_of::<usize>();
        bytes += self.cells.capacity() * std::mem::size_of::<pb::NodeCellUpdate>();
        for cell in &self.cells {
            bytes += cell.node_id.capacity();
            if let Some(value) = &cell.value {
                bytes += cell_value_heap_size(value);
            }
            if let Some(style) = &cell.style {
                if let Some(font) = &style.font {
                    bytes += font.family.as_ref().map_or(0, String::capacity);
                    for family in &font.families {
                        bytes += family.capacity();
                    }
                }
            }
            if let Some(picture) = &cell.picture {
                bytes += picture.data.capacity() + picture.format.capacity();
            }
            if let Some(dropdown) = &cell.dropdown {
                bytes += dropdown_heap_size(dropdown);
            }
        }
        bytes += string_heap_bytes(&self.icon_name);
        bytes += string_heap_bytes(&self.icon_name_open);
        bytes += bytes_heap_bytes(&self.data);
        if let Some(row) = &self.row {
            bytes += row.data.as_ref().map_or(0, Vec::capacity);
            if let Some(status) = &row.status {
                bytes += status.domain.capacity();
            }
        }
        bytes
    }
}

fn cell_value_heap_size(value: &pb::CellValue) -> usize {
    match &value.value {
        Some(pb::cell_value::Value::Text(text)) => text.capacity(),
        Some(pb::cell_value::Value::Raw(bytes)) => bytes.capacity(),
        Some(
            pb::cell_value::Value::Number(_)
            | pb::cell_value::Value::Flag(_)
            | pb::cell_value::Value::Timestamp(_),
        )
        | None => 0,
    }
}

fn dropdown_heap_size(dropdown: &pb::Dropdown) -> usize {
    let mut bytes = dropdown.items.capacity() * std::mem::size_of::<pb::DropdownItem>();
    for item in &dropdown.items {
        bytes += item.value.as_ref().map_or(0, String::capacity);
        bytes += item.label.as_ref().map_or(0, String::capacity);
        for detail in &item.details {
            bytes += detail.capacity();
        }
    }
    bytes
}

struct FlatTreeNode {
    node: pb::TreeNode,
    parent_id: String,
}

/// Arena-backed native tree state.
///
/// Node indices are internal and stable between projections. Public identity is
/// always `node_id`; the visible grid row is derived from the current expansion
/// projection and may change after insert/remove/move/expand/collapse.
#[derive(Clone, Debug, Default)]
pub struct TreeState {
    nodes: Vec<TreeNodeRecord>,
    id_to_index: HashMap<String, usize>,
    roots: Vec<usize>,
    visible: Vec<usize>,
    visible_filter: Option<HashSet<usize>>,
    selected: HashSet<usize>,
    active: Option<usize>,
    checked: HashSet<usize>,
}

impl TreeState {
    pub fn is_empty(&self) -> bool {
        self.nodes.is_empty()
    }

    pub fn node_count(&self) -> usize {
        self.nodes.len()
    }

    pub fn visible_count(&self) -> usize {
        self.visible.len()
    }

    pub fn heap_size_bytes(&self) -> usize {
        let mut bytes = 0usize;
        bytes += self.nodes.capacity() * std::mem::size_of::<TreeNodeRecord>();
        bytes += self.id_to_index.capacity()
            * (std::mem::size_of::<String>() + HASHMAP_BUCKET_OVERHEAD_BYTES);
        bytes += self.roots.capacity() * std::mem::size_of::<usize>();
        bytes += self.visible.capacity() * std::mem::size_of::<usize>();
        bytes += self.visible_filter.as_ref().map_or(0, |filter| {
            filter.capacity() * (std::mem::size_of::<usize>() + HASHSET_BUCKET_OVERHEAD_BYTES)
        });
        bytes += self.selected.capacity()
            * (std::mem::size_of::<usize>() + HASHSET_BUCKET_OVERHEAD_BYTES);
        bytes += self.checked.capacity()
            * (std::mem::size_of::<usize>() + HASHSET_BUCKET_OVERHEAD_BYTES);
        for node in &self.nodes {
            bytes += node.heap_size_bytes();
        }
        bytes
    }

    pub fn load(
        &mut self,
        nodes: Vec<pb::TreeNode>,
        collapse_initial: bool,
    ) -> Result<(), TreeError> {
        let flat = flatten_nodes(nodes, "", false)?;
        let mut next = TreeState::default();
        next.reserve(flat.len());
        next.add_flat_nodes(flat, collapse_initial)?;
        next.refresh_metadata()?;
        next.rebuild_visible();
        *self = next;
        Ok(())
    }

    pub fn insert_nodes(
        &mut self,
        parent_id: &str,
        position: i32,
        nodes: Vec<pb::TreeNode>,
        collapse_initial: bool,
    ) -> Result<usize, TreeError> {
        self.insert_nodes_inner(parent_id, position, nodes, collapse_initial, true)
    }

    fn insert_nodes_inner(
        &mut self,
        parent_id: &str,
        position: i32,
        nodes: Vec<pb::TreeNode>,
        collapse_initial: bool,
        rebuild_visible: bool,
    ) -> Result<usize, TreeError> {
        if nodes.is_empty() {
            return Ok(0);
        }
        let flat = flatten_nodes(nodes, parent_id, true)?;
        let inserted = flat.len();
        self.reserve(inserted);
        let first_new = self.nodes.len();
        let target_parent = if parent_id.is_empty() {
            None
        } else {
            Some(self.index_for_id(parent_id)?)
        };

        self.validate_new_ids(&flat)?;
        self.validate_new_parent_refs(&flat)?;
        let mut parent_ids = Vec::with_capacity(flat.len());
        for item in flat {
            let node_id = item.node.node_id.clone();
            let idx = self.nodes.len();
            self.id_to_index.insert(node_id, idx);
            self.nodes
                .push(TreeNodeRecord::from_proto(item.node, collapse_initial));
            parent_ids.push(item.parent_id);
        }

        let mut target_children = Vec::new();
        for (offset, parent_id) in parent_ids.into_iter().enumerate() {
            let idx = first_new + offset;
            let parent =
                if parent_id.is_empty() {
                    None
                } else {
                    Some(*self.id_to_index.get(&parent_id).ok_or_else(|| {
                        TreeError::MissingParent {
                            node_id: self.nodes[idx].id.clone(),
                            parent_id: parent_id.clone(),
                        }
                    })?)
                };
            if parent == Some(idx) {
                return Err(TreeError::Cycle(self.nodes[idx].id.clone()));
            }
            self.nodes[idx].parent = parent;
            if parent == target_parent {
                target_children.push(idx);
            } else if let Some(parent_idx) = parent {
                self.nodes[parent_idx].children.push(idx);
            } else {
                self.roots.push(idx);
            }
        }

        match target_parent {
            Some(parent_idx) => insert_child_indices(
                &mut self.nodes[parent_idx].children,
                position,
                target_children,
            ),
            None => insert_child_indices(&mut self.roots, position, target_children),
        }

        self.refresh_structure_metadata(rebuild_visible)?;
        Ok(inserted)
    }

    pub fn remove_nodes(
        &mut self,
        node_ids: &[String],
        recursive: bool,
    ) -> Result<usize, TreeError> {
        self.remove_nodes_inner(node_ids, recursive, true)
    }

    fn remove_nodes_inner(
        &mut self,
        node_ids: &[String],
        recursive: bool,
        rebuild_visible: bool,
    ) -> Result<usize, TreeError> {
        if node_ids.is_empty() {
            return Ok(0);
        }
        let mut remove = HashSet::new();
        for node_id in node_ids {
            let idx = self.index_for_id(node_id)?;
            if recursive {
                let mut stack = vec![idx];
                while let Some(current) = stack.pop() {
                    if !remove.insert(current) {
                        continue;
                    }
                    stack.extend(self.nodes[current].children.iter().copied());
                }
            } else {
                if !self.nodes[idx].children.is_empty() {
                    return Err(TreeError::InvalidArgument(format!(
                        "tree node {node_id} has children; recursive remove is required"
                    )));
                }
                remove.insert(idx);
            }
        }
        let removed = remove.len();
        self.compact_without(&remove);
        self.refresh_structure_metadata(rebuild_visible)?;
        Ok(removed)
    }

    pub fn move_nodes(
        &mut self,
        node_ids: &[String],
        new_parent_id: &str,
        position: i32,
    ) -> Result<usize, TreeError> {
        self.move_nodes_inner(node_ids, new_parent_id, position, true)
    }

    fn move_nodes_inner(
        &mut self,
        node_ids: &[String],
        new_parent_id: &str,
        position: i32,
        rebuild_visible: bool,
    ) -> Result<usize, TreeError> {
        if node_ids.is_empty() {
            return Ok(0);
        }
        let mut moving = Vec::with_capacity(node_ids.len());
        let mut seen = HashSet::with_capacity(node_ids.len());
        for node_id in node_ids {
            let idx = self.index_for_id(node_id)?;
            if seen.insert(idx) {
                moving.push(idx);
            }
        }
        let moving_set: HashSet<usize> = moving.iter().copied().collect();
        for &idx in &moving {
            let mut parent = self.nodes[idx].parent;
            while let Some(parent_idx) = parent {
                if moving_set.contains(&parent_idx) {
                    return Err(TreeError::InvalidArgument(format!(
                        "tree node {} cannot be moved with its ancestor",
                        self.nodes[idx].id
                    )));
                }
                parent = self.nodes[parent_idx].parent;
            }
        }

        let new_parent = if new_parent_id.is_empty() {
            None
        } else {
            Some(self.index_for_id(new_parent_id)?)
        };
        if let Some(parent_idx) = new_parent {
            for &idx in &moving {
                if idx == parent_idx || self.is_ancestor(idx, parent_idx) {
                    return Err(TreeError::InvalidArgument(format!(
                        "tree node {} cannot be moved into its own descendant",
                        self.nodes[idx].id
                    )));
                }
            }
        }

        self.roots.retain(|idx| !moving_set.contains(idx));
        for node in &mut self.nodes {
            node.children.retain(|idx| !moving_set.contains(idx));
        }
        for &idx in &moving {
            self.nodes[idx].parent = new_parent;
        }
        match new_parent {
            Some(parent_idx) => {
                insert_child_indices(&mut self.nodes[parent_idx].children, position, moving)
            }
            None => insert_child_indices(&mut self.roots, position, moving),
        }
        self.refresh_structure_metadata(rebuild_visible)?;
        Ok(moving_set.len())
    }

    pub fn update_node_cells(
        &mut self,
        updates: &[pb::NodeCellUpdate],
    ) -> Result<usize, TreeError> {
        let mut indexed = Vec::with_capacity(updates.len());
        for update in updates {
            indexed.push(self.index_for_id(&update.node_id)?);
        }

        let mut changed = 0usize;
        for (idx, update) in indexed.into_iter().zip(updates) {
            if let Some(existing) = self.nodes[idx]
                .cells
                .iter_mut()
                .find(|cell| cell.col == update.col)
            {
                *existing = update.clone();
            } else {
                self.nodes[idx].cells.push(update.clone());
            }
            changed += 1;
        }
        Ok(changed)
    }

    pub fn rename_node(
        &mut self,
        node_id: &str,
        col: i32,
        text: String,
    ) -> Result<pb::TreeNodeInfo, TreeError> {
        let update = pb::NodeCellUpdate {
            node_id: node_id.to_string(),
            col,
            value: Some(pb::CellValue {
                value: Some(pb::cell_value::Value::Text(text)),
            }),
            style: None,
            checked: None,
            picture: None,
            picture_align: None,
            dropdown: None,
            rich_text: None,
        };
        self.update_node_cells(&[update])?;
        self.node_info_by_id(node_id, 0, false)
    }

    pub fn set_expanded(
        &mut self,
        node_ids: &[String],
        expanded: bool,
        recursive: bool,
    ) -> Result<usize, TreeError> {
        if node_ids.is_empty() {
            return Ok(0);
        }
        let mut changed = 0usize;
        let mut visited = HashSet::new();
        let mut stack = Vec::with_capacity(node_ids.len());
        for node_id in node_ids {
            stack.push(self.index_for_id(node_id)?);
        }
        while let Some(idx) = stack.pop() {
            if !visited.insert(idx) {
                continue;
            }
            if self.nodes[idx].may_have_children() && self.nodes[idx].expanded != expanded {
                self.nodes[idx].expanded = expanded;
                changed += 1;
            }
            if recursive {
                stack.extend(self.nodes[idx].children.iter().copied());
            }
        }
        self.rebuild_visible();
        Ok(changed)
    }

    pub fn expanded_node_ids(&self) -> Vec<String> {
        self.nodes
            .iter()
            .filter(|node| node.expanded && node.may_have_children())
            .map(|node| node.id.clone())
            .collect()
    }

    pub fn set_expansion(&mut self, expanded_node_ids: &[String]) -> Result<(), TreeError> {
        let mut expanded = HashSet::with_capacity(expanded_node_ids.len());
        for node_id in expanded_node_ids {
            expanded.insert(self.index_for_id(node_id)?);
        }
        for (idx, node) in self.nodes.iter_mut().enumerate() {
            node.expanded = expanded.contains(&idx) && node.may_have_children();
        }
        self.rebuild_visible();
        Ok(())
    }

    pub fn expand_to_node(&mut self, node_id: &str) -> Result<i32, TreeError> {
        let idx = self.index_for_id(node_id)?;
        let mut parent = self.nodes[idx].parent;
        while let Some(parent_idx) = parent {
            self.nodes[parent_idx].expanded = true;
            parent = self.nodes[parent_idx].parent;
        }
        self.rebuild_visible();
        Ok(self
            .nodes
            .get(idx)
            .and_then(|node| node.visible_ordinal)
            .map_or(NO_ROW, usize_to_i32_saturating))
    }

    pub fn node_path(
        &self,
        node_id: &str,
        sep: &str,
        mode: i32,
    ) -> Result<pb::NodePathResponse, TreeError> {
        let idx = self.index_for_id(node_id)?;
        let sep = if sep.is_empty() { "/" } else { sep };
        let mut parts = Vec::new();
        let mut current = Some(idx);
        while let Some(node_idx) = current {
            parts.push(if mode == pb::NodePathMode::NodePathLabel as i32 {
                self.node_label(node_idx)
            } else {
                self.nodes[node_idx].id.clone()
            });
            current = self.nodes[node_idx].parent;
        }
        parts.reverse();
        Ok(pb::NodePathResponse {
            path: parts.join(sep),
            found: true,
        })
    }

    pub fn node_by_path(
        &self,
        path: &str,
        sep: &str,
        mode: i32,
        fixed_rows: i32,
        include_children: bool,
    ) -> pb::TreeNodeInfo {
        let sep = if sep.is_empty() { "/" } else { sep };
        let parts: Vec<&str> = path.split(sep).filter(|part| !part.is_empty()).collect();
        if parts.is_empty() {
            return missing_node_info();
        }
        let mut siblings: &[usize] = &self.roots;
        let mut found = None;
        for part in parts {
            found = siblings.iter().copied().find(|idx| {
                let node = &self.nodes[*idx];
                if mode == pb::NodePathMode::NodePathLabel as i32 {
                    self.node_label(*idx) == part
                } else {
                    node.id == part
                }
            });
            let Some(idx) = found else {
                return missing_node_info();
            };
            siblings = &self.nodes[idx].children;
        }
        found
            .map(|idx| self.node_info(idx, fixed_rows, include_children))
            .unwrap_or_else(missing_node_info)
    }

    pub fn select_nodes(
        &mut self,
        active_node_id: &str,
        selected_node_ids: &[String],
    ) -> Result<(), TreeError> {
        let active = if active_node_id.is_empty() {
            None
        } else {
            Some(self.index_for_id(active_node_id)?)
        };
        let mut selected = HashSet::with_capacity(selected_node_ids.len().saturating_add(1));
        for node_id in selected_node_ids {
            selected.insert(self.index_for_id(node_id)?);
        }
        if let Some(active) = active {
            selected.insert(active);
        }

        self.selected.clear();
        self.selected = selected;
        self.active = active;
        Ok(())
    }

    pub fn selection_state(&self, fixed_rows: i32) -> pb::NodeSelectionState {
        let active_node_id = self
            .active
            .map(|idx| self.nodes[idx].id.clone())
            .unwrap_or_default();
        let active_row = self.active.map_or(NO_ROW, |idx| {
            self.nodes[idx].visible_ordinal.map_or(NO_ROW, |ordinal| {
                fixed_rows.saturating_add(usize_to_i32_saturating(ordinal))
            })
        });
        let mut selected_node_ids: Vec<String> = self
            .selected
            .iter()
            .map(|idx| self.nodes[*idx].id.clone())
            .collect();
        selected_node_ids.sort();
        pb::NodeSelectionState {
            active_node_id,
            selected_node_ids,
            active_row,
        }
    }

    pub fn set_checked_nodes(
        &mut self,
        node_ids: &[String],
        state: i32,
    ) -> Result<pb::CheckedNodes, TreeError> {
        let mut indices = Vec::with_capacity(node_ids.len());
        for node_id in node_ids {
            indices.push(self.index_for_id(node_id)?);
        }
        for idx in indices {
            if state == pb::CheckedState::CheckedChecked as i32 {
                self.checked.insert(idx);
            } else {
                self.checked.remove(&idx);
            }
        }
        Ok(self.checked_nodes())
    }

    pub fn checked_nodes(&self) -> pb::CheckedNodes {
        let mut fully_checked: Vec<String> = self
            .checked
            .iter()
            .map(|idx| self.nodes[*idx].id.clone())
            .collect();
        fully_checked.sort();
        pb::CheckedNodes {
            fully_checked,
            indeterminate: Vec::new(),
        }
    }

    pub fn set_children_state(&mut self, node_id: &str, state: i32) -> Result<(), TreeError> {
        let idx = self.index_for_id(node_id)?;
        self.nodes[idx].children_state = state;
        if state == pb::NodeChildrenState::NodeLeaf as i32 {
            self.nodes[idx].expanded = false;
        }
        Ok(())
    }

    pub fn sort_tree(&mut self, sort_columns: &[pb::SortColumn], recursive: bool) {
        if sort_columns.is_empty() {
            return;
        }
        let mut roots = self.roots.clone();
        roots.sort_by(|a, b| self.compare_nodes(*a, *b, sort_columns));
        self.roots = roots;
        if recursive {
            for idx in 0..self.nodes.len() {
                let mut children = self.nodes[idx].children.clone();
                children.sort_by(|a, b| self.compare_nodes(*a, *b, sort_columns));
                self.nodes[idx].children = children;
            }
        }
        self.rebuild_visible();
    }

    pub fn find_tree(
        &mut self,
        request: &pb::FindTreeRequest,
        fixed_rows: i32,
    ) -> Result<pb::FindTreeResponse, TreeError> {
        let candidates: Vec<usize> = if request.visible_only {
            self.visible.clone()
        } else {
            (0..self.nodes.len()).collect()
        };
        if candidates.is_empty() {
            return Ok(missing_find_response());
        }
        let start_pos = if request.start_node_id.is_empty() {
            0
        } else {
            let start_idx = self.index_for_id(&request.start_node_id)?;
            candidates
                .iter()
                .position(|idx| *idx == start_idx)
                .map_or(0, |pos| pos.saturating_add(1))
        };
        for offset in 0..candidates.len() {
            let idx = candidates[(start_pos + offset) % candidates.len()];
            if self.node_matches_query(idx, request.col, request.query.as_ref())? {
                if request.auto_expand_ancestors {
                    let node_id = self.nodes[idx].id.clone();
                    let _ = self.expand_to_node(&node_id)?;
                }
                let row = self.nodes[idx].visible_ordinal.map_or(NO_ROW, |ordinal| {
                    fixed_rows.saturating_add(usize_to_i32_saturating(ordinal))
                });
                return Ok(pb::FindTreeResponse {
                    found: true,
                    node_id: self.nodes[idx].id.clone(),
                    row,
                });
            }
        }
        Ok(missing_find_response())
    }

    pub fn filter_tree(&mut self, request: &pb::FilterTreeRequest) -> Result<(), TreeError> {
        let mut matches = Vec::with_capacity(self.nodes.len());
        for idx in 0..self.nodes.len() {
            matches.push(self.node_matches_filter_query(
                idx,
                request.col,
                request.query.as_ref(),
            )?);
        }

        let mut visible = HashSet::new();
        for (idx, is_match) in matches.into_iter().enumerate() {
            if is_match {
                visible.insert(idx);
                if request.keep_ancestors_of_matches {
                    let mut parent = self.nodes[idx].parent;
                    while let Some(parent_idx) = parent {
                        visible.insert(parent_idx);
                        self.nodes[parent_idx].expanded = true;
                        parent = self.nodes[parent_idx].parent;
                    }
                }
                if request.keep_descendants_of_matches {
                    let mut stack = self.nodes[idx].children.clone();
                    while let Some(child_idx) = stack.pop() {
                        visible.insert(child_idx);
                        stack.extend(self.nodes[child_idx].children.iter().copied());
                    }
                }
            }
        }
        for &idx in &visible {
            let mut parent = self.nodes[idx].parent;
            while let Some(parent_idx) = parent {
                self.nodes[parent_idx].expanded = true;
                parent = self.nodes[parent_idx].parent;
            }
        }
        self.visible_filter = Some(visible);
        self.rebuild_visible();
        Ok(())
    }

    pub fn clear_filter(&mut self) {
        self.visible_filter = None;
        self.rebuild_visible();
    }

    pub fn node_info_by_id(
        &self,
        node_id: &str,
        fixed_rows: i32,
        include_children: bool,
    ) -> Result<pb::TreeNodeInfo, TreeError> {
        let idx = self.index_for_id(node_id)?;
        Ok(self.node_info(idx, fixed_rows, include_children))
    }

    pub fn node_info_by_row(
        &self,
        fixed_rows: i32,
        row: i32,
        include_children: bool,
    ) -> Option<pb::TreeNodeInfo> {
        self.node_index_at_row(fixed_rows, row)
            .map(|idx| self.node_info(idx, fixed_rows, include_children))
    }

    pub fn children_info(
        &self,
        parent_id: &str,
        fixed_rows: i32,
        offset: i32,
        count: i32,
    ) -> Result<pb::TreeNodeList, TreeError> {
        let children: &[usize] = if parent_id.is_empty() {
            &self.roots
        } else {
            let parent_idx = self.index_for_id(parent_id)?;
            &self.nodes[parent_idx].children
        };
        Ok(self.info_list(children.iter().copied(), fixed_rows, offset, count))
    }

    pub fn visible_info(&self, fixed_rows: i32, offset: i32, count: i32) -> pb::TreeNodeList {
        self.info_list(self.visible.iter().copied(), fixed_rows, offset, count)
    }

    pub fn node_index_at_row(&self, fixed_rows: i32, row: i32) -> Option<usize> {
        if row < fixed_rows {
            return None;
        }
        let ordinal = (row - fixed_rows) as usize;
        self.visible.get(ordinal).copied()
    }

    pub fn node_id_at_row(&self, fixed_rows: i32, row: i32) -> Option<&str> {
        self.node_index_at_row(fixed_rows, row)
            .map(|idx| self.nodes[idx].id.as_str())
    }

    pub fn row_has_children(&self, fixed_rows: i32, row: i32) -> bool {
        self.node_index_at_row(fixed_rows, row)
            .is_some_and(|idx| self.nodes[idx].may_have_children())
    }

    pub fn row_is_expanded(&self, fixed_rows: i32, row: i32) -> Option<bool> {
        self.node_index_at_row(fixed_rows, row)
            .map(|idx| self.nodes[idx].expanded)
    }

    pub fn row_children_state(&self, fixed_rows: i32, row: i32) -> Option<i32> {
        self.node_index_at_row(fixed_rows, row)
            .map(|idx| self.nodes[idx].children_state)
    }

    pub fn row_level(&self, fixed_rows: i32, row: i32) -> Option<i32> {
        self.node_index_at_row(fixed_rows, row)
            .map(|idx| self.nodes[idx].level)
    }

    fn reserve(&mut self, additional: usize) {
        self.nodes.reserve(additional);
        self.id_to_index.reserve(additional);
        self.visible.reserve(additional);
    }

    fn validate_new_ids(&self, flat: &[FlatTreeNode]) -> Result<(), TreeError> {
        let mut seen = HashSet::with_capacity(flat.len());
        for item in flat {
            if item.node.node_id.is_empty() {
                return Err(TreeError::InvalidArgument(
                    "tree node id must not be empty".to_string(),
                ));
            }
            if self.id_to_index.contains_key(&item.node.node_id) || !seen.insert(&item.node.node_id)
            {
                return Err(TreeError::DuplicateNodeId(item.node.node_id.clone()));
            }
        }
        Ok(())
    }

    fn validate_new_parent_refs(&self, flat: &[FlatTreeNode]) -> Result<(), TreeError> {
        let mut parent_by_new_id = HashMap::with_capacity(flat.len());
        for item in flat {
            parent_by_new_id.insert(item.node.node_id.as_str(), item.parent_id.as_str());
        }

        for item in flat {
            let parent_id = item.parent_id.as_str();
            if parent_id.is_empty() || self.id_to_index.contains_key(parent_id) {
                continue;
            }
            if !parent_by_new_id.contains_key(parent_id) {
                return Err(TreeError::MissingParent {
                    node_id: item.node.node_id.clone(),
                    parent_id: parent_id.to_string(),
                });
            }
        }

        for item in flat {
            let mut seen = HashSet::with_capacity(flat.len());
            let mut current = item.node.node_id.as_str();
            loop {
                if !seen.insert(current) {
                    return Err(TreeError::Cycle(current.to_string()));
                }
                let Some(parent_id) = parent_by_new_id.get(current).copied() else {
                    break;
                };
                if parent_id.is_empty() || self.id_to_index.contains_key(parent_id) {
                    break;
                }
                current = parent_id;
            }
        }

        Ok(())
    }

    fn refresh_structure_metadata(&mut self, rebuild_visible: bool) -> Result<(), TreeError> {
        if !rebuild_visible {
            return Ok(());
        }
        self.refresh_metadata()?;
        self.rebuild_visible();
        Ok(())
    }

    fn add_flat_nodes(
        &mut self,
        flat: Vec<FlatTreeNode>,
        collapse_initial: bool,
    ) -> Result<(), TreeError> {
        self.validate_new_ids(&flat)?;
        self.validate_new_parent_refs(&flat)?;
        let mut parent_ids = Vec::with_capacity(flat.len());
        for item in flat {
            let node_id = item.node.node_id.clone();
            let idx = self.nodes.len();
            self.id_to_index.insert(node_id, idx);
            self.nodes
                .push(TreeNodeRecord::from_proto(item.node, collapse_initial));
            parent_ids.push(item.parent_id);
        }
        for (idx, parent_id) in parent_ids.into_iter().enumerate() {
            if parent_id.is_empty() {
                self.roots.push(idx);
                continue;
            }
            let parent_idx =
                *self
                    .id_to_index
                    .get(&parent_id)
                    .ok_or_else(|| TreeError::MissingParent {
                        node_id: self.nodes[idx].id.clone(),
                        parent_id: parent_id.clone(),
                    })?;
            if parent_idx == idx {
                return Err(TreeError::Cycle(self.nodes[idx].id.clone()));
            }
            self.nodes[idx].parent = Some(parent_idx);
            self.nodes[parent_idx].children.push(idx);
        }
        Ok(())
    }

    fn refresh_metadata(&mut self) -> Result<(), TreeError> {
        let mut marks = vec![0u8; self.nodes.len()];
        let roots = self.roots.clone();
        for root in roots {
            self.refresh_node(root, 0, &mut marks)?;
        }
        for idx in 0..self.nodes.len() {
            if marks[idx] == 0 {
                self.refresh_node(idx, 0, &mut marks)?;
            }
        }
        Ok(())
    }

    fn refresh_node(&mut self, idx: usize, level: i32, marks: &mut [u8]) -> Result<(), TreeError> {
        match marks[idx] {
            1 => return Err(TreeError::Cycle(self.nodes[idx].id.clone())),
            2 => return Ok(()),
            _ => {}
        }
        marks[idx] = 1;
        self.nodes[idx].level = level;

        let has_children = !self.nodes[idx].children.is_empty();
        if has_children {
            if self.nodes[idx].children_state != pb::NodeChildrenState::NodeChildrenError as i32 {
                self.nodes[idx].children_state = pb::NodeChildrenState::NodeChildrenLoaded as i32;
            }
        } else if self.nodes[idx].children_state
            == pb::NodeChildrenState::NodeChildrenUnknown as i32
        {
            self.nodes[idx].children_state = pb::NodeChildrenState::NodeLeaf as i32;
            self.nodes[idx].expanded = false;
        } else if self.nodes[idx].children_state == pb::NodeChildrenState::NodeLeaf as i32 {
            self.nodes[idx].expanded = false;
        }

        let children = self.nodes[idx].children.clone();
        for child in children {
            self.refresh_node(child, level.saturating_add(1), marks)?;
        }
        marks[idx] = 2;
        Ok(())
    }

    fn rebuild_visible(&mut self) {
        for node in &mut self.nodes {
            node.visible_ordinal = None;
        }
        self.visible.clear();
        let mut stack = Vec::with_capacity(self.roots.len());
        stack.extend(self.roots.iter().rev().copied());
        while let Some(idx) = stack.pop() {
            let passes_filter = self
                .visible_filter
                .as_ref()
                .map_or(true, |filter| filter.contains(&idx));
            if passes_filter {
                self.nodes[idx].visible_ordinal = Some(self.visible.len());
                self.visible.push(idx);
            }
            if self.nodes[idx].expanded {
                stack.extend(self.nodes[idx].children.iter().rev().copied());
            }
        }
    }

    fn compact_without(&mut self, remove: &HashSet<usize>) {
        let mut old_to_new = vec![None; self.nodes.len()];
        let mut next_nodes = Vec::with_capacity(self.nodes.len().saturating_sub(remove.len()));
        for (old_idx, node) in self.nodes.iter().enumerate() {
            if remove.contains(&old_idx) {
                continue;
            }
            let new_idx = next_nodes.len();
            old_to_new[old_idx] = Some(new_idx);
            let mut next = node.clone();
            next.parent = None;
            next.children.clear();
            next.visible_ordinal = None;
            next_nodes.push(next);
        }

        let old_nodes = std::mem::replace(&mut self.nodes, next_nodes);
        self.id_to_index.clear();
        self.roots.clear();
        for (old_idx, old_node) in old_nodes.iter().enumerate() {
            let Some(new_idx) = old_to_new[old_idx] else {
                continue;
            };
            self.id_to_index
                .insert(self.nodes[new_idx].id.clone(), new_idx);
            self.nodes[new_idx].parent = old_node.parent.and_then(|idx| old_to_new[idx]);
            self.nodes[new_idx].children = old_node
                .children
                .iter()
                .filter_map(|idx| old_to_new[*idx])
                .collect();
            if self.nodes[new_idx].parent.is_none() {
                self.roots.push(new_idx);
            }
        }
        self.selected = self
            .selected
            .iter()
            .filter_map(|idx| old_to_new[*idx])
            .collect();
        self.checked = self
            .checked
            .iter()
            .filter_map(|idx| old_to_new[*idx])
            .collect();
        self.visible_filter = self
            .visible_filter
            .as_ref()
            .map(|filter| filter.iter().filter_map(|idx| old_to_new[*idx]).collect());
        self.active = self.active.and_then(|idx| old_to_new[idx]);
    }

    fn index_for_id(&self, node_id: &str) -> Result<usize, TreeError> {
        self.id_to_index
            .get(node_id)
            .copied()
            .ok_or_else(|| TreeError::NotFound(node_id.to_string()))
    }

    fn is_ancestor(&self, ancestor: usize, node: usize) -> bool {
        let mut parent = self.nodes[node].parent;
        while let Some(parent_idx) = parent {
            if parent_idx == ancestor {
                return true;
            }
            parent = self.nodes[parent_idx].parent;
        }
        false
    }

    fn node_info(&self, idx: usize, fixed_rows: i32, include_children: bool) -> pb::TreeNodeInfo {
        let node = &self.nodes[idx];
        let row = node.visible_ordinal.map_or(NO_ROW, |ordinal| {
            fixed_rows.saturating_add(usize_to_i32_saturating(ordinal))
        });
        pb::TreeNodeInfo {
            node_id: node.id.clone(),
            parent_node_id: node
                .parent
                .map(|parent_idx| self.nodes[parent_idx].id.clone())
                .unwrap_or_default(),
            row,
            level: node.level,
            is_expanded: node.expanded,
            children_state: node.children_state,
            child_count: usize_to_i32_saturating(node.children.len()),
            child_node_ids: if include_children {
                node.children
                    .iter()
                    .map(|child_idx| self.nodes[*child_idx].id.clone())
                    .collect()
            } else {
                Vec::new()
            },
            found: true,
        }
    }

    fn node_label(&self, idx: usize) -> String {
        self.nodes[idx]
            .cells
            .iter()
            .min_by_key(|cell| cell.col)
            .and_then(|cell| cell.value.as_ref())
            .and_then(|value| value.value.as_ref())
            .map(|value| match value {
                pb::cell_value::Value::Text(text) => text.clone(),
                pb::cell_value::Value::Number(value) => value.to_string(),
                pb::cell_value::Value::Flag(value) => value.to_string(),
                pb::cell_value::Value::Raw(value) => format!("{value:?}"),
                pb::cell_value::Value::Timestamp(value) => value.to_string(),
            })
            .filter(|label| !label.is_empty())
            .unwrap_or_else(|| self.nodes[idx].id.clone())
    }

    fn node_cell_text(&self, idx: usize, col: i32) -> String {
        self.nodes[idx]
            .cells
            .iter()
            .find(|cell| cell.col == col)
            .and_then(|cell| cell.value.as_ref())
            .and_then(|value| value.value.as_ref())
            .map(|value| match value {
                pb::cell_value::Value::Text(text) => text.clone(),
                pb::cell_value::Value::Number(value) => value.to_string(),
                pb::cell_value::Value::Flag(value) => value.to_string(),
                pb::cell_value::Value::Raw(value) => format!("{value:?}"),
                pb::cell_value::Value::Timestamp(value) => value.to_string(),
            })
            .unwrap_or_default()
    }

    fn compare_nodes(
        &self,
        left: usize,
        right: usize,
        sort_columns: &[pb::SortColumn],
    ) -> std::cmp::Ordering {
        for column in sort_columns {
            let descending = column.order == Some(pb::SortOrder::SortDescending as i32);
            let numeric = column.r#type == Some(pb::SortType::Numeric as i32);
            let mut ordering = if numeric {
                let left_num = self.node_cell_text(left, column.col).parse::<f64>().ok();
                let right_num = self.node_cell_text(right, column.col).parse::<f64>().ok();
                left_num
                    .partial_cmp(&right_num)
                    .unwrap_or(std::cmp::Ordering::Equal)
            } else {
                let left_text = self.node_cell_text(left, column.col);
                let right_text = self.node_cell_text(right, column.col);
                if column.r#type == Some(pb::SortType::String as i32) {
                    left_text.cmp(&right_text)
                } else {
                    left_text
                        .to_ascii_lowercase()
                        .cmp(&right_text.to_ascii_lowercase())
                }
            };
            if descending {
                ordering = ordering.reverse();
            }
            if ordering != std::cmp::Ordering::Equal {
                return ordering;
            }
        }
        self.nodes[left].id.cmp(&self.nodes[right].id)
    }

    fn node_matches_query(
        &self,
        idx: usize,
        col: i32,
        query: Option<&pb::find_tree_request::Query>,
    ) -> Result<bool, TreeError> {
        let text = self.node_cell_text(idx, col);
        match query {
            Some(pb::find_tree_request::Query::TextQuery(query)) => {
                let haystack = if query.case_sensitive {
                    text
                } else {
                    text.to_ascii_lowercase()
                };
                let needle = if query.case_sensitive {
                    query.text.clone()
                } else {
                    query.text.to_ascii_lowercase()
                };
                Ok(if query.full_match {
                    haystack == needle
                } else {
                    haystack.contains(&needle)
                })
            }
            Some(pb::find_tree_request::Query::RegexQuery(query)) => {
                #[cfg(feature = "regex")]
                {
                    regex::Regex::new(&query.pattern)
                        .map(|regex| regex.is_match(&text))
                        .map_err(|err| TreeError::InvalidArgument(err.to_string()))
                }
                #[cfg(not(feature = "regex"))]
                {
                    let _ = query;
                    Err(TreeError::InvalidArgument(
                        "regex feature is not enabled".to_string(),
                    ))
                }
            }
            None => Ok(false),
        }
    }

    fn node_matches_filter_query(
        &self,
        idx: usize,
        col: i32,
        query: Option<&pb::filter_tree_request::Query>,
    ) -> Result<bool, TreeError> {
        let text = self.node_cell_text(idx, col);
        match query {
            Some(pb::filter_tree_request::Query::TextQuery(query)) => {
                let haystack = if query.case_sensitive {
                    text
                } else {
                    text.to_ascii_lowercase()
                };
                let needle = if query.case_sensitive {
                    query.text.clone()
                } else {
                    query.text.to_ascii_lowercase()
                };
                Ok(if query.full_match {
                    haystack == needle
                } else {
                    haystack.contains(&needle)
                })
            }
            Some(pb::filter_tree_request::Query::RegexQuery(query)) => {
                #[cfg(feature = "regex")]
                {
                    regex::Regex::new(&query.pattern)
                        .map(|regex| regex.is_match(&text))
                        .map_err(|err| TreeError::InvalidArgument(err.to_string()))
                }
                #[cfg(not(feature = "regex"))]
                {
                    let _ = query;
                    Err(TreeError::InvalidArgument(
                        "regex feature is not enabled".to_string(),
                    ))
                }
            }
            None => Ok(false),
        }
    }

    fn info_list(
        &self,
        iter: impl Iterator<Item = usize>,
        fixed_rows: i32,
        offset: i32,
        count: i32,
    ) -> pb::TreeNodeList {
        let all: Vec<usize> = iter.collect();
        let total_count = usize_to_i32_saturating(all.len());
        let start = offset.max(0) as usize;
        let end = if count <= 0 {
            all.len()
        } else {
            start.saturating_add(count as usize).min(all.len())
        };
        let nodes = if start >= all.len() {
            Vec::new()
        } else {
            all[start..end]
                .iter()
                .map(|idx| self.node_info(*idx, fixed_rows, false))
                .collect()
        };
        pb::TreeNodeList { nodes, total_count }
    }
}

fn missing_node_info() -> pb::TreeNodeInfo {
    pb::TreeNodeInfo {
        node_id: String::new(),
        parent_node_id: String::new(),
        row: NO_ROW,
        level: 0,
        is_expanded: false,
        children_state: pb::NodeChildrenState::NodeChildrenUnknown as i32,
        child_count: 0,
        child_node_ids: Vec::new(),
        found: false,
    }
}

fn missing_find_response() -> pb::FindTreeResponse {
    pb::FindTreeResponse {
        found: false,
        node_id: String::new(),
        row: NO_ROW,
    }
}

fn insert_child_indices(target: &mut Vec<usize>, position: i32, mut incoming: Vec<usize>) {
    if incoming.is_empty() {
        return;
    }
    if position < 0 || position as usize >= target.len() {
        target.append(&mut incoming);
        return;
    }
    let pos = position as usize;
    target.reserve(incoming.len());
    target.splice(pos..pos, incoming);
}

fn flatten_nodes(
    nodes: Vec<pb::TreeNode>,
    inherited_parent: &str,
    strict_parent: bool,
) -> Result<Vec<FlatTreeNode>, TreeError> {
    let mut flat = Vec::with_capacity(nodes.len());
    let mut stack: Vec<(pb::TreeNode, String)> = nodes
        .into_iter()
        .rev()
        .map(|node| (node, inherited_parent.to_string()))
        .collect();
    while let Some((mut node, inherited_parent)) = stack.pop() {
        if node.node_id.is_empty() {
            return Err(TreeError::InvalidArgument(
                "tree node id must not be empty".to_string(),
            ));
        }
        let parent_id = if strict_parent {
            if !node.parent_id.is_empty() && node.parent_id != inherited_parent {
                return Err(TreeError::InvalidArgument(format!(
                    "tree node {} parent_id {} does not match insertion parent {}",
                    node.node_id, node.parent_id, inherited_parent
                )));
            }
            inherited_parent
        } else if !inherited_parent.is_empty()
            && !node.parent_id.is_empty()
            && node.parent_id != inherited_parent
        {
            return Err(TreeError::InvalidArgument(format!(
                "tree node {} parent_id {} does not match nested parent {}",
                node.node_id, node.parent_id, inherited_parent
            )));
        } else if node.parent_id.is_empty() {
            inherited_parent
        } else {
            node.parent_id.clone()
        };

        let children = std::mem::take(&mut node.children);
        let child_parent = node.node_id.clone();
        for child in children.into_iter().rev() {
            stack.push((child, child_parent.clone()));
        }
        node.parent_id = parent_id.clone();
        flat.push(FlatTreeNode { node, parent_id });
    }
    Ok(flat)
}

pub fn load_tree(
    grid: &mut VolvoxGrid,
    request: pb::LoadTreeRequest,
) -> Result<pb::LoadTreeResponse, TreeError> {
    let mut next = if request.replace || grid.tree.is_empty() {
        TreeState::default()
    } else {
        grid.tree.clone()
    };
    if request.replace || next.is_empty() {
        next.load(request.nodes, request.collapse_initial)?;
    } else {
        next.insert_nodes("", -1, request.nodes, request.collapse_initial)?;
    }
    let warnings = project_tree_state(grid, &next);
    let response = pb::LoadTreeResponse {
        node_count: usize_to_i32_saturating(next.node_count()),
        visible_count: usize_to_i32_saturating(next.visible_count()),
        warnings,
    };
    grid.tree = next;
    Ok(response)
}

pub fn insert_nodes(
    grid: &mut VolvoxGrid,
    request: pb::InsertNodesRequest,
) -> Result<pb::InsertNodesResponse, TreeError> {
    let mut tree = std::mem::take(&mut grid.tree);
    let inserted = tree.insert_nodes(&request.parent_id, request.position, request.nodes, false);
    match inserted {
        Ok(inserted_count) => {
            project_tree_state(grid, &tree);
            let visible_count = usize_to_i32_saturating(tree.visible_count());
            grid.tree = tree;
            Ok(pb::InsertNodesResponse {
                inserted_count: usize_to_i32_saturating(inserted_count),
                visible_count,
            })
        }
        Err(err) => {
            grid.tree = tree;
            Err(err)
        }
    }
}

pub fn remove_nodes(
    grid: &mut VolvoxGrid,
    request: pb::RemoveNodesRequest,
) -> Result<pb::RemoveNodesResponse, TreeError> {
    let mut tree = std::mem::take(&mut grid.tree);
    let removed = tree.remove_nodes(&request.node_ids, request.recursive);
    match removed {
        Ok(removed_count) => {
            project_tree_state(grid, &tree);
            let visible_count = usize_to_i32_saturating(tree.visible_count());
            grid.tree = tree;
            Ok(pb::RemoveNodesResponse {
                removed_count: usize_to_i32_saturating(removed_count),
                visible_count,
            })
        }
        Err(err) => {
            grid.tree = tree;
            Err(err)
        }
    }
}

pub fn move_nodes(
    grid: &mut VolvoxGrid,
    request: pb::MoveNodesRequest,
) -> Result<pb::MoveNodesResponse, TreeError> {
    let mut tree = std::mem::take(&mut grid.tree);
    let moved = tree.move_nodes(&request.node_ids, &request.new_parent_id, request.position);
    match moved {
        Ok(moved_count) => {
            project_tree_state(grid, &tree);
            let visible_count = usize_to_i32_saturating(tree.visible_count());
            grid.tree = tree;
            Ok(pb::MoveNodesResponse {
                moved_count: usize_to_i32_saturating(moved_count),
                visible_count,
            })
        }
        Err(err) => {
            grid.tree = tree;
            Err(err)
        }
    }
}

pub fn update_node_cells(
    grid: &mut VolvoxGrid,
    request: pb::UpdateNodeCellsRequest,
) -> Result<pb::WriteResult, TreeError> {
    let mut tree = std::mem::take(&mut grid.tree);
    let updated = tree.update_node_cells(&request.cells);
    match updated {
        Ok(_) => {
            let result = project_tree_state_with_write_result(grid, &tree, request.atomic);
            grid.tree = tree;
            Ok(result)
        }
        Err(err) => {
            grid.tree = tree;
            Err(err)
        }
    }
}

pub fn rename_node(
    grid: &mut VolvoxGrid,
    request: pb::RenameNodeRequest,
) -> Result<pb::RenameNodeResponse, TreeError> {
    let mut tree = std::mem::take(&mut grid.tree);
    let renamed = tree.rename_node(&request.node_id, request.col, request.text);
    match renamed {
        Ok(_) => {
            project_tree_state(grid, &tree);
            let node = tree.node_info_by_id(&request.node_id, grid.fixed_rows, true)?;
            grid.tree = tree;
            Ok(pb::RenameNodeResponse { node: Some(node) })
        }
        Err(err) => {
            grid.tree = tree;
            Err(err)
        }
    }
}

pub fn update_tree(
    grid: &mut VolvoxGrid,
    request: pb::UpdateTreeRequest,
) -> Result<pb::UpdateTreeResponse, TreeError> {
    let original = std::mem::take(&mut grid.tree);
    let mut tree = original.clone();
    let result = (|| {
        let mut inserted_count = 0usize;
        let mut removed_count = 0usize;
        let mut moved_count = 0usize;
        let mut renamed_count = 0usize;
        let mut structure_changed = false;

        for remove in &request.removes {
            let removed = tree.remove_nodes_inner(&remove.node_ids, remove.recursive, false)?;
            structure_changed |= removed > 0;
            removed_count += removed;
        }
        for mv in &request.moves {
            let moved =
                tree.move_nodes_inner(&mv.node_ids, &mv.new_parent_id, mv.position, false)?;
            structure_changed |= moved > 0;
            moved_count += moved;
        }
        for add in request.adds {
            let inserted =
                tree.insert_nodes_inner(&add.parent_id, add.position, add.nodes, false, false)?;
            structure_changed |= inserted > 0;
            inserted_count += inserted;
        }
        for rename in request.renames {
            tree.rename_node(&rename.node_id, rename.col, rename.text)?;
            renamed_count += 1;
        }
        for update in request.cell_updates {
            tree.update_node_cells(&update.cells)?;
        }
        if structure_changed {
            tree.refresh_structure_metadata(true)?;
        }

        Ok::<_, TreeError>((inserted_count, removed_count, moved_count, renamed_count))
    })();
    match result {
        Ok((inserted_count, removed_count, moved_count, renamed_count)) => {
            project_tree_state(grid, &tree);
            let visible_count = usize_to_i32_saturating(tree.visible_count());
            grid.tree = tree;
            Ok(pb::UpdateTreeResponse {
                inserted_count: usize_to_i32_saturating(inserted_count),
                removed_count: usize_to_i32_saturating(removed_count),
                moved_count: usize_to_i32_saturating(moved_count),
                renamed_count: usize_to_i32_saturating(renamed_count),
                visible_count,
            })
        }
        Err(err) => {
            grid.tree = original;
            Err(err)
        }
    }
}

pub fn expand_nodes(
    grid: &mut VolvoxGrid,
    request: pb::ExpandNodesRequest,
) -> Result<pb::ExpandNodesResponse, TreeError> {
    set_nodes_expanded(grid, &request.node_ids, true, request.recursive).map(
        |(expanded_count, visible_count)| pb::ExpandNodesResponse {
            expanded_count,
            visible_count,
        },
    )
}

pub fn collapse_nodes(
    grid: &mut VolvoxGrid,
    request: pb::CollapseNodesRequest,
) -> Result<pb::CollapseNodesResponse, TreeError> {
    set_nodes_expanded(grid, &request.node_ids, false, request.recursive).map(
        |(collapsed_count, visible_count)| pb::CollapseNodesResponse {
            collapsed_count,
            visible_count,
        },
    )
}

pub fn expand_to_node(
    grid: &mut VolvoxGrid,
    request: pb::ExpandToNodeRequest,
) -> Result<pb::ExpandToNodeResponse, TreeError> {
    let mut tree = std::mem::take(&mut grid.tree);
    let row = tree.expand_to_node(&request.node_id);
    match row {
        Ok(ordinal) => {
            project_tree_state(grid, &tree);
            let row = if ordinal < 0 {
                NO_ROW
            } else {
                grid.fixed_rows.saturating_add(ordinal)
            };
            let visible_count = usize_to_i32_saturating(tree.visible_count());
            grid.tree = tree;
            Ok(pb::ExpandToNodeResponse {
                found: row >= 0,
                row,
                visible_count,
            })
        }
        Err(err) => {
            grid.tree = tree;
            Err(err)
        }
    }
}

pub fn get_tree_node(
    grid: &VolvoxGrid,
    request: pb::GetTreeNodeRequest,
) -> Result<pb::TreeNodeInfo, TreeError> {
    match request.address {
        Some(pb::get_tree_node_request::Address::NodeId(node_id)) => {
            grid.tree
                .node_info_by_id(&node_id, grid.fixed_rows, request.include_children)
        }
        Some(pb::get_tree_node_request::Address::Row(row)) => grid
            .tree
            .node_info_by_row(grid.fixed_rows, row, request.include_children)
            .ok_or_else(|| TreeError::NotFound(format!("row {row}"))),
        None => Err(TreeError::InvalidArgument(
            "tree node request needs node_id or row".to_string(),
        )),
    }
}

pub fn get_children(
    grid: &VolvoxGrid,
    request: pb::GetChildrenRequest,
) -> Result<pb::TreeNodeList, TreeError> {
    let _visible_only = request.visible_only;
    grid.tree
        .children_info(&request.parent_id, grid.fixed_rows, 0, 0)
}

pub fn get_visible_nodes(
    grid: &VolvoxGrid,
    request: pb::GetVisibleNodesRequest,
) -> pb::TreeNodeList {
    grid.tree
        .visible_info(grid.fixed_rows, request.start, request.count)
}

pub fn get_expansion(grid: &VolvoxGrid) -> pb::ExpansionState {
    pb::ExpansionState {
        expanded_node_ids: grid.tree.expanded_node_ids(),
    }
}

pub fn set_expansion(
    grid: &mut VolvoxGrid,
    request: pb::SetExpansionRequest,
) -> Result<pb::SetExpansionResponse, TreeError> {
    let mut tree = std::mem::take(&mut grid.tree);
    let state = request
        .state
        .as_ref()
        .map(|state| state.expanded_node_ids.as_slice())
        .unwrap_or(&[]);
    let result = tree.set_expansion(state);
    match result {
        Ok(()) => {
            project_tree_state(grid, &tree);
            let visible_count = usize_to_i32_saturating(tree.visible_count());
            grid.tree = tree;
            Ok(pb::SetExpansionResponse { visible_count })
        }
        Err(err) => {
            grid.tree = tree;
            Err(err)
        }
    }
}

pub fn get_node_path(
    grid: &VolvoxGrid,
    request: pb::GetNodePathRequest,
) -> Result<pb::NodePathResponse, TreeError> {
    grid.tree
        .node_path(&request.node_id, &request.sep, request.mode)
}

pub fn get_node_by_path(grid: &VolvoxGrid, request: pb::GetNodeByPathRequest) -> pb::TreeNodeInfo {
    grid.tree.node_by_path(
        &request.path,
        &request.sep,
        request.mode,
        grid.fixed_rows,
        false,
    )
}

pub fn select_nodes(
    grid: &mut VolvoxGrid,
    request: pb::SelectNodesRequest,
) -> Result<pb::NodeSelectionState, TreeError> {
    let mut tree = std::mem::take(&mut grid.tree);
    let selected = tree.select_nodes(&request.active_node_id, &request.selected_node_ids);
    match selected {
        Ok(()) => {
            if request.show && !request.active_node_id.is_empty() {
                let _ = tree.expand_to_node(&request.active_node_id)?;
            }
            project_tree_state(grid, &tree);
            let state = tree.selection_state(grid.fixed_rows);
            if request.show && state.active_row >= grid.fixed_rows {
                grid.selection.set_cursor(
                    state.active_row,
                    grid.fixed_cols,
                    grid.rows,
                    grid.cols,
                    grid.fixed_rows,
                    grid.fixed_cols,
                );
            }
            grid.tree = tree;
            Ok(state)
        }
        Err(err) => {
            grid.tree = tree;
            Err(err)
        }
    }
}

pub fn get_node_selection(grid: &VolvoxGrid) -> pb::NodeSelectionState {
    grid.tree.selection_state(grid.fixed_rows)
}

pub fn set_checked_nodes(
    grid: &mut VolvoxGrid,
    request: pb::SetCheckedNodesRequest,
) -> Result<pb::CheckedNodes, TreeError> {
    grid.tree
        .set_checked_nodes(&request.node_ids, request.state)
}

pub fn get_checked_nodes(grid: &VolvoxGrid) -> pb::CheckedNodes {
    grid.tree.checked_nodes()
}

pub fn sort_tree(grid: &mut VolvoxGrid, request: pb::SortTreeRequest) -> pb::SortTreeResponse {
    let mut tree = std::mem::take(&mut grid.tree);
    tree.sort_tree(&request.sort_columns, request.recursive);
    project_tree_state(grid, &tree);
    let visible_count = usize_to_i32_saturating(tree.visible_count());
    grid.tree = tree;
    pb::SortTreeResponse { visible_count }
}

pub fn find_tree(
    grid: &mut VolvoxGrid,
    request: pb::FindTreeRequest,
) -> Result<pb::FindTreeResponse, TreeError> {
    let mut tree = std::mem::take(&mut grid.tree);
    let result = tree.find_tree(&request, grid.fixed_rows);
    match result {
        Ok(response) => {
            if request.auto_expand_ancestors {
                project_tree_state(grid, &tree);
            }
            grid.tree = tree;
            Ok(response)
        }
        Err(err) => {
            grid.tree = tree;
            Err(err)
        }
    }
}

pub fn filter_tree(
    grid: &mut VolvoxGrid,
    request: pb::FilterTreeRequest,
) -> Result<pb::FilterTreeResponse, TreeError> {
    let mut tree = std::mem::take(&mut grid.tree);
    let result = tree.filter_tree(&request);
    match result {
        Ok(()) => {
            project_tree_state(grid, &tree);
            let visible_count = usize_to_i32_saturating(tree.visible_count());
            grid.tree = tree;
            Ok(pb::FilterTreeResponse { visible_count })
        }
        Err(err) => {
            grid.tree = tree;
            Err(err)
        }
    }
}

pub fn clear_tree_filter(grid: &mut VolvoxGrid) -> pb::ClearTreeFilterResponse {
    let mut tree = std::mem::take(&mut grid.tree);
    tree.clear_filter();
    project_tree_state(grid, &tree);
    let visible_count = usize_to_i32_saturating(tree.visible_count());
    grid.tree = tree;
    pb::ClearTreeFilterResponse { visible_count }
}

pub fn resolve_children(
    grid: &mut VolvoxGrid,
    request: pb::ResolveChildrenRequest,
) -> Result<pb::ResolveChildrenResponse, TreeError> {
    if request.parent_id.is_empty() {
        return Err(TreeError::InvalidArgument(
            "resolve children requires parent_id".to_string(),
        ));
    }
    let mut tree = std::mem::take(&mut grid.tree);
    let result = if request
        .error
        .as_ref()
        .is_some_and(|error| !error.is_empty())
    {
        tree.set_children_state(
            &request.parent_id,
            pb::NodeChildrenState::NodeChildrenError as i32,
        )
        .map(|_| (0usize, pb::NodeChildrenState::NodeChildrenError as i32))
    } else if request.children.is_empty() {
        tree.set_children_state(&request.parent_id, pb::NodeChildrenState::NodeLeaf as i32)
            .map(|_| (0usize, pb::NodeChildrenState::NodeLeaf as i32))
    } else {
        tree.insert_nodes(&request.parent_id, -1, request.children, false)
            .map(|inserted| (inserted, pb::NodeChildrenState::NodeChildrenLoaded as i32))
    };
    match result {
        Ok((inserted_count, children_state)) => {
            project_tree_state(grid, &tree);
            let visible_count = usize_to_i32_saturating(tree.visible_count());
            grid.tree = tree;
            Ok(pb::ResolveChildrenResponse {
                children_state,
                inserted_count: usize_to_i32_saturating(inserted_count),
                visible_count,
            })
        }
        Err(err) => {
            grid.tree = tree;
            Err(err)
        }
    }
}

pub fn project_tree(grid: &mut VolvoxGrid) -> pb::WriteResult {
    let tree = std::mem::take(&mut grid.tree);
    let result = project_tree_state_with_write_result(grid, &tree, false);
    grid.tree = tree;
    result
}

fn set_nodes_expanded(
    grid: &mut VolvoxGrid,
    node_ids: &[String],
    expanded: bool,
    recursive: bool,
) -> Result<(i32, i32), TreeError> {
    let mut tree = std::mem::take(&mut grid.tree);
    let changed = tree.set_expanded(node_ids, expanded, recursive);
    match changed {
        Ok(changed_count) => {
            project_tree_state(grid, &tree);
            let visible_count = usize_to_i32_saturating(tree.visible_count());
            grid.tree = tree;
            Ok((usize_to_i32_saturating(changed_count), visible_count))
        }
        Err(err) => {
            grid.tree = tree;
            Err(err)
        }
    }
}

fn project_tree_state(grid: &mut VolvoxGrid, tree: &TreeState) -> Vec<String> {
    let result = project_tree_state_with_write_result(grid, tree, false);
    if result.rejected_count == 0 {
        Vec::new()
    } else {
        vec![format!(
            "{} tree cell updates were rejected by grid write policy",
            result.rejected_count
        )]
    }
}

fn project_tree_state_with_write_result(
    grid: &mut VolvoxGrid,
    tree: &TreeState,
    atomic: bool,
) -> pb::WriteResult {
    clear_projected_tree_rows(grid);
    let visible_count = usize_to_i32_saturating(tree.visible_count());
    let fixed_rows = grid.fixed_rows.max(0);
    let new_rows = fixed_rows.saturating_add(visible_count).max(1);
    grid.rows = new_rows;
    grid.row_positions.clear();
    grid.row_positions.extend(0..grid.rows);

    let mut updates = Vec::new();
    let mut pinned_top = Vec::new();
    let mut pinned_bottom = Vec::new();
    for (ordinal, node_idx) in tree.visible.iter().copied().enumerate() {
        let row = fixed_rows.saturating_add(usize_to_i32_saturating(ordinal));
        let node = &tree.nodes[node_idx];
        apply_projected_row_props(grid, row, node, &mut pinned_top, &mut pinned_bottom);
        updates.reserve(node.cells.len());
        for cell in &node.cells {
            updates.push(pb::CellUpdate {
                row,
                col: cell.col,
                value: cell.value.clone(),
                style: cell.style.clone(),
                checked: cell.checked,
                picture: cell.picture.clone(),
                picture_align: cell.picture_align,
                button_picture: None,
                dropdown: cell.dropdown.clone(),
                sticky_row: None,
                sticky_col: None,
                interaction: None,
                barcode: None,
                rich_text: cell.rich_text.clone(),
            });
        }
    }
    pinned_top.sort_unstable();
    pinned_bottom.sort_unstable();
    grid.pinned_rows_top.extend(pinned_top);
    grid.pinned_rows_bottom.extend(pinned_bottom);

    grid.selection
        .clamp(grid.rows, grid.cols, grid.fixed_rows, grid.fixed_cols);
    grid.layout.invalidate();
    grid.dirty = true;
    let result = grid.write_cells(&updates, atomic);
    grid.auto_resize_all();
    result
}

fn clear_projected_tree_rows(grid: &mut VolvoxGrid) {
    let fixed_rows = grid.fixed_rows.max(0);
    let old_rows = grid.rows.max(1);
    if fixed_rows < old_rows && grid.cols > 0 {
        grid.cells
            .clear_range(fixed_rows, 0, old_rows - 1, grid.cols - 1);
        grid.merged_regions
            .remove_overlapping(fixed_rows, 0, old_rows - 1, grid.cols - 1);
    }
    grid.recompute_barcode_presence();
    grid.cell_styles.retain(|(row, _), _| *row < fixed_rows);
    grid.row_props.retain(|row, _| *row < fixed_rows);
    grid.row_heights.retain(|row, _| *row < fixed_rows);
    grid.rows_hidden.retain(|row| *row < fixed_rows);
    grid.pinned_rows_top.retain(|row| *row < fixed_rows);
    grid.pinned_rows_bottom.retain(|row| *row < fixed_rows);
    grid.sticky_rows.retain(|row, _| *row < fixed_rows);
    grid.sticky_cells.retain(|(row, _), _| *row < fixed_rows);
    grid.span.span_rows.retain(|row, _| *row < fixed_rows);
    grid.span.clear_span_cache();
}

fn apply_projected_row_props(
    grid: &mut VolvoxGrid,
    row: i32,
    node: &TreeNodeRecord,
    pinned_top: &mut Vec<i32>,
    pinned_bottom: &mut Vec<i32>,
) {
    let mut props = RowProps {
        outline_level: node.level,
        is_collapsed: node.may_have_children() && !node.expanded,
        user_data: node.data.clone(),
        ..RowProps::default()
    };
    if let Some(def) = &node.row {
        if let Some(height) = def.height {
            if height > 0 {
                grid.row_heights.insert(row, grid.clamp_row_height(height));
            } else {
                grid.row_heights.remove(&row);
            }
        }
        if def.hidden.unwrap_or(false) {
            grid.rows_hidden.insert(row);
        }
        if let Some(data) = &def.data {
            props.user_data = if data.is_empty() {
                None
            } else {
                Some(data.clone())
            };
        }
        if let Some(status) = &def.status {
            props.status = RowStatus::from_proto(status);
        }
        if let Some(span) = def.span {
            props.span = span;
            if span {
                grid.span.span_rows.insert(row, true);
            }
        }
        if let Some(pin) = def.pin {
            props.pin = pin;
            match pin {
                1 => pinned_top.push(row),
                2 => pinned_bottom.push(row),
                _ => {}
            }
        }
        if let Some(sticky) = def.sticky {
            if sticky != 0 {
                grid.sticky_rows.insert(row, sticky);
            }
        }
    }
    grid.row_props.insert(row, props);
}

#[cfg(test)]
mod tests {
    use super::*;

    fn text_cell(node_id: &str, col: i32, text: &str) -> pb::NodeCellUpdate {
        pb::NodeCellUpdate {
            node_id: node_id.to_string(),
            col,
            value: Some(pb::CellValue {
                value: Some(pb::cell_value::Value::Text(text.to_string())),
            }),
            style: None,
            checked: None,
            picture: None,
            picture_align: None,
            dropdown: None,
            rich_text: None,
        }
    }

    fn node(id: &str, parent: &str, cells: Vec<pb::NodeCellUpdate>) -> pb::TreeNode {
        pb::TreeNode {
            node_id: id.to_string(),
            parent_id: parent.to_string(),
            row: None,
            cells,
            children_state: pb::NodeChildrenState::NodeChildrenUnknown as i32,
            children: Vec::new(),
            icon_name: None,
            icon_name_open: None,
            data: None,
        }
    }

    #[test]
    fn load_tree_projects_visible_rows() {
        let mut grid = VolvoxGrid::new(0, 320, 240, 1, 3, 1, 0);
        let response = load_tree(
            &mut grid,
            pb::LoadTreeRequest {
                grid_id: 0,
                nodes: vec![
                    node("root", "", vec![text_cell("root", 0, "Root")]),
                    node("child", "root", vec![text_cell("child", 0, "Child")]),
                ],
                replace: true,
                collapse_initial: false,
            },
        )
        .unwrap();
        assert_eq!(response.node_count, 2);
        assert_eq!(response.visible_count, 2);
        assert_eq!(grid.rows, 3);
        assert_eq!(grid.cells.get_text(1, 0), "Root");
        assert_eq!(grid.cells.get_text(2, 0), "Child");
        assert_eq!(grid.tree.node_id_at_row(grid.fixed_rows, 2), Some("child"));
    }

    #[test]
    fn load_tree_auto_resizes_projected_row_heights() {
        let mut grid = VolvoxGrid::new(0, 320, 240, 1, 1, 0, 0);
        grid.default_col_width = 24;
        grid.default_row_height = 16;
        grid.word_wrap = true;
        grid.auto_resize = true;
        grid.auto_size_mode = 2;

        let before = grid.get_row_height(0);
        let response = load_tree(
            &mut grid,
            pb::LoadTreeRequest {
                grid_id: 0,
                nodes: vec![node(
                    "root",
                    "",
                    vec![text_cell(
                        "root",
                        0,
                        "wrapped tree text wrapped tree text wrapped tree text",
                    )],
                )],
                replace: true,
                collapse_initial: false,
            },
        )
        .unwrap();

        assert_eq!(response.visible_count, 1);
        assert!(grid.get_row_height(0) > before);
    }

    #[test]
    fn load_tree_projects_rich_text_and_autosizes_it() {
        let mut grid = VolvoxGrid::new(0, 320, 240, 1, 1, 0, 0);
        grid.default_col_width = 12;
        grid.default_row_height = 10;
        grid.auto_resize = true;
        grid.auto_size_mode = 0;

        let mut cell = text_cell("root", 0, "meta\nLarge");
        cell.rich_text = Some(pb::RichText {
            runs: vec![
                pb::TextFormatRun {
                    start_index: 0,
                    style: Some(pb::TextRunStyle {
                        font: Some(pb::Font {
                            size: Some(8.0),
                            ..Default::default()
                        }),
                        ..Default::default()
                    }),
                },
                pb::TextFormatRun {
                    start_index: 5,
                    style: Some(pb::TextRunStyle {
                        font: Some(pb::Font {
                            size: Some(28.0),
                            bold: Some(true),
                            ..Default::default()
                        }),
                        foreground: Some(0xFF2563EB),
                        ..Default::default()
                    }),
                },
            ],
        });

        let response = load_tree(
            &mut grid,
            pb::LoadTreeRequest {
                grid_id: 0,
                nodes: vec![node("root", "", vec![cell])],
                replace: true,
                collapse_initial: false,
            },
        )
        .unwrap();

        assert_eq!(response.visible_count, 1);
        let projected = grid.cells.get(0, 0).expect("projected cell should exist");
        assert!(projected.rich_text().is_some());
        assert!(grid.get_col_width(0) > grid.default_col_width);
        assert!(grid.get_row_height(0) > grid.default_row_height);
    }

    #[test]
    fn collapse_hides_descendants_without_losing_nodes() {
        let mut grid = VolvoxGrid::new(0, 320, 240, 1, 3, 1, 0);
        load_tree(
            &mut grid,
            pb::LoadTreeRequest {
                grid_id: 0,
                nodes: vec![
                    node("root", "", vec![text_cell("root", 0, "Root")]),
                    node("child", "root", vec![text_cell("child", 0, "Child")]),
                ],
                replace: true,
                collapse_initial: false,
            },
        )
        .unwrap();
        let response = collapse_nodes(
            &mut grid,
            pb::CollapseNodesRequest {
                grid_id: 0,
                node_ids: vec!["root".to_string()],
                recursive: false,
            },
        )
        .unwrap();
        assert_eq!(response.collapsed_count, 1);
        assert_eq!(response.visible_count, 1);
        assert_eq!(grid.rows, 2);
        assert_eq!(grid.tree.node_count(), 2);
        assert!(grid.tree.row_has_children(grid.fixed_rows, 1));
        assert_eq!(grid.cells.get_text(1, 0), "Root");
    }

    #[test]
    fn native_tree_root_can_toggle_repeatedly_from_projected_row() {
        let mut grid = VolvoxGrid::new(0, 320, 240, 1, 3, 1, 0);
        load_tree(
            &mut grid,
            pb::LoadTreeRequest {
                grid_id: 0,
                nodes: vec![
                    node("root", "", vec![text_cell("root", 0, "Root")]),
                    node("child", "root", vec![text_cell("child", 0, "Child")]),
                ],
                replace: true,
                collapse_initial: false,
            },
        )
        .unwrap();

        assert_eq!(grid.tree.node_id_at_row(grid.fixed_rows, 1), Some("root"));
        assert!(!grid.row_props.get(&1).unwrap().is_collapsed);

        crate::input::apply_node_toggle_after_before(&mut grid, 1, true);
        assert_eq!(grid.tree.visible_count(), 1);
        assert!(grid.row_props.get(&1).unwrap().is_collapsed);

        crate::input::apply_node_toggle_after_before(&mut grid, 1, false);
        assert_eq!(grid.tree.visible_count(), 2);
        assert_eq!(grid.tree.node_id_at_row(grid.fixed_rows, 1), Some("root"));
        assert!(!grid.row_props.get(&1).unwrap().is_collapsed);

        crate::input::apply_node_toggle_after_before(&mut grid, 1, true);
        assert_eq!(grid.tree.visible_count(), 1);
        assert!(grid.row_props.get(&1).unwrap().is_collapsed);
    }

    #[test]
    fn duplicate_ids_are_rejected() {
        let mut tree = TreeState::default();
        let err = tree
            .load(
                vec![node("a", "", Vec::new()), node("a", "", Vec::new())],
                false,
            )
            .unwrap_err();
        assert!(matches!(err, TreeError::DuplicateNodeId(id) if id == "a"));
    }

    #[test]
    fn cycles_are_rejected() {
        let mut tree = TreeState::default();
        let err = tree
            .load(
                vec![node("a", "b", Vec::new()), node("b", "a", Vec::new())],
                false,
            )
            .unwrap_err();
        assert!(matches!(err, TreeError::Cycle(_)));
    }

    #[test]
    fn nested_nodes_infer_parent_ids() {
        let mut parent = node("root", "", vec![text_cell("root", 0, "Root")]);
        parent.children.push(node("child", "", Vec::new()));
        let mut tree = TreeState::default();
        tree.load(vec![parent], false).unwrap();
        let child = tree.node_info_by_id("child", 0, false).unwrap();
        assert_eq!(child.parent_node_id, "root");
        assert_eq!(child.level, 1);
    }

    #[test]
    fn move_nodes_reparents_without_reindexing_ids() {
        let mut tree = TreeState::default();
        tree.load(
            vec![
                node("a", "", Vec::new()),
                node("b", "", Vec::new()),
                node("c", "a", Vec::new()),
            ],
            false,
        )
        .unwrap();
        assert_eq!(tree.move_nodes(&["c".to_string()], "b", -1).unwrap(), 1);
        let moved = tree.node_info_by_id("c", 0, false).unwrap();
        assert_eq!(moved.parent_node_id, "b");
        assert_eq!(moved.level, 1);
    }

    #[test]
    fn lazy_child_requests_have_unique_request_ids() {
        let mut grid = VolvoxGrid::new(7, 320, 240, 1, 3, 1, 0);
        let mut root = node("root", "", vec![text_cell("root", 0, "Root")]);
        root.children_state = pb::NodeChildrenState::NodeChildrenUnloaded as i32;
        load_tree(
            &mut grid,
            pb::LoadTreeRequest {
                grid_id: 7,
                nodes: vec![root],
                replace: true,
                collapse_initial: false,
            },
        )
        .unwrap();

        crate::input::apply_node_toggle_after_before(&mut grid, 1, false);
        crate::input::apply_node_toggle_after_before(&mut grid, 1, false);

        let events = grid.events.drain();
        assert_eq!(events.len(), 2);
        assert!(matches!(
            &events[0].data,
            crate::event::GridEventData::TreeChildrenRequested {
                node_id,
                row: 1,
                request_id: 1,
            } if node_id == "root"
        ));
        assert!(matches!(
            &events[1].data,
            crate::event::GridEventData::TreeChildrenRequested {
                node_id,
                row: 1,
                request_id: 2,
            } if node_id == "root"
        ));
    }

    #[test]
    fn update_node_cells_rolls_back_on_invalid_node() {
        let mut grid = VolvoxGrid::new(0, 320, 240, 1, 3, 1, 0);
        load_tree(
            &mut grid,
            pb::LoadTreeRequest {
                grid_id: 0,
                nodes: vec![node("root", "", vec![text_cell("root", 0, "Root")])],
                replace: true,
                collapse_initial: false,
            },
        )
        .unwrap();

        let err = update_node_cells(
            &mut grid,
            pb::UpdateNodeCellsRequest {
                grid_id: 0,
                cells: vec![
                    text_cell("root", 0, "Changed"),
                    text_cell("missing", 0, "Missing"),
                ],
                atomic: false,
            },
        )
        .unwrap_err();
        assert!(matches!(err, TreeError::NotFound(id) if id == "missing"));

        project_tree(&mut grid);
        assert_eq!(grid.cells.get_text(1, 0), "Root");
    }

    #[test]
    fn select_nodes_rolls_back_on_invalid_node() {
        let mut grid = VolvoxGrid::new(0, 320, 240, 1, 3, 1, 0);
        load_tree(
            &mut grid,
            pb::LoadTreeRequest {
                grid_id: 0,
                nodes: vec![
                    node("root", "", Vec::new()),
                    node("child", "root", Vec::new()),
                ],
                replace: true,
                collapse_initial: false,
            },
        )
        .unwrap();
        select_nodes(
            &mut grid,
            pb::SelectNodesRequest {
                grid_id: 0,
                active_node_id: "root".to_string(),
                selected_node_ids: vec!["root".to_string()],
                show: false,
            },
        )
        .unwrap();

        let err = select_nodes(
            &mut grid,
            pb::SelectNodesRequest {
                grid_id: 0,
                active_node_id: "child".to_string(),
                selected_node_ids: vec!["missing".to_string()],
                show: false,
            },
        )
        .unwrap_err();
        assert!(matches!(err, TreeError::NotFound(id) if id == "missing"));

        let state = get_node_selection(&grid);
        assert_eq!(state.active_node_id, "root");
        assert_eq!(state.selected_node_ids, vec!["root".to_string()]);
    }

    #[test]
    fn update_tree_batches_structural_changes() {
        let mut grid = VolvoxGrid::new(0, 320, 240, 1, 3, 1, 0);
        load_tree(
            &mut grid,
            pb::LoadTreeRequest {
                grid_id: 0,
                nodes: {
                    let mut b = node("b", "root", vec![text_cell("b", 0, "B")]);
                    b.children_state = pb::NodeChildrenState::NodeChildrenUnloaded as i32;
                    vec![
                        node("root", "", vec![text_cell("root", 0, "Root")]),
                        node("a", "root", vec![text_cell("a", 0, "A")]),
                        b,
                        node("c", "root", vec![text_cell("c", 0, "C")]),
                    ]
                },
                replace: true,
                collapse_initial: false,
            },
        )
        .unwrap();

        let response = update_tree(
            &mut grid,
            pb::UpdateTreeRequest {
                grid_id: 0,
                adds: vec![pb::InsertNodesRequest {
                    grid_id: 0,
                    parent_id: "b".to_string(),
                    position: -1,
                    nodes: vec![node("d", "b", vec![text_cell("d", 0, "D")])],
                }],
                removes: vec![pb::RemoveNodesRequest {
                    grid_id: 0,
                    node_ids: vec!["c".to_string()],
                    recursive: false,
                }],
                moves: vec![pb::MoveNodesRequest {
                    grid_id: 0,
                    node_ids: vec!["a".to_string()],
                    new_parent_id: "b".to_string(),
                    position: -1,
                }],
                renames: Vec::new(),
                cell_updates: Vec::new(),
            },
        )
        .unwrap();

        assert_eq!(response.inserted_count, 1);
        assert_eq!(response.removed_count, 1);
        assert_eq!(response.moved_count, 1);
        assert_eq!(response.visible_count, 4);
        assert_eq!(
            grid.tree
                .node_info_by_id("a", grid.fixed_rows, false)
                .unwrap()
                .parent_node_id,
            "b"
        );
        assert_eq!(grid.tree.node_id_at_row(grid.fixed_rows, 1), Some("root"));
        assert_eq!(grid.tree.node_id_at_row(grid.fixed_rows, 2), Some("b"));
        assert_eq!(grid.tree.node_id_at_row(grid.fixed_rows, 3), Some("a"));
        assert_eq!(grid.tree.node_id_at_row(grid.fixed_rows, 4), Some("d"));
    }

    #[test]
    fn tree_errors_map_to_typed_grid_error_codes() {
        assert_eq!(
            error_code(&TreeError::NotFound("missing".to_string())),
            pb::ErrorCode::ErrorNotFound as i32
        );
        assert_eq!(
            error_code(&TreeError::DuplicateNodeId("dup".to_string())),
            pb::ErrorCode::ErrorInvalidArgument as i32
        );
        assert_eq!(
            error_code(&TreeError::MissingParent {
                node_id: "child".to_string(),
                parent_id: "parent".to_string(),
            }),
            pb::ErrorCode::ErrorInvalidArgument as i32
        );
        assert_eq!(
            error_code(&TreeError::Cycle("root".to_string())),
            pb::ErrorCode::ErrorInvalidArgument as i32
        );
    }
}
