use crate::grid::VolvoxGrid;
use crate::proto::volvoxgrid::v1 as pb;
#[cfg(not(target_arch = "wasm32"))]
use std::time::Instant;
#[cfg(target_arch = "wasm32")]
use web_time::Instant;

pub const DEFAULT_SCROLLBAR_MIN_THUMB: i32 = 12;
pub const DEFAULT_SCROLLBAR_FADE_DELAY_MS: i32 = 1000;
pub const DEFAULT_SCROLLBAR_FADE_DURATION_MS: i32 = 300;
pub const DEFAULT_SCROLLBAR_MARGIN: i32 = 2;

#[derive(Clone, Copy, Debug, Default, PartialEq, Eq)]
pub struct ScrollBarColors {
    pub thumb: u32,
    pub thumb_hover: u32,
    pub thumb_active: u32,
    pub track: u32,
    pub arrow: u32,
    pub border: u32,
}

#[derive(Clone, Copy, Debug, Default)]
pub(crate) struct ScrollBarGeometry {
    pub show_h: bool,
    pub show_v: bool,
    pub overlays_content: bool,
    pub uses_arrows: bool,
    pub bar_size: i32,
    pub view_w: i32,
    pub view_h: i32,
    pub h_bar_x: i32,
    pub h_bar_y: i32,
    pub h_bar_w: i32,
    pub h_bar_h: i32,
    pub h_left_arrow_x: i32,
    pub h_right_arrow_x: i32,
    pub h_track_x: i32,
    pub h_track_y: i32,
    pub h_track_w: i32,
    pub h_track_h: i32,
    pub h_thumb_x: i32,
    pub h_thumb_y: i32,
    pub h_thumb_w: i32,
    pub h_thumb_h: i32,
    pub h_thumb_range: i32,
    pub h_max_scroll: f32,
    pub v_bar_x: i32,
    pub v_bar_y: i32,
    pub v_bar_w: i32,
    pub v_bar_h: i32,
    pub v_top_arrow_y: i32,
    pub v_bot_arrow_y: i32,
    pub v_track_x: i32,
    pub v_track_y: i32,
    pub v_track_w: i32,
    pub v_track_h: i32,
    pub v_thumb_x: i32,
    pub v_thumb_y: i32,
    pub v_thumb_w: i32,
    pub v_thumb_h: i32,
    pub v_thumb_range: i32,
    pub v_max_scroll: f32,
    pub corner_x: i32,
    pub corner_y: i32,
    pub corner_w: i32,
    pub corner_h: i32,
}

impl ScrollBarGeometry {
    pub fn contains_h(&self, px: i32, py: i32) -> bool {
        self.show_h
            && px >= self.h_bar_x
            && px < self.h_bar_x + self.h_bar_w
            && py >= self.h_bar_y
            && py < self.h_bar_y + self.h_bar_h
    }

    pub fn contains_v(&self, px: i32, py: i32) -> bool {
        self.show_v
            && px >= self.v_bar_x
            && px < self.v_bar_x + self.v_bar_w
            && py >= self.v_bar_y
            && py < self.v_bar_y + self.v_bar_h
    }
}

pub(crate) fn normalize_scrollbar_mode(mode: i32) -> i32 {
    match mode {
        m if m == pb::ScrollBarMode::ScrollbarModeAuto as i32 => m,
        m if m == pb::ScrollBarMode::ScrollbarModeAlways as i32 => m,
        m if m == pb::ScrollBarMode::ScrollbarModeNever as i32 => m,
        _ => pb::ScrollBarMode::ScrollbarModeNever as i32,
    }
}

pub(crate) fn normalize_scrollbar_appearance(appearance: i32) -> i32 {
    match appearance {
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceClassic as i32 => a,
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceFlat as i32 => a,
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceModern as i32 => a,
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceOverlay as i32 => a,
        _ => pb::ScrollBarAppearance::ScrollbarAppearanceClassic as i32,
    }
}

pub(crate) fn default_scrollbar_size(appearance: i32) -> i32 {
    match normalize_scrollbar_appearance(appearance) {
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceModern as i32 => 8,
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceOverlay as i32 => 6,
        _ => 16,
    }
}

pub(crate) fn default_scrollbar_corner_radius(appearance: i32) -> i32 {
    match normalize_scrollbar_appearance(appearance) {
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceModern as i32 => 4,
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceOverlay as i32 => 4,
        _ => 0,
    }
}

pub(crate) fn scrollbar_uses_arrows(appearance: i32) -> bool {
    matches!(
        normalize_scrollbar_appearance(appearance),
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceClassic as i32
            || a == pb::ScrollBarAppearance::ScrollbarAppearanceFlat as i32
    )
}

pub(crate) fn scrollbar_overlays_content(appearance: i32) -> bool {
    normalize_scrollbar_appearance(appearance)
        == pb::ScrollBarAppearance::ScrollbarAppearanceOverlay as i32
}

pub(crate) fn scrollbar_mode_visible(mode: i32, overflow: bool) -> bool {
    match normalize_scrollbar_mode(mode) {
        m if m == pb::ScrollBarMode::ScrollbarModeAlways as i32 => true,
        m if m == pb::ScrollBarMode::ScrollbarModeNever as i32 => false,
        _ => overflow,
    }
}

pub(crate) fn default_scrollbar_colors(appearance: i32) -> ScrollBarColors {
    match normalize_scrollbar_appearance(appearance) {
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceFlat as i32 => ScrollBarColors {
            thumb: 0xFFB8B8B8,
            thumb_hover: 0xFFC7C7C7,
            thumb_active: 0xFF999999,
            track: 0xFFE3E3E3,
            arrow: 0xFF202020,
            border: 0xFF6C6C6C,
        },
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceModern as i32 => ScrollBarColors {
            thumb: 0xFF7A7A7A,
            thumb_hover: 0xFF666666,
            thumb_active: 0xFF505050,
            track: 0xFFE5E5E5,
            arrow: 0x00000000,
            border: 0xFFB8B8B8,
        },
        a if a == pb::ScrollBarAppearance::ScrollbarAppearanceOverlay as i32 => ScrollBarColors {
            thumb: 0xAA4E4E4E,
            thumb_hover: 0xCC404040,
            thumb_active: 0xEE303030,
            track: 0x22000000,
            arrow: 0x00000000,
            border: 0x44000000,
        },
        _ => ScrollBarColors {
            thumb: 0xFFC0C0C0,
            thumb_hover: 0xFFD0D0D0,
            thumb_active: 0xFFA8A8A8,
            track: 0xFFD8D8D8,
            arrow: 0xFF000000,
            border: 0xFF606060,
        },
    }
}

pub(crate) fn merge_scrollbar_colors(
    mut base: ScrollBarColors,
    patch: Option<&pb::ScrollBarColors>,
) -> ScrollBarColors {
    let Some(patch) = patch else {
        return base;
    };
    if let Some(v) = patch.thumb {
        base.thumb = v;
    }
    if let Some(v) = patch.thumb_hover {
        base.thumb_hover = v;
    }
    if let Some(v) = patch.thumb_active {
        base.thumb_active = v;
    }
    if let Some(v) = patch.track {
        base.track = v;
    }
    if let Some(v) = patch.arrow {
        base.arrow = v;
    }
    if let Some(v) = patch.border {
        base.border = v;
    }
    base
}

pub(crate) fn scale_color_alpha(color: u32, opacity: f32) -> u32 {
    let opacity = opacity.clamp(0.0, 1.0);
    let alpha = ((color >> 24) & 0xFF) as f32;
    let scaled = (alpha * opacity).round().clamp(0.0, 255.0) as u32;
    (color & 0x00FF_FFFF) | (scaled << 24)
}

pub(crate) fn bump_scrollbar_fade(grid: &mut VolvoxGrid) -> bool {
    if !scrollbar_overlays_content(grid.scrollbar_appearance) {
        grid.scrollbar_fade_last_tick = None;
        return false;
    }
    let old_opacity = grid.scrollbar_fade_opacity;
    let old_timer = grid.scrollbar_fade_timer;
    grid.scrollbar_fade_opacity = 1.0;
    grid.scrollbar_fade_timer = (grid.scrollbar_fade_delay_ms.max(0) as f32) / 1000.0;
    grid.scrollbar_fade_last_tick = if grid.animation.enabled {
        Some(Instant::now())
    } else {
        None
    };
    (grid.scrollbar_fade_opacity - old_opacity).abs() > f32::EPSILON
        || (grid.scrollbar_fade_timer - old_timer).abs() > f32::EPSILON
}

pub(crate) fn scrollbar_fade_animating(grid: &VolvoxGrid) -> bool {
    grid.animation.enabled
        && scrollbar_overlays_content(grid.scrollbar_appearance)
        && !grid.scrollbar_hover
        && !grid.scrollbar_drag_active
        && !grid.scrollbar_repeat_active
        && (grid.scrollbar_fade_timer > 0.0 || grid.scrollbar_fade_opacity > 0.0)
}

pub(crate) fn reset_scrollbar_fade_state(grid: &mut VolvoxGrid) {
    grid.scrollbar_hover = false;
    grid.scrollbar_fade_opacity = 1.0;
    grid.scrollbar_fade_timer = if scrollbar_overlays_content(grid.scrollbar_appearance) {
        (grid.scrollbar_fade_delay_ms.max(0) as f32) / 1000.0
    } else {
        0.0
    };
    grid.scrollbar_fade_last_tick =
        if scrollbar_overlays_content(grid.scrollbar_appearance) && grid.animation.enabled {
            Some(Instant::now())
        } else {
            None
        };
}

pub(crate) fn compute_scrollbar_geometry(
    grid: &VolvoxGrid,
    buf_w: i32,
    buf_h: i32,
) -> ScrollBarGeometry {
    let appearance = normalize_scrollbar_appearance(grid.scrollbar_appearance);
    let bar_size = grid.scrollbar_size.max(1);
    let min_thumb = grid.scrollbar_min_thumb.max(1);
    let overlays_content = scrollbar_overlays_content(appearance);
    let uses_arrows = scrollbar_uses_arrows(appearance);
    let margin = if overlays_content {
        grid.scrollbar_margin.max(0)
    } else {
        0
    };
    let mode_h = normalize_scrollbar_mode(grid.scrollbar_show_h);
    let mode_v = normalize_scrollbar_mode(grid.scrollbar_show_v);

    let fixed_height = grid.layout.row_pos(grid.fixed_rows);
    let fixed_width = grid.layout.col_pos(grid.fixed_cols);
    let pinned_height = grid.pinned_top_height() + grid.pinned_bottom_height();
    let pinned_width = grid.pinned_left_width() + grid.pinned_right_width();

    let compute_max_scroll = |view_w: i32, view_h: i32| -> (f32, f32) {
        let mx = (grid.layout.total_width - view_w + fixed_width + pinned_width).max(0) as f32;
        let my = (grid.layout.total_height - view_h + fixed_height + pinned_height).max(0) as f32;
        (mx, my)
    };

    let mut show_h = mode_h == pb::ScrollBarMode::ScrollbarModeAlways as i32;
    let mut show_v = mode_v == pb::ScrollBarMode::ScrollbarModeAlways as i32;
    for _ in 0..3 {
        let view_w = (buf_w
            - if show_v && !overlays_content {
                bar_size
            } else {
                0
            })
        .max(1);
        let view_h = (buf_h
            - if show_h && !overlays_content {
                bar_size
            } else {
                0
            })
        .max(1);
        let (mx, my) = compute_max_scroll(view_w, view_h);
        let next_h = scrollbar_mode_visible(mode_h, mx > 0.0);
        let next_v = scrollbar_mode_visible(mode_v, my > 0.0);
        if next_h == show_h && next_v == show_v {
            break;
        }
        show_h = next_h;
        show_v = next_v;
    }

    let view_w = (buf_w
        - if show_v && !overlays_content {
            bar_size
        } else {
            0
        })
    .max(1);
    let view_h = (buf_h
        - if show_h && !overlays_content {
            bar_size
        } else {
            0
        })
    .max(1);
    let (max_x, max_y) = compute_max_scroll(view_w, view_h);
    let scroll_x = grid.scroll.scroll_x.clamp(0.0, max_x);
    let scroll_y = grid.scroll.scroll_y.clamp(0.0, max_y);

    let mut geom = ScrollBarGeometry {
        show_h,
        show_v,
        overlays_content,
        uses_arrows,
        bar_size,
        view_w,
        view_h,
        h_max_scroll: max_x,
        v_max_scroll: max_y,
        ..Default::default()
    };

    if show_h {
        let x = if overlays_content { margin } else { 0 };
        let y = if overlays_content {
            buf_h - bar_size - margin
        } else {
            buf_h - bar_size
        };
        let end_x = if overlays_content {
            buf_w - margin - if show_v { bar_size + margin } else { 0 }
        } else {
            buf_w - if show_v { bar_size } else { 0 }
        };
        let w = (end_x - x).max(1);
        geom.h_bar_x = x;
        geom.h_bar_y = y;
        geom.h_bar_w = w;
        geom.h_bar_h = bar_size;
        if uses_arrows {
            geom.h_left_arrow_x = x;
            geom.h_right_arrow_x = x + w - bar_size;
            geom.h_track_x = x + bar_size;
            geom.h_track_y = y;
            geom.h_track_w = (w - bar_size * 2).max(0);
            geom.h_track_h = bar_size;
        } else {
            geom.h_left_arrow_x = x;
            geom.h_right_arrow_x = x + w;
            geom.h_track_x = x;
            geom.h_track_y = y;
            geom.h_track_w = w.max(0);
            geom.h_track_h = bar_size;
        }
        if geom.h_track_w > 0 {
            let mut thumb_w = if max_x > 0.0 {
                ((view_w as f32 / (view_w as f32 + max_x)) * geom.h_track_w as f32).round() as i32
            } else {
                geom.h_track_w
            };
            thumb_w = thumb_w
                .clamp(min_thumb, geom.h_track_w.max(min_thumb))
                .min(geom.h_track_w);
            geom.h_thumb_range = (geom.h_track_w - thumb_w).max(0);
            let thumb_off = if max_x > 0.0 && geom.h_thumb_range > 0 {
                ((scroll_x / max_x) * geom.h_thumb_range as f32).round() as i32
            } else {
                0
            };
            geom.h_thumb_x = geom.h_track_x + thumb_off;
            geom.h_thumb_y = if uses_arrows { y + 1 } else { y };
            geom.h_thumb_w = thumb_w;
            geom.h_thumb_h = if uses_arrows {
                (bar_size - 2).max(1)
            } else {
                bar_size
            };
        } else {
            geom.h_thumb_x = geom.h_track_x;
            geom.h_thumb_y = y;
        }
    }

    if show_v {
        let x = if overlays_content {
            buf_w - bar_size - margin
        } else {
            buf_w - bar_size
        };
        let y = if overlays_content { margin } else { 0 };
        let end_y = if overlays_content {
            buf_h - margin - if show_h { bar_size + margin } else { 0 }
        } else {
            buf_h - if show_h { bar_size } else { 0 }
        };
        let h = (end_y - y).max(1);
        geom.v_bar_x = x;
        geom.v_bar_y = y;
        geom.v_bar_w = bar_size;
        geom.v_bar_h = h;
        if uses_arrows {
            geom.v_top_arrow_y = y;
            geom.v_bot_arrow_y = y + h - bar_size;
            geom.v_track_x = x;
            geom.v_track_y = y + bar_size;
            geom.v_track_w = bar_size;
            geom.v_track_h = (h - bar_size * 2).max(0);
        } else {
            geom.v_top_arrow_y = y;
            geom.v_bot_arrow_y = y + h;
            geom.v_track_x = x;
            geom.v_track_y = y;
            geom.v_track_w = bar_size;
            geom.v_track_h = h.max(0);
        }
        if geom.v_track_h > 0 {
            let mut thumb_h = if max_y > 0.0 {
                ((view_h as f32 / (view_h as f32 + max_y)) * geom.v_track_h as f32).round() as i32
            } else {
                geom.v_track_h
            };
            thumb_h = thumb_h
                .clamp(min_thumb, geom.v_track_h.max(min_thumb))
                .min(geom.v_track_h);
            geom.v_thumb_range = (geom.v_track_h - thumb_h).max(0);
            let thumb_off = if max_y > 0.0 && geom.v_thumb_range > 0 {
                ((scroll_y / max_y) * geom.v_thumb_range as f32).round() as i32
            } else {
                0
            };
            geom.v_thumb_x = if uses_arrows { x + 1 } else { x };
            geom.v_thumb_y = geom.v_track_y + thumb_off;
            geom.v_thumb_w = if uses_arrows {
                (bar_size - 2).max(1)
            } else {
                bar_size
            };
            geom.v_thumb_h = thumb_h;
        } else {
            geom.v_thumb_x = x;
            geom.v_thumb_y = geom.v_track_y;
        }
    }

    if show_h && show_v && !overlays_content {
        geom.corner_x = buf_w - bar_size;
        geom.corner_y = buf_h - bar_size;
        geom.corner_w = bar_size;
        geom.corner_h = bar_size;
    }

    geom
}
