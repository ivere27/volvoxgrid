pub mod proto {
    pub mod volvoxgrid {
        pub mod v1 {
            include!(concat!(env!("OUT_DIR"), "/volvoxgrid.v1.rs"));
        }
    }
}

#[cfg(feature = "demo")]
pub mod demo;

pub mod animation;
pub mod canvas;
pub mod canvas_cpu;
#[cfg(feature = "gpu")]
pub mod canvas_gpu;
pub mod cell;
pub mod clipboard;
pub mod column;
pub mod config;
pub mod drag;
pub mod edit;
pub mod event;
pub mod font_fallbacks;
pub mod glyph_rasterizer;
#[cfg(feature = "gpu")]
pub mod glyph_atlas;
#[cfg(feature = "gpu")]
pub mod gpu_render;
pub mod grid;
pub mod input;
pub mod layout;
pub mod merge_registry;
pub mod span;
pub mod outline;
pub mod print;
pub mod render;
pub mod row;
pub mod save;
pub mod scroll;
pub mod search;
pub mod selection;
pub mod sort;
pub mod style;
pub mod text;

use std::collections::HashMap;
use std::sync::{
    atomic::{AtomicI64, Ordering},
    Arc, Mutex,
};

use grid::VolvoxGrid;

static NEXT_GRID_ID: AtomicI64 = AtomicI64::new(1);

pub struct GridManager {
    grids: Mutex<HashMap<i64, Arc<Mutex<VolvoxGrid>>>>,
}

impl GridManager {
    pub fn new() -> Self {
        Self {
            grids: Mutex::new(HashMap::new()),
        }
    }

    pub fn create_grid(
        &self,
        viewport_width: i32,
        viewport_height: i32,
        rows: i32,
        cols: i32,
        fixed_rows: i32,
        fixed_cols: i32,
        scale: f32,
    ) -> i64 {
        let id = NEXT_GRID_ID.fetch_add(1, Ordering::Relaxed);
        let mut grid = VolvoxGrid::new(
            id,
            viewport_width,
            viewport_height,
            rows,
            cols,
            fixed_rows,
            fixed_cols,
        );
        grid.scale = if scale > 0.01 { scale } else { 1.0 };
        self.grids
            .lock()
            .unwrap()
            .insert(id, Arc::new(Mutex::new(grid)));
        id
    }

    pub fn destroy_grid(&self, id: i64) {
        self.grids.lock().unwrap().remove(&id);
    }

    pub fn with_grid<F, R>(&self, id: i64, f: F) -> Result<R, String>
    where
        F: FnOnce(&mut VolvoxGrid) -> R,
    {
        let grid_arc = {
            let grids = self.grids.lock().unwrap();
            grids
                .get(&id)
                .cloned()
                .ok_or_else(|| format!("grid {} not found", id))?
        };
        let mut grid = grid_arc.lock().unwrap();
        Ok(f(&mut grid))
    }

    pub fn get_grid(&self, id: i64) -> Result<Arc<Mutex<VolvoxGrid>>, String> {
        let grids = self.grids.lock().unwrap();
        grids
            .get(&id)
            .cloned()
            .ok_or_else(|| format!("grid {} not found", id))
    }

    pub fn grid_ids(&self) -> Vec<i64> {
        let grids = self.grids.lock().unwrap();
        grids.keys().copied().collect()
    }
}

impl Default for GridManager {
    fn default() -> Self {
        Self::new()
    }
}

#[cfg(test)]
mod tests {
    use super::GridManager;
    use std::sync::{mpsc, Arc};
    use std::time::Duration;

    #[test]
    fn with_grid_does_not_hold_outer_map_lock_during_closure() {
        let manager = Arc::new(GridManager::new());
        let id1 = manager.create_grid(100, 100, 10, 10, 1, 1, 1.0);
        let id2 = manager.create_grid(100, 100, 10, 10, 1, 1, 1.0);

        let (entered_tx, entered_rx) = mpsc::channel::<()>();
        let (release_tx, release_rx) = mpsc::channel::<()>();
        let manager_for_with_grid = Arc::clone(&manager);

        let with_grid_thread = std::thread::spawn(move || {
            manager_for_with_grid
                .with_grid(id1, |_g| {
                    let _ = entered_tx.send(());
                    let _ = release_rx.recv();
                })
                .expect("with_grid should succeed");
        });

        entered_rx
            .recv_timeout(Duration::from_secs(1))
            .expect("with_grid closure did not start");

        let (destroy_done_tx, destroy_done_rx) = mpsc::channel::<()>();
        let manager_for_destroy = Arc::clone(&manager);
        let destroy_thread = std::thread::spawn(move || {
            manager_for_destroy.destroy_grid(id2);
            let _ = destroy_done_tx.send(());
        });

        destroy_done_rx
            .recv_timeout(Duration::from_millis(200))
            .expect("destroy_grid blocked while with_grid closure was running");

        let _ = release_tx.send(());
        with_grid_thread.join().expect("with_grid thread panicked");
        destroy_thread.join().expect("destroy thread panicked");
    }
}
