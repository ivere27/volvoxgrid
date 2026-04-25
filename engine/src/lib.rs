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
pub mod canvas_tui;
pub mod cell;
pub mod clipboard;
pub mod column;
pub mod compose;
pub mod config;
pub mod control;
pub mod debug_font;
pub mod drag;
pub mod edit;
pub mod event;
pub mod font_fallbacks;
#[cfg(feature = "gpu")]
pub mod glyph_atlas;
pub mod glyph_rasterizer;
#[cfg(feature = "gpu")]
pub mod gpu_render;
pub mod grid;
pub mod indicator;
pub mod input;
pub mod layout;
pub mod load;
pub mod merge_registry;
pub mod outline;
pub mod print;
pub mod render;
pub mod row;
pub mod save;
pub mod scroll;
mod scroll_cache;
pub mod scrollbar;
pub mod search;
pub mod selection;
pub mod sort;
pub mod span;
pub mod style;
pub mod text;

use std::collections::HashMap;
use std::sync::{
    atomic::{AtomicBool, AtomicI64, AtomicU64, Ordering},
    Arc, Condvar, Mutex,
};

use grid::VolvoxGrid;

static NEXT_GRID_ID: AtomicI64 = AtomicI64::new(1);

/// Push-only wakeup primitive. Notifiers publish state under their own locks,
/// then call `wake()` which bumps a monotonic sequence and signals a condvar.
/// Waiters snapshot the sequence, do their work, then block in
/// `wait_for_change(baseline)` until any publisher advances the sequence past
/// the snapshot. This avoids the classic "check-then-wait" lost-wakeup race
/// without forcing all publishers to share a single mutex with the waiter.
pub struct Waker {
    seq: AtomicU64,
    mu: Mutex<()>,
    cv: Condvar,
}

impl Waker {
    pub fn new() -> Self {
        Self {
            seq: AtomicU64::new(0),
            mu: Mutex::new(()),
            cv: Condvar::new(),
        }
    }

    pub fn wake(&self) {
        self.seq.fetch_add(1, Ordering::SeqCst);
        {
            let _g = self.mu.lock().unwrap_or_else(|p| p.into_inner());
        }
        self.cv.notify_all();
    }

    pub fn current_seq(&self) -> u64 {
        self.seq.load(Ordering::SeqCst)
    }

    pub fn wait_for_change(&self, baseline: u64) {
        let g = self.mu.lock().unwrap_or_else(|p| p.into_inner());
        let _guard = self
            .cv
            .wait_while(g, |_| self.seq.load(Ordering::SeqCst) == baseline)
            .unwrap_or_else(|p| p.into_inner());
    }
}

impl Default for Waker {
    fn default() -> Self {
        Self::new()
    }
}

struct GridSlot {
    grid: Arc<Mutex<VolvoxGrid>>,
    event_cv: Arc<Condvar>,
    destroyed: Arc<AtomicBool>,
    waker: Arc<Waker>,
}

pub struct GridManager {
    grids: Mutex<HashMap<i64, Arc<GridSlot>>>,
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
        let slot = Arc::new(GridSlot {
            grid: Arc::new(Mutex::new(grid)),
            event_cv: Arc::new(Condvar::new()),
            destroyed: Arc::new(AtomicBool::new(false)),
            waker: Arc::new(Waker::new()),
        });
        self.grids.lock().unwrap().insert(id, slot);
        id
    }

    pub fn destroy_grid(&self, id: i64) {
        if let Some(slot) = self.grids.lock().unwrap().remove(&id) {
            let _grid = slot.grid.lock().unwrap();
            slot.destroyed.store(true, Ordering::SeqCst);
            slot.event_cv.notify_all();
            slot.waker.wake();
        }
    }

    pub fn with_grid<F, R>(&self, id: i64, f: F) -> Result<R, String>
    where
        F: FnOnce(&mut VolvoxGrid) -> R,
    {
        let slot = {
            let grids = self.grids.lock().unwrap();
            grids
                .get(&id)
                .cloned()
                .ok_or_else(|| format!("grid {} not found", id))?
        };
        let (result, should_notify) = {
            let mut grid = slot.grid.lock().unwrap();
            let events_before = grid.events.len();
            let result = f(&mut grid);
            let should_notify = grid.events.len() > events_before;
            (result, should_notify)
        };
        if should_notify {
            slot.event_cv.notify_all();
            slot.waker.wake();
        }
        Ok(result)
    }

    pub fn get_grid(&self, id: i64) -> Result<Arc<Mutex<VolvoxGrid>>, String> {
        let grids = self.grids.lock().unwrap();
        grids
            .get(&id)
            .map(|slot| Arc::clone(&slot.grid))
            .ok_or_else(|| format!("grid {} not found", id))
    }

    pub fn get_grid_waiter(
        &self,
        id: i64,
    ) -> Result<(Arc<Mutex<VolvoxGrid>>, Arc<Condvar>, Arc<AtomicBool>), String> {
        let grids = self.grids.lock().unwrap();
        let slot = grids
            .get(&id)
            .cloned()
            .ok_or_else(|| format!("grid {} not found", id))?;
        Ok((
            Arc::clone(&slot.grid),
            Arc::clone(&slot.event_cv),
            Arc::clone(&slot.destroyed),
        ))
    }

    pub fn notify_all_event_waiters(&self) {
        let slots: Vec<Arc<GridSlot>> = self.grids.lock().unwrap().values().cloned().collect();
        for slot in slots {
            slot.event_cv.notify_all();
            slot.waker.wake();
        }
    }

    pub fn get_grid_waker(&self, id: i64) -> Result<Arc<Waker>, String> {
        let grids = self.grids.lock().unwrap();
        grids
            .get(&id)
            .map(|slot| Arc::clone(&slot.waker))
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
    use std::sync::{atomic::Ordering, mpsc, Arc};
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

    #[test]
    fn with_grid_notifies_event_waiters_when_events_arrive() {
        let manager = Arc::new(GridManager::new());
        let id = manager.create_grid(100, 100, 10, 10, 1, 1, 1.0);
        let (grid_arc, event_cv, destroyed) = manager
            .get_grid_waiter(id)
            .expect("grid waiter should exist");
        let (ready_tx, ready_rx) = mpsc::channel::<()>();
        let (done_tx, done_rx) = mpsc::channel::<()>();

        let waiter = std::thread::spawn(move || {
            let mut grid = grid_arc.lock().unwrap();
            ready_tx.send(()).expect("ready send should succeed");
            while grid.events.is_empty() && !destroyed.load(Ordering::SeqCst) {
                grid = event_cv.wait(grid).unwrap();
            }
            done_tx.send(()).expect("done send should succeed");
        });

        ready_rx
            .recv_timeout(Duration::from_secs(1))
            .expect("waiter did not start");
        manager
            .with_grid(id, |grid| {
                grid.events.push(crate::event::GridEventData::Click {
                    row: 0,
                    col: 0,
                    hit_area: 0,
                    interaction: crate::proto::volvoxgrid::v1::CellInteraction::None as i32,
                });
            })
            .expect("with_grid should succeed");
        done_rx
            .recv_timeout(Duration::from_secs(1))
            .expect("waiter did not receive notification");

        waiter.join().expect("waiter thread panicked");
    }

    #[test]
    fn destroy_grid_notifies_event_waiters() {
        let manager = Arc::new(GridManager::new());
        let id = manager.create_grid(100, 100, 10, 10, 1, 1, 1.0);
        let (grid_arc, event_cv, destroyed) = manager
            .get_grid_waiter(id)
            .expect("grid waiter should exist");
        let (ready_tx, ready_rx) = mpsc::channel::<()>();
        let (done_tx, done_rx) = mpsc::channel::<()>();

        let waiter = std::thread::spawn(move || {
            let mut grid = grid_arc.lock().unwrap();
            ready_tx.send(()).expect("ready send should succeed");
            while grid.events.is_empty() && !destroyed.load(Ordering::SeqCst) {
                grid = event_cv.wait(grid).unwrap();
            }
            done_tx.send(()).expect("done send should succeed");
        });

        ready_rx
            .recv_timeout(Duration::from_secs(1))
            .expect("waiter did not start");
        manager.destroy_grid(id);
        done_rx
            .recv_timeout(Duration::from_secs(1))
            .expect("waiter did not wake on destroy");

        waiter.join().expect("waiter thread panicked");
    }
}
