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
int32_t volvox_grid_set_event_decision_enabled_native(int64_t id, int32_t enabled);
uint8_t* volvox_grid_peek_next_event_native(int64_t id, int32_t* out_len);
int32_t volvox_grid_ack_event_native(int64_t id, int64_t event_id);
uint8_t* volvox_grid_take_next_event_native(int64_t id, int32_t* out_len);
int32_t volvox_grid_send_event_decision_native(int64_t id, int64_t event_id, int32_t cancel);
int32_t volvox_grid_set_hover_mode_native(int64_t id, uint32_t mode);
int32_t volvox_grid_set_debug_overlay_native(int64_t id, int32_t enabled);
int32_t volvox_grid_set_scroll_blit_native(int64_t id, int32_t enabled);

/* ActiveX container integration hooks. COM/HDC handles are passed opaquely. */
typedef int32_t (*volvox_grid_stream_write_fn)(
    void* ctx,
    const uint8_t* data,
    int32_t len
);
typedef int32_t (*volvox_grid_stream_read_fn)(
    void* ctx,
    uint8_t* data,
    int32_t cap
);
typedef int32_t (*volvox_grid_owner_draw_callback_fn)(
    void* ctx,
    int64_t grid_id,
    void* hdc,
    int32_t row,
    int32_t col,
    int32_t left,
    int32_t top,
    int32_t right,
    int32_t bottom
);
typedef int32_t (*volvox_grid_owner_draw_measure_fn)(
    void* ctx,
    int64_t grid_id,
    int32_t row,
    int32_t col,
    int32_t* out_width,
    int32_t* out_height
);
int32_t volvox_grid_get_extent_himetric_native(int64_t id, int32_t* cx, int32_t* cy);
int32_t volvox_grid_paint_to_hdc_native(
    int64_t id,
    void* hdc,
    int32_t x,
    int32_t y,
    int32_t w,
    int32_t h,
    int32_t aspect
);
int32_t volvox_grid_save_ole_stream_native(
    int64_t id,
    volvox_grid_stream_write_fn write_fn,
    void* ctx
);
int32_t volvox_grid_load_ole_stream_native(
    int64_t id,
    volvox_grid_stream_read_fn read_fn,
    void* ctx
);
int32_t volvox_grid_ado_attach_native(int64_t id, void* dispatch);
int32_t volvox_grid_ado_detach_native(int64_t id);
int32_t volvox_grid_ado_pump_row_native(int64_t id, int32_t row);
int32_t volvox_grid_ado_fetch_window_native(int64_t id, int32_t start, int32_t count);
int32_t volvox_grid_ole_begin_drag_native(
    int64_t id,
    int32_t allowed_effects,
    int32_t* out_effect
);
int32_t volvox_grid_set_data_format_native(
    int64_t id,
    uint32_t cf,
    const uint8_t* bytes,
    int32_t len
);
int32_t volvox_grid_set_owner_draw_callback_native(
    int64_t id,
    volvox_grid_owner_draw_callback_fn callback,
    void* ctx
);
int32_t volvox_grid_owner_draw_reply_native(int64_t id, int32_t done);
int32_t volvox_grid_owner_draw_measure_callback_native(
    int64_t id,
    volvox_grid_owner_draw_measure_fn callback,
    void* ctx
);
int32_t volvox_grid_set_row_image_list_native(int64_t id, int32_t row, int32_t handle);
int32_t volvox_grid_set_col_picture_type_native(int64_t id, int32_t col, int32_t picture_type);
int32_t volvox_grid_set_image_and_text_native(int64_t id, int32_t enabled);
int32_t volvox_grid_get_dispid_default_native(int64_t id, int32_t dispid, void* variant_out);

/* Color properties (OLE_COLOR as u32 ARGB) */
int32_t  volvox_grid_set_back_color(int64_t id, uint32_t color);
uint32_t volvox_grid_get_back_color(int64_t id);
int32_t  volvox_grid_set_fore_color(int64_t id, uint32_t color);
uint32_t volvox_grid_get_fore_color(int64_t id);
int32_t  volvox_grid_set_grid_color(int64_t id, uint32_t color);
uint32_t volvox_grid_get_grid_color(int64_t id);
int32_t  volvox_grid_set_grid_color_fixed(int64_t id, uint32_t color);
uint32_t volvox_grid_get_grid_color_fixed(int64_t id);
int32_t  volvox_grid_set_back_color_fixed(int64_t id, uint32_t color);
uint32_t volvox_grid_get_back_color_fixed(int64_t id);
int32_t  volvox_grid_set_fore_color_fixed(int64_t id, uint32_t color);
uint32_t volvox_grid_get_fore_color_fixed(int64_t id);
int32_t  volvox_grid_set_back_color_frozen_native(int64_t id, uint32_t color);
uint32_t volvox_grid_get_back_color_frozen_native(int64_t id);
int32_t  volvox_grid_set_fore_color_frozen_native(int64_t id, uint32_t color);
uint32_t volvox_grid_get_fore_color_frozen_native(int64_t id);
int32_t  volvox_grid_set_back_color_bkg_native(int64_t id, uint32_t color);
uint32_t volvox_grid_get_back_color_bkg_native(int64_t id);
int32_t  volvox_grid_set_back_color_sel(int64_t id, uint32_t color);
uint32_t volvox_grid_get_back_color_sel(int64_t id);
int32_t  volvox_grid_set_fore_color_sel(int64_t id, uint32_t color);
uint32_t volvox_grid_get_fore_color_sel(int64_t id);
int32_t  volvox_grid_set_back_color_alternate(int64_t id, uint32_t color);
uint32_t volvox_grid_get_back_color_alternate(int64_t id);
int32_t  volvox_grid_set_tree_color_native(int64_t id, uint32_t color);
uint32_t volvox_grid_get_tree_color(int64_t id);
int32_t  volvox_grid_set_sheet_border_native(int64_t id, uint32_t color);
uint32_t volvox_grid_get_sheet_border_native(int64_t id);
int32_t  volvox_grid_set_flood_color_native(int64_t id, uint32_t color);
uint32_t volvox_grid_get_flood_color_native(int64_t id);

/* Grid lines */
int32_t volvox_grid_set_appearance_native(int64_t id, int32_t value);
int32_t volvox_grid_get_appearance_native(int64_t id);
int32_t volvox_grid_set_grid_lines_native(int64_t id, int32_t value);
int32_t volvox_grid_get_grid_lines(int64_t id);
int32_t volvox_grid_set_grid_lines_fixed_native(int64_t id, int32_t value);
int32_t volvox_grid_get_grid_lines_fixed(int64_t id);
int32_t volvox_grid_set_grid_line_width_native(int64_t id, int32_t value);
int32_t volvox_grid_get_grid_line_width_native(int64_t id);
int32_t volvox_grid_set_allow_user_freezing_native(int64_t id, int32_t mode);
int32_t volvox_grid_get_allow_user_freezing_native(int64_t id);
int32_t volvox_grid_set_explorer_bar_native(int64_t id, int32_t mode);
int32_t volvox_grid_get_explorer_bar_native(int64_t id);
int32_t volvox_grid_set_tab_behavior_native(int64_t id, int32_t behavior);
int32_t volvox_grid_get_tab_behavior_native(int64_t id);
int32_t volvox_grid_get_editable_native(int64_t id);
int32_t volvox_grid_set_row_height_min_native(int64_t id, int32_t height);
int32_t volvox_grid_get_row_height_min_native(int64_t id);
int32_t volvox_grid_set_col_width_min_default_native(int64_t id, int32_t width);
int32_t volvox_grid_get_col_width_min_default_native(int64_t id);
int32_t volvox_grid_set_col_indent_native(int64_t id, int32_t col, int32_t indent);
int32_t volvox_grid_get_col_indent_native(int64_t id, int32_t col);
int32_t volvox_grid_set_col_image_list_native(int64_t id, int32_t col, int32_t handle);
int32_t volvox_grid_get_col_image_list_native(int64_t id, int32_t col);
uint8_t* volvox_grid_get_format_string_native(int64_t id, int32_t* out_len);
uint8_t* volvox_grid_get_combo_list_native(int64_t id, int32_t* out_len);
uint8_t* volvox_grid_set_clip_separators_compat_native(
    int64_t id,
    const uint8_t* value,
    int32_t value_len,
    int32_t* out_len
);
uint8_t* volvox_grid_get_clip_separators_native(int64_t id, int32_t* out_len);

/* Font */
int32_t volvox_grid_set_font_size(int64_t id, float size);
float   volvox_grid_get_font_size(int64_t id);
int32_t volvox_grid_set_font_name(int64_t id, const uint8_t* name, int32_t len);
uint8_t* volvox_grid_get_font_name(int64_t id, int32_t* out_len);
int32_t volvox_grid_set_font_bold_native(int64_t id, int32_t value);
int32_t volvox_grid_get_font_bold_native(int64_t id);
int32_t volvox_grid_set_font_italic_native(int64_t id, int32_t value);
int32_t volvox_grid_get_font_italic_native(int64_t id);
int32_t volvox_grid_set_font_underline_native(int64_t id, int32_t value);
int32_t volvox_grid_get_font_underline_native(int64_t id);
int32_t volvox_grid_set_font_strikethrough_native(int64_t id, int32_t value);
int32_t volvox_grid_get_font_strikethrough_native(int64_t id);
int32_t volvox_grid_set_font_width_native(int64_t id, int32_t value);
int32_t volvox_grid_get_font_width_native(int64_t id);
int32_t volvox_grid_get_cursor_style_native(int64_t id);

/* ActiveX compatibility helpers */
uint8_t* volvox_grid_set_cell_picture_range_native(
    int64_t grid_id,
    int32_t row1,
    int32_t col1,
    int32_t row2,
    int32_t col2,
    const uint8_t* image,
    int32_t image_len,
    int32_t* out_len
);
uint8_t* volvox_grid_get_cell_picture_native(
    int64_t grid_id,
    int32_t row,
    int32_t col,
    int32_t* out_len
);
uint8_t* volvox_grid_set_cell_button_picture_range_native(
    int64_t grid_id,
    int32_t row1,
    int32_t col1,
    int32_t row2,
    int32_t col2,
    const uint8_t* image,
    int32_t image_len,
    int32_t* out_len
);
uint8_t* volvox_grid_get_cell_button_picture_native(
    int64_t grid_id,
    int32_t row,
    int32_t col,
    int32_t* out_len
);
uint8_t* volvox_grid_set_node_open_picture_native(
    int64_t grid_id,
    const uint8_t* image,
    int32_t image_len,
    int32_t* out_len
);
uint8_t* volvox_grid_get_node_open_picture_native(
    int64_t grid_id,
    int32_t* out_len
);
uint8_t* volvox_grid_set_node_closed_picture_native(
    int64_t grid_id,
    const uint8_t* image,
    int32_t image_len,
    int32_t* out_len
);
uint8_t* volvox_grid_get_node_closed_picture_native(
    int64_t grid_id,
    int32_t* out_len
);
uint8_t* volvox_grid_set_sort_ascending_picture_native(
    int64_t grid_id,
    const uint8_t* image,
    int32_t image_len,
    int32_t* out_len
);
uint8_t* volvox_grid_get_sort_ascending_picture_native(
    int64_t grid_id,
    int32_t* out_len
);
uint8_t* volvox_grid_set_sort_descending_picture_native(
    int64_t grid_id,
    const uint8_t* image,
    int32_t image_len,
    int32_t* out_len
);
uint8_t* volvox_grid_get_sort_descending_picture_native(
    int64_t grid_id,
    int32_t* out_len
);
int32_t volvox_grid_set_pictures_over_native(int64_t grid_id, int32_t value);
int32_t volvox_grid_get_pictures_over_native(int64_t grid_id);
uint8_t* volvox_grid_set_wallpaper_native(
    int64_t grid_id,
    const uint8_t* image,
    int32_t image_len,
    int32_t* out_len
);
uint8_t* volvox_grid_get_wallpaper_native(
    int64_t grid_id,
    int32_t* out_len
);
int32_t volvox_grid_set_wallpaper_alignment_native(int64_t grid_id, int32_t alignment);
int32_t volvox_grid_get_wallpaper_alignment_native(int64_t grid_id);
uint8_t* volvox_grid_set_cell_picture_alignment_range_native(
    int64_t grid_id,
    int32_t row1,
    int32_t col1,
    int32_t row2,
    int32_t col2,
    int32_t alignment,
    int32_t* out_len
);
int32_t volvox_grid_get_cell_picture_alignment_native(int64_t grid_id, int32_t row, int32_t col);
uint8_t* volvox_grid_set_cell_back_color_range(
    int64_t grid_id,
    int32_t row1,
    int32_t col1,
    int32_t row2,
    int32_t col2,
    uint32_t color,
    int32_t* out_len
);
uint32_t volvox_grid_get_cell_back_color(int64_t grid_id, int32_t row, int32_t col);
uint8_t* volvox_grid_set_cell_font_bold_range(
    int64_t grid_id,
    int32_t row1,
    int32_t col1,
    int32_t row2,
    int32_t col2,
    int32_t bold,
    int32_t* out_len
);
int32_t volvox_grid_get_cell_font_bold(int64_t grid_id, int32_t row, int32_t col);
uint8_t* volvox_grid_get_value_matrix_compat_text(
    int64_t grid_id,
    int32_t row,
    int32_t col,
    int32_t* out_len
);
uint8_t* volvox_grid_set_cell_fore_color_range_native(
    int64_t grid_id,
    int32_t row1,
    int32_t col1,
    int32_t row2,
    int32_t col2,
    uint32_t color,
    int32_t* out_len
);
uint32_t volvox_grid_get_cell_fore_color_native(int64_t grid_id, int32_t row, int32_t col);
uint8_t* volvox_grid_set_cell_alignment_range_native(
    int64_t grid_id,
    int32_t row1,
    int32_t col1,
    int32_t row2,
    int32_t col2,
    int32_t alignment,
    int32_t* out_len
);
int32_t volvox_grid_get_cell_alignment_native(int64_t grid_id, int32_t row, int32_t col);
float volvox_grid_get_cell_flood_percent_native(int64_t grid_id, int32_t row, int32_t col);
uint8_t* volvox_grid_set_default_row_height_native(
    int64_t grid_id,
    int32_t height,
    int32_t* out_len
);
int32_t volvox_grid_get_row_display_position(int64_t grid_id, int32_t row);
int32_t volvox_grid_get_col_display_position(int64_t grid_id, int32_t col);

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

typedef int32_t (*volvox_grid_custom_compare_fn)(
    void* user_data,
    int32_t row1,
    int32_t row2,
    int32_t col
);

/* Register or clear a synchronous custom sort comparator for ActiveX.
 * The callback is invoked during flexSortCustom and should return
 * -1, 0, or 1 for row1 before/equal/after row2.
 */
int32_t volvox_grid_set_custom_compare_native(
    int64_t grid_id,
    volvox_grid_custom_compare_fn compare_fn,
    void* user_data
);

#ifdef __cplusplus
}
#endif
