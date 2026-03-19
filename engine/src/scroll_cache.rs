use crate::canvas::{DamageRect, DamageRegion, VisibleRange};
use crate::grid::VolvoxGrid;

#[derive(Clone, Debug, PartialEq, Eq)]
struct ScrollBands {
    viewport: (i32, i32),
    data_x: i32,
    data_y: i32,
    data_w: i32,
    data_h: i32,
    fixed_width: i32,
    fixed_height: i32,
    pinned_top_rows: Vec<i32>,
    pinned_bottom_rows: Vec<i32>,
    sticky_top_rows: Vec<i32>,
    sticky_bottom_rows: Vec<i32>,
    sticky_left_cols: Vec<i32>,
    sticky_right_cols: Vec<i32>,
    pinned_top_height: i32,
    pinned_bottom_height: i32,
    sticky_top_height: i32,
    sticky_bottom_height: i32,
    sticky_left_width: i32,
    sticky_right_width: i32,
}

impl ScrollBands {
    fn from_visible_range(grid: &VolvoxGrid, width: i32, height: i32, vp: &VisibleRange) -> Self {
        Self {
            viewport: (width, height),
            data_x: vp.data_x,
            data_y: vp.data_y,
            data_w: vp.data_w,
            data_h: vp.data_h,
            fixed_width: grid.col_pos(vp.fixed_col_end),
            fixed_height: grid.row_pos(vp.fixed_row_end),
            pinned_top_rows: vp.pinned_top_rows.clone(),
            pinned_bottom_rows: vp.pinned_bottom_rows.clone(),
            sticky_top_rows: vp.sticky_top_rows.clone(),
            sticky_bottom_rows: vp.sticky_bottom_rows.clone(),
            sticky_left_cols: vp.sticky_left_cols.clone(),
            sticky_right_cols: vp.sticky_right_cols.clone(),
            pinned_top_height: vp.pinned_top_height,
            pinned_bottom_height: vp.pinned_bottom_height,
            sticky_top_height: vp.sticky_top_height,
            sticky_bottom_height: vp.sticky_bottom_height,
            sticky_left_width: vp.sticky_left_width,
            sticky_right_width: vp.sticky_right_width,
        }
    }

    fn horizontal_moving_rect(&self) -> Option<DamageRect> {
        let x = self.data_x + self.fixed_width + self.sticky_left_width;
        let w = self.data_w - self.fixed_width - self.sticky_left_width - self.sticky_right_width;
        (w > 0 && self.data_h > 0).then_some(DamageRect {
            x,
            y: self.data_y,
            w,
            h: self.data_h,
        })
    }

    fn vertical_moving_rect(&self) -> Option<DamageRect> {
        let y = self.data_y + self.fixed_height + self.pinned_top_height + self.sticky_top_height;
        let h = self.data_h
            - self.fixed_height
            - self.pinned_top_height
            - self.sticky_top_height
            - self.pinned_bottom_height
            - self.sticky_bottom_height;
        (self.data_w > 0 && h > 0).then_some(DamageRect {
            x: self.data_x,
            y,
            w: self.data_w,
            h,
        })
    }
}

#[derive(Clone, Debug)]
pub(crate) struct ScrollCacheState {
    valid: bool,
    scroll_x_px: i32,
    scroll_y_px: i32,
    generation: u64,
    mouse_row: i32,
    mouse_col: i32,
    bands: ScrollBands,
}

#[derive(Clone, Copy, Debug)]
pub(crate) struct ScrollAxisBlit {
    pub rect: DamageRect,
    pub screen_dx: i32,
    pub screen_dy: i32,
}

#[derive(Clone, Copy, Debug)]
pub(crate) struct ScrollBlitPlan {
    pub damage: DamageRegion,
    pub horizontal: Option<ScrollAxisBlit>,
    pub vertical: Option<ScrollAxisBlit>,
}

impl Default for ScrollCacheState {
    fn default() -> Self {
        Self {
            valid: false,
            scroll_x_px: 0,
            scroll_y_px: 0,
            generation: 0,
            mouse_row: -1,
            mouse_col: -1,
            bands: ScrollBands {
                viewport: (0, 0),
                data_x: 0,
                data_y: 0,
                data_w: 0,
                data_h: 0,
                fixed_width: 0,
                fixed_height: 0,
                pinned_top_rows: Vec::new(),
                pinned_bottom_rows: Vec::new(),
                sticky_top_rows: Vec::new(),
                sticky_bottom_rows: Vec::new(),
                sticky_left_cols: Vec::new(),
                sticky_right_cols: Vec::new(),
                pinned_top_height: 0,
                pinned_bottom_height: 0,
                sticky_top_height: 0,
                sticky_bottom_height: 0,
                sticky_left_width: 0,
                sticky_right_width: 0,
            },
        }
    }
}

impl ScrollCacheState {
    pub(crate) fn snapshot(grid: &VolvoxGrid, width: i32, height: i32) -> Self {
        let vp = VisibleRange::compute(grid, width, height);
        Self {
            valid: grid.scroll_blit_enabled
                && !grid.animation.active
                && !grid.is_editing()
                && grid.style.background_image.is_empty()
                && !grid.right_to_left,
            scroll_x_px: grid.scroll.scroll_x as i32,
            scroll_y_px: grid.scroll.scroll_y as i32,
            generation: grid.text_meta_generation,
            mouse_row: grid.mouse_row,
            mouse_col: grid.mouse_col,
            bands: ScrollBands::from_visible_range(grid, width, height, &vp),
        }
    }
}

pub(crate) struct ScrollCache {
    prev: ScrollCacheState,
}

impl ScrollCache {
    pub(crate) fn new() -> Self {
        Self {
            prev: ScrollCacheState::default(),
        }
    }

    pub(crate) fn plan(&self, current: &ScrollCacheState) -> Option<ScrollBlitPlan> {
        let prev = &self.prev;
        if !prev.valid || !current.valid {
            return None;
        }
        if prev.generation != current.generation
            || prev.mouse_row != current.mouse_row
            || prev.mouse_col != current.mouse_col
            || prev.bands != current.bands
        {
            return None;
        }

        let delta_x = current.scroll_x_px - prev.scroll_x_px;
        let delta_y = current.scroll_y_px - prev.scroll_y_px;
        if delta_x == 0 && delta_y == 0 {
            return None;
        }

        let mut plan = ScrollBlitPlan {
            damage: DamageRegion::default(),
            horizontal: None,
            vertical: None,
        };

        if delta_x != 0 {
            let Some(rect) = current.bands.horizontal_moving_rect() else {
                return None;
            };
            if delta_x.abs() >= rect.w {
                return None;
            }
            let screen_dx = -delta_x;
            plan.horizontal = Some(ScrollAxisBlit {
                rect,
                screen_dx,
                screen_dy: 0,
            });
            plan.damage.mark_scrolled_x();
            for edge in horizontal_damage_edges(rect, screen_dx.abs()) {
                plan.damage.push(edge);
            }
        }

        if delta_y != 0 {
            let Some(rect) = current.bands.vertical_moving_rect() else {
                return None;
            };
            if delta_y.abs() >= rect.h {
                return None;
            }
            let screen_dy = -delta_y;
            plan.vertical = Some(ScrollAxisBlit {
                rect,
                screen_dx: 0,
                screen_dy,
            });
            plan.damage.mark_scrolled_y();
            for edge in vertical_damage_edges(rect, screen_dy.abs()) {
                plan.damage.push(edge);
            }
        }

        (!plan.damage.is_empty()).then_some(plan)
    }

    pub(crate) fn try_blit(
        &self,
        buffer: &mut [u8],
        stride: i32,
        current: &ScrollCacheState,
    ) -> Option<DamageRegion> {
        let plan = self.plan(current)?;

        if let Some(horizontal) = plan.horizontal {
            blit_horizontal(buffer, stride, horizontal.rect, horizontal.screen_dx);
        }
        if let Some(vertical) = plan.vertical {
            blit_vertical(buffer, stride, vertical.rect, vertical.screen_dy);
        }

        Some(plan.damage)
    }

    pub(crate) fn finish(&mut self, current: ScrollCacheState) {
        self.prev = current;
    }

    #[cfg(feature = "gpu")]
    pub(crate) fn invalidate(&mut self) {
        self.prev = ScrollCacheState::default();
    }
}

fn horizontal_damage_edges(rect: DamageRect, amount: i32) -> [DamageRect; 2] {
    let w = (amount + 1).min(rect.w);
    [
        DamageRect {
            x: rect.x,
            y: rect.y,
            w,
            h: rect.h,
        },
        DamageRect {
            x: rect.x + rect.w - w,
            y: rect.y,
            w,
            h: rect.h,
        },
    ]
}

fn vertical_damage_edges(rect: DamageRect, amount: i32) -> [DamageRect; 2] {
    let h = (amount + 1).min(rect.h);
    [
        DamageRect {
            x: rect.x,
            y: rect.y,
            w: rect.w,
            h,
        },
        DamageRect {
            x: rect.x,
            y: rect.y + rect.h - h,
            w: rect.w,
            h,
        },
    ]
}

fn blit_horizontal(buffer: &mut [u8], stride: i32, rect: DamageRect, screen_dx: i32) {
    let stride = stride as usize;
    let byte_x = (rect.x * 4) as usize;
    let byte_w = (rect.w * 4) as usize;
    let shift = (screen_dx.abs() * 4) as usize;

    for row in rect.y..rect.y + rect.h {
        let row_start = row as usize * stride;
        let slice = &mut buffer[row_start + byte_x..row_start + byte_x + byte_w];
        if screen_dx > 0 {
            slice.copy_within(0..byte_w - shift, shift);
        } else {
            slice.copy_within(shift..byte_w, 0);
        }
    }
}

fn blit_vertical(buffer: &mut [u8], stride: i32, rect: DamageRect, screen_dy: i32) {
    let stride = stride as usize;
    let byte_x = (rect.x * 4) as usize;
    let byte_w = (rect.w * 4) as usize;
    let rows = rect.h as usize;
    let shift = screen_dy.unsigned_abs() as usize;

    if screen_dy > 0 {
        for row in (0..rows - shift).rev() {
            let src = (rect.y as usize + row) * stride + byte_x;
            let dst = (rect.y as usize + row + shift) * stride + byte_x;
            buffer.copy_within(src..src + byte_w, dst);
        }
    } else {
        for row in 0..rows - shift {
            let src = (rect.y as usize + row + shift) * stride + byte_x;
            let dst = (rect.y as usize + row) * stride + byte_x;
            buffer.copy_within(src..src + byte_w, dst);
        }
    }
}

impl Default for ScrollCache {
    fn default() -> Self {
        Self::new()
    }
}
