use std::collections::{HashMap, HashSet};

const FREE_SLOT: i32 = -1;
const HIDDEN_SLOT: i32 = -2;
const RETIRED_SLOT: i32 = -3;
const SLOT_BITS: u32 = 31;
const SLOT_MASK: u64 = (1u64 << SLOT_BITS) - 1;

/// Compact stable identities, independent of temporary cell-storage mappings.
/// Automatic IDs use three u32/i32 arrays (12 bytes per live row before capacity).
/// Caller IDs are sparse aliases; automatic IDs need neither strings nor a hash index.
#[derive(Clone, Debug)]
pub struct RowIdentityStore {
    enabled: bool,
    row_count: i32,
    slots: Vec<u32>,
    positions: Vec<i32>,
    generations: Vec<u32>,
    free: Vec<u32>,
    aliases: HashMap<i64, u32>,
    slot_aliases: Vec<i64>,
    tree_slots: HashMap<String, u32>,
    tree_owned: HashSet<u32>,
    revision: u64,
}

impl RowIdentityStore {
    /// Create an enabled identity store. Grid creation opts in explicitly.
    pub fn new(_grid_id: i64, rows: i32) -> Self {
        let mut store = Self::new_disabled(0);
        store.enabled = true;
        store.resize(rows);
        store
    }

    /// Track only a structural revision, without allocating per-row storage.
    pub fn new_disabled(rows: i32) -> Self {
        Self {
            enabled: false,
            row_count: rows.max(0),
            slots: Vec::new(),
            positions: Vec::new(),
            generations: Vec::new(),
            free: Vec::new(),
            aliases: HashMap::new(),
            slot_aliases: Vec::new(),
            tree_slots: HashMap::new(),
            tree_owned: HashSet::new(),
            revision: 0,
        }
    }

    pub fn is_enabled(&self) -> bool {
        self.enabled
    }

    pub(crate) fn require_enabled(&self) -> Result<(), String> {
        if self.enabled {
            Ok(())
        } else {
            Err("row IDs are disabled; create the grid with row_ids_enabled=true".into())
        }
    }

    pub fn revision(&self) -> u64 {
        self.revision
    }

    fn changed(&mut self) {
        self.revision = self.revision.wrapping_add(1);
    }

    fn token_for_slot(&self, slot: u32) -> i64 {
        ((u64::from(self.generations[slot as usize]) << SLOT_BITS) | (u64::from(slot) + 1)) as i64
    }

    fn slot_for_token(&self, token: i64) -> Option<u32> {
        if token <= 0 {
            return None;
        }
        let token = token as u64;
        let word = token & SLOT_MASK;
        if word == 0 {
            return None;
        }
        let slot = (word - 1) as u32;
        let index = slot as usize;
        if self.generations.get(index).copied()? != (token >> SLOT_BITS) as u32
            || self.positions[index] < HIDDEN_SLOT
            || self.positions[index] == FREE_SLOT
        {
            return None;
        }
        Some(slot)
    }

    fn slot_for_id(&self, id: i64) -> Option<u32> {
        if let Some(&slot) = self.aliases.get(&id) {
            return Some(slot);
        }
        let slot = self.slot_for_token(id)?;
        self.alias_for_slot(slot).is_none().then_some(slot)
    }

    fn alias_for_slot(&self, slot: u32) -> Option<i64> {
        self.slot_aliases
            .get(slot as usize)
            .copied()
            .filter(|&id| id != 0)
    }

    fn clear_alias(&mut self, slot: u32) {
        if let Some(id) = self.slot_aliases.get_mut(slot as usize) {
            if *id != 0 {
                self.aliases.remove(id);
                *id = 0;
            }
        }
    }

    fn set_alias(&mut self, slot: u32, id: i64) {
        if self.slot_aliases.is_empty() {
            self.slot_aliases.resize(self.positions.len(), 0);
        }
        self.slot_aliases[slot as usize] = id;
        self.aliases.insert(id, slot);
    }

    pub fn get(&self, row: i32) -> Option<i64> {
        let &slot = self.slots.get(usize::try_from(row).ok()?)?;
        Some(
            self.alias_for_slot(slot)
                .unwrap_or_else(|| self.token_for_slot(slot)),
        )
    }

    pub fn find(&self, id: i64) -> Option<i32> {
        let slot = self.slot_for_id(id)?;
        let position = self.positions[slot as usize];
        (position >= 0).then_some(position)
    }

    /// Internal incarnation token. Unlike a caller alias, this cannot revive after replacement.
    pub fn identity_token(&self, row: i32) -> Option<i64> {
        self.slots
            .get(usize::try_from(row).ok()?)
            .map(|&slot| self.token_for_slot(slot))
    }

    pub fn find_identity_token(&self, token: i64) -> Option<i32> {
        let slot = self.slot_for_token(token)?;
        let position = self.positions[slot as usize];
        (position >= 0).then_some(position)
    }

    fn reserve_rows(&mut self, rows: usize) {
        if rows > self.slots.len() {
            self.slots.reserve_exact(rows - self.slots.len());
        }
        if rows > self.positions.len() {
            self.positions.reserve_exact(rows - self.positions.len());
            self.generations
                .reserve_exact(rows - self.generations.len());
        }
    }

    fn allocate_slot(&mut self, position: i32) -> u32 {
        loop {
            let slot = if let Some(slot) = self.free.pop() {
                let generation = &mut self.generations[slot as usize];
                let Some(next) = generation.checked_add(1) else {
                    self.positions[slot as usize] = RETIRED_SLOT;
                    continue;
                };
                *generation = next;
                slot
            } else {
                assert!(
                    self.positions.len() < SLOT_MASK as usize,
                    "row identity slot space exhausted"
                );
                let slot = self.positions.len() as u32;
                self.positions.push(FREE_SLOT);
                self.generations.push(1);
                if !self.slot_aliases.is_empty() {
                    self.slot_aliases.push(0);
                }
                slot
            };
            // All positive caller IDs are legal, including future automatic tokens.
            while self.aliases.contains_key(&self.token_for_slot(slot)) {
                let generation = &mut self.generations[slot as usize];
                let Some(next) = generation.checked_add(1) else {
                    self.positions[slot as usize] = RETIRED_SLOT;
                    break;
                };
                *generation = next;
            }
            if self.positions[slot as usize] == RETIRED_SLOT {
                continue;
            }
            self.positions[slot as usize] = position;
            return slot;
        }
    }

    fn release_slot(&mut self, slot: u32) {
        let position = self.positions[slot as usize];
        if position == FREE_SLOT || position == RETIRED_SLOT {
            return;
        }
        self.clear_alias(slot);
        if self.aliases.is_empty() {
            self.slot_aliases = Vec::new();
        }
        self.positions[slot as usize] = FREE_SLOT;
        self.free.push(slot);
    }

    fn detach_slot(&mut self, slot: u32) {
        if self.tree_owned.contains(&slot) {
            self.positions[slot as usize] = HIDDEN_SLOT;
        } else {
            self.release_slot(slot);
        }
    }

    pub(crate) fn resize(&mut self, rows: i32) {
        let rows = rows.max(0);
        if !self.enabled {
            if self.row_count != rows {
                self.row_count = rows;
                self.changed();
            }
            return;
        }
        self.row_count = rows;
        let rows = rows as usize;
        if rows == self.slots.len() {
            return;
        }
        self.reserve_rows(rows);
        while self.slots.len() > rows {
            let slot = self.slots.pop().unwrap();
            self.detach_slot(slot);
        }
        while self.slots.len() < rows {
            let slot = self.allocate_slot(self.slots.len() as i32);
            self.slots.push(slot);
        }
        self.changed();
    }

    pub(crate) fn reset(&mut self, rows: i32) {
        if !self.enabled {
            self.row_count = rows.max(0);
            self.changed();
            return;
        }
        self.slots.clear();
        self.aliases = HashMap::new();
        self.slot_aliases = Vec::new();
        self.tree_slots.clear();
        self.tree_owned.clear();
        self.free.clear();
        // Preserve generation history across full table replacement. Retired slots
        // never wrap; stale tokens cannot identify a later row at the same slot.
        for slot in (0..self.positions.len()).rev() {
            if self.generations[slot] == u32::MAX {
                self.positions[slot] = RETIRED_SLOT;
            } else {
                self.positions[slot] = FREE_SLOT;
                self.free.push(slot as u32);
            }
        }
        self.resize(rows);
        if self.free.is_empty() {
            self.free = Vec::new();
        }
        self.changed();
    }

    pub(crate) fn insert(&mut self, row: i32) {
        self.row_count += 1;
        if !self.enabled {
            self.changed();
            return;
        }
        let slot = self.allocate_slot(row);
        self.slots.insert(row as usize, slot);
        for position in row as usize + 1..self.slots.len() {
            self.positions[self.slots[position] as usize] = position as i32;
        }
        self.changed();
    }

    pub(crate) fn remove(&mut self, row: i32) {
        self.row_count -= 1;
        if !self.enabled {
            self.changed();
            return;
        }
        let slot = self.slots.remove(row as usize);
        self.detach_slot(slot);
        for position in row as usize..self.slots.len() {
            self.positions[self.slots[position] as usize] = position as i32;
        }
        self.changed();
    }

    /// Apply an in-range permutation from old display row to new display row.
    /// Only numeric slot indexes move; neither IDs nor the alias index are copied.
    pub fn remap(&mut self, remap: &HashMap<i32, i32>) {
        if remap.is_empty() {
            return;
        }
        if !self.enabled {
            self.changed();
            return;
        }
        if remap.len() > self.slots.len() / 2 {
            let old = self.slots.clone();
            for (&source, &destination) in remap {
                let slot = old[source as usize];
                self.slots[destination as usize] = slot;
                self.positions[slot as usize] = destination;
            }
        } else {
            let moved: Vec<(u32, u32)> = remap
                .iter()
                .map(|(&source, &destination)| (destination as u32, self.slots[source as usize]))
                .collect();
            for (destination, slot) in moved {
                self.slots[destination as usize] = slot;
                self.positions[slot as usize] = destination as i32;
            }
        }
        self.changed();
    }

    /// Reorder a sort group directly from its permutation, without hashing row indexes.
    pub(crate) fn reorder_rows(&mut self, rows: &[i32], source_indices: &[usize]) {
        if !self.enabled {
            if rows.len() > 1 {
                self.changed();
            }
            return;
        }
        if source_indices
            .iter()
            .enumerate()
            .all(|(index, &source)| index == source)
        {
            return;
        }
        let slots: Vec<u32> = source_indices
            .iter()
            .map(|&source| self.slots[rows[source] as usize])
            .collect();
        for (&row, slot) in rows.iter().zip(slots) {
            self.slots[row as usize] = slot;
            self.positions[slot as usize] = row;
        }
        self.changed();
    }

    /// Assign positive IDs atomically. Swaps are legal; duplicate rows or IDs are not.
    pub fn assign(&mut self, assignments: &[(i32, i64)]) -> Result<(), String> {
        if assignments.is_empty() {
            return Ok(());
        }
        self.require_enabled()?;
        let mut rows = HashSet::with_capacity(assignments.len());
        let mut ids = HashSet::with_capacity(assignments.len());
        for &(row, id) in assignments {
            if row < 0 || row as usize >= self.slots.len() {
                return Err(format!("row ID index {row} is out of range"));
            }
            if !rows.insert(row) {
                return Err(format!("duplicate row ID assignment for row {row}"));
            }
            if id <= 0 || !ids.insert(id) {
                return Err("row IDs must be positive and unique".into());
            }
        }
        for &(_, id) in assignments {
            if let Some(slot) = self.slot_for_id(id) {
                if !rows.contains(&self.positions[slot as usize]) {
                    return Err(format!("duplicate row ID: {id}"));
                }
            }
        }
        for &(row, _) in assignments {
            let slot = self.slots[row as usize];
            self.clear_alias(slot);
        }
        self.aliases.reserve(assignments.len());
        for &(row, id) in assignments {
            let slot = self.slots[row as usize];
            if id != self.token_for_slot(slot) {
                self.set_alias(slot, id);
            }
        }
        if self.aliases.is_empty() {
            self.slot_aliases = Vec::new();
        }
        self.changed();
        Ok(())
    }

    pub fn validate_replacement(rows: i32, ids: &[i64]) -> Result<(), String> {
        if ids.is_empty() {
            return Ok(());
        }
        if ids.len() != rows.max(1) as usize {
            return Err(format!(
                "expected {} row IDs, received {}",
                rows.max(1),
                ids.len()
            ));
        }
        let mut unique = HashSet::with_capacity(ids.len());
        if ids.iter().any(|&id| id <= 0 || !unique.insert(id)) {
            return Err("row IDs must be positive and unique".into());
        }
        Ok(())
    }

    pub(crate) fn replace(&mut self, rows: i32, ids: &[i64]) -> Result<(), String> {
        if !ids.is_empty() {
            self.require_enabled()?;
        }
        Self::validate_replacement(rows, ids)?;
        self.replace_validated(rows, ids);
        Ok(())
    }

    /// Caller has validated the complete replacement before mutating the grid.
    pub(crate) fn replace_validated(&mut self, rows: i32, ids: &[i64]) {
        self.reset(rows);
        if !self.enabled {
            debug_assert!(ids.is_empty());
            return;
        }
        let alias_count = ids
            .iter()
            .enumerate()
            .filter(|&(row, id)| *id != self.token_for_slot(self.slots[row]))
            .count();
        self.aliases.reserve(alias_count);
        for (row, &id) in ids.iter().enumerate() {
            let slot = self.slots[row];
            if id != self.token_for_slot(slot) {
                self.set_alias(slot, id);
            }
        }
    }

    pub(crate) fn clear_tree_ids(&mut self) {
        if !self.enabled {
            self.changed();
            return;
        }
        let slots: Vec<u32> = self.tree_slots.values().copied().collect();
        self.tree_slots.clear();
        self.tree_owned.clear();
        for slot in slots {
            self.release_slot(slot);
        }
        self.changed();
    }

    /// Reserve hidden node identities until the underlying tree nodes are removed.
    pub(crate) fn project_tree(&mut self, fixed_rows: i32, all: &[&str], visible: &[&str]) {
        if !self.enabled {
            self.reset(fixed_rows.saturating_add(visible.len() as i32).max(1));
            return;
        }
        let retained: HashSet<&str> = all.iter().copied().collect();
        let removed: Vec<String> = self
            .tree_slots
            .keys()
            .filter(|node| !retained.contains(node.as_str()))
            .cloned()
            .collect();
        for node in removed {
            let slot = self.tree_slots.remove(&node).unwrap();
            self.tree_owned.remove(&slot);
            self.release_slot(slot);
        }
        self.resize(fixed_rows);
        // A larger fixed region can cover a previously visible tree node. Its
        // slot remains reserved for that node; the new header needs its own ID.
        // Removed/replaced tree nodes can also leave a freed slot in this prefix.
        for row in 0..self.slots.len() {
            let slot = self.slots[row];
            if self.tree_owned.contains(&slot) || self.positions[slot as usize] != row as i32 {
                if self.tree_owned.contains(&slot) {
                    self.positions[slot as usize] = HIDDEN_SLOT;
                }
                self.slots[row] = self.allocate_slot(row as i32);
            }
        }
        for &node in all {
            if !self.tree_slots.contains_key(node) {
                let slot = self.allocate_slot(HIDDEN_SLOT);
                self.tree_slots.insert(node.to_owned(), slot);
                self.tree_owned.insert(slot);
            }
        }
        for &node in visible {
            let slot = self.tree_slots[node];
            self.positions[slot as usize] = self.slots.len() as i32;
            self.slots.push(slot);
        }
        self.resize((fixed_rows + visible.len() as i32).max(1));
        self.changed();
    }

    pub fn heap_size_bytes(&self) -> usize {
        (self.slots.capacity()
            + self.positions.capacity()
            + self.generations.capacity()
            + self.free.capacity())
            * std::mem::size_of::<u32>()
            + self.aliases.capacity() * (std::mem::size_of::<(i64, u32)>() + 1)
            + self.slot_aliases.capacity() * std::mem::size_of::<i64>()
            + self.tree_slots.capacity() * (std::mem::size_of::<(String, u32)>() + 1)
            + self.tree_slots.keys().map(String::capacity).sum::<usize>()
            + self.tree_owned.capacity() * (std::mem::size_of::<u32>() + 1)
    }
}

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

#[cfg(test)]
mod identity_tests {
    use super::*;

    #[test]
    fn exhausted_generation_retires_slot_instead_of_wrapping() {
        let mut store = RowIdentityStore::new(1, 1);
        store.generations[0] = u32::MAX;
        let old = store.get(0).unwrap();
        store.remove(0);
        store.insert(0);
        assert_ne!(store.slots[0], 0);
        assert_eq!(store.find_identity_token(old), None);
        assert!(store.get(0).unwrap() > 0);
    }

    #[test]
    fn automatic_replacement_releases_alias_storage_and_keeps_compact_arrays() {
        let mut store = RowIdentityStore::new(1, 1_000);
        store.assign(&[(1, i64::MAX)]).unwrap();
        assert!(!store.aliases.is_empty());
        assert!(!store.slot_aliases.is_empty());
        let old = store.identity_token(1).unwrap();
        store.reset(1_000);
        assert_eq!(store.find_identity_token(old), None);
        assert_eq!(store.aliases.capacity(), 0);
        assert_eq!(store.slot_aliases.capacity(), 0);
        assert_eq!(store.heap_size_bytes(), 12_000);
    }
}
