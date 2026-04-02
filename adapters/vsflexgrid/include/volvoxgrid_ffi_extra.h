#pragma once

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

/* Render grid to a BGRA pixel buffer (for IViewObject) */
int32_t volvox_grid_render_bgra(int64_t id, uint8_t* buf, int32_t w, int32_t h);
int32_t volvox_grid_resize_viewport_native(int64_t id, int32_t w, int32_t h);
int32_t volvox_grid_pointer_down_native(
    int64_t id,
    float x,
    float y,
    int32_t button,
    int32_t modifier,
    int32_t dbl_click
);
int32_t volvox_grid_pointer_move_native(
    int64_t id,
    float x,
    float y,
    int32_t button,
    int32_t modifier
);
int32_t volvox_grid_pointer_up_native(
    int64_t id,
    float x,
    float y,
    int32_t button,
    int32_t modifier
);
int32_t volvox_grid_scroll_native(int64_t id, float delta_x, float delta_y);
int32_t volvox_grid_key_down_native(int64_t id, int32_t key_code, int32_t modifier);
int32_t volvox_grid_key_press_native(int64_t id, uint32_t char_code);
int32_t volvox_grid_set_hover_mode_native(int64_t id, uint32_t mode);
int32_t volvox_grid_set_debug_overlay_native(int64_t id, int32_t enabled);
int32_t volvox_grid_set_scroll_blit_native(int64_t id, int32_t enabled);

/* Color properties (OLE_COLOR as u32 ARGB) */
int32_t  volvox_grid_set_back_color(int64_t id, uint32_t color);
uint32_t volvox_grid_get_back_color(int64_t id);
int32_t  volvox_grid_set_fore_color(int64_t id, uint32_t color);
uint32_t volvox_grid_get_fore_color(int64_t id);
int32_t  volvox_grid_set_grid_color(int64_t id, uint32_t color);
uint32_t volvox_grid_get_grid_color(int64_t id);
int32_t  volvox_grid_set_back_color_fixed(int64_t id, uint32_t color);
uint32_t volvox_grid_get_back_color_fixed(int64_t id);
int32_t  volvox_grid_set_fore_color_fixed(int64_t id, uint32_t color);
uint32_t volvox_grid_get_fore_color_fixed(int64_t id);
int32_t  volvox_grid_set_back_color_sel(int64_t id, uint32_t color);
uint32_t volvox_grid_get_back_color_sel(int64_t id);
int32_t  volvox_grid_set_fore_color_sel(int64_t id, uint32_t color);
uint32_t volvox_grid_get_fore_color_sel(int64_t id);
int32_t  volvox_grid_set_back_color_alternate(int64_t id, uint32_t color);
uint32_t volvox_grid_get_back_color_alternate(int64_t id);
int32_t  volvox_grid_set_tree_color_native(int64_t id, uint32_t color);
uint32_t volvox_grid_get_tree_color(int64_t id);

/* Grid lines */
int32_t volvox_grid_set_grid_lines_native(int64_t id, int32_t value);
int32_t volvox_grid_get_grid_lines(int64_t id);
int32_t volvox_grid_set_grid_lines_fixed_native(int64_t id, int32_t value);
int32_t volvox_grid_get_grid_lines_fixed(int64_t id);

/* Font */
int32_t volvox_grid_set_font_size(int64_t id, float size);
float   volvox_grid_get_font_size(int64_t id);
int32_t volvox_grid_set_font_name(int64_t id, const uint8_t* name, int32_t len);
uint8_t* volvox_grid_get_font_name(int64_t id, int32_t* out_len);

/*
 * Text/font_name are passed as (const uint8_t*, int32_t len) UTF-8 byte pairs
 * (NOT null-terminated).
 * max_width = -1.0 means no constraint.
 * Color is 0xAARRGGBB (engine internal format).
 * user_data is an opaque void* passed through to all callbacks.
 */
typedef void (*volvox_grid_measure_text_fn)(
    const uint8_t* text_ptr, int32_t text_len,
    const uint8_t* font_name_ptr, int32_t font_name_len,
    float font_size,
    int32_t bold, int32_t italic,
    float max_width,
    float* out_width, float* out_height,
    void* user_data
);

typedef float (*volvox_grid_render_text_fn)(
    uint8_t* buffer, int32_t buf_width, int32_t buf_height, int32_t stride,
    int32_t x, int32_t y,
    int32_t clip_x, int32_t clip_y, int32_t clip_w, int32_t clip_h,
    const uint8_t* text_ptr, int32_t text_len,
    const uint8_t* font_name_ptr, int32_t font_name_len,
    float font_size,
    int32_t bold, int32_t italic,
    uint32_t color,
    float max_width,
    void* user_data
);

/* Register or clear a custom text renderer for a grid.
 * Pass non-null measure_fn + render_fn to enable; pass NULL for both to clear.
 * Returns 0 on success.
 */
int32_t volvox_grid_set_text_renderer(
    int64_t grid_id,
    volvox_grid_measure_text_fn measure_fn,
    volvox_grid_render_text_fn render_fn,
    void* user_data
);

#ifdef __cplusplus
}
#endif
