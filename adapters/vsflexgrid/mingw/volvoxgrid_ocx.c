/* VolvoxGrid.ocx — Raw COM control implementation.
 *
 * Implements IUnknown + IDispatch + IViewObject for the VolvoxGrid ActiveX
 * control.  Each IDispatch method maps to a native C API call (volvox_grid_*).
 *
 * The IViewObject implementation calls volvox_grid_render_bgra() to render
 * the grid to a BGRA pixel buffer and BitBlt's to the caller's DC.
 */

#define WIN32_LEAN_AND_MEAN
#define COBJMACROS
#include <windows.h>
#include <ole2.h>
#include <oleauto.h>
#include <olectl.h>
#include <stdio.h>
#include <string.h>
#include "VolvoxGrid_guids.h"
#include "../include/volvoxgrid_activex_ffi_native.h"
#include "../include/volvoxgrid_ffi_extra.h"
#include "../include/volvoxgrid_activex.h"

/* ════════════════════════════════════════════════════════════════ */
/* Synurang Native ABI Compatibility                               */
/* ════════════════════════════════════════════════════════════════ */

/* New synurang native API frees by pointer only; keep old callsites valid. */
#define volvox_grid_free(ptr, len) volvox_grid_free(ptr)

static int vfg_read_varint(const uint8_t *buf, int32_t len, int32_t *pos, uint64_t *out) {
    uint64_t v = 0;
    int shift = 0;
    while (*pos < len && shift < 64) {
        uint8_t b = buf[(*pos)++];
        v |= ((uint64_t)(b & 0x7F)) << shift;
        if ((b & 0x80) == 0) {
            *out = v;
            return 1;
        }
        shift += 7;
    }
    return 0;
}

static int vfg_skip_wire(const uint8_t *buf, int32_t len, int32_t *pos, uint32_t wire_type) {
    uint64_t n = 0;
    switch (wire_type) {
    case 0: /* varint */
        return vfg_read_varint(buf, len, pos, &n);
    case 1: /* 64-bit */
        if (len - *pos < 8) return 0;
        *pos += 8;
        return 1;
    case 2: /* length-delimited */
        if (!vfg_read_varint(buf, len, pos, &n)) return 0;
        if (n > (uint64_t)(len - *pos)) return 0;
        *pos += (int32_t)n;
        return 1;
    case 5: /* 32-bit */
        if (len - *pos < 4) return 0;
        *pos += 4;
        return 1;
    default:
        return 0;
    }
}

/* Decode field #2 varint from local wrapper messages (Int32Value/BoolValue). */
static int32_t vfg_decode_field2_i32(const uint8_t *data, int32_t len, int32_t fallback) {
    int32_t pos = 0;
    if (!data || len < 0) return fallback;

    while (pos < len) {
        uint64_t key = 0;
        uint32_t field_no, wire_type;
        if (!vfg_read_varint(data, len, &pos, &key)) return fallback;
        field_no = (uint32_t)(key >> 3);
        wire_type = (uint32_t)(key & 0x7);
        if (field_no == 2 && wire_type == 0) {
            uint64_t v = 0;
            if (!vfg_read_varint(data, len, &pos, &v)) return fallback;
            return (int32_t)v;
        }
        if (!vfg_skip_wire(data, len, &pos, wire_type)) return fallback;
    }
    return fallback;
}

static int32_t vfg_take_status_response(uint8_t *data) {
    if (!data) return -1;
    volvox_grid_free(data, 0);
    return 0;
}

static int32_t vfg_take_i32_response(uint8_t *data, int32_t len, int32_t fallback) {
    int32_t out = fallback;
    if (!data) return fallback;
    out = vfg_decode_field2_i32(data, len, fallback);
    volvox_grid_free(data, 0);
    return out;
}

#define VG_WRAP_I32_1(name, t1, a1) \
static int32_t name##_compat(t1 a1) { \
    int32_t out_len = 0; \
    uint8_t *out = name(a1, &out_len); \
    return vfg_take_i32_response(out, out_len, -1); \
}

#define VG_WRAP_I32_2(name, t1, a1, t2, a2) \
static int32_t name##_compat(t1 a1, t2 a2) { \
    int32_t out_len = 0; \
    uint8_t *out = name(a1, a2, &out_len); \
    return vfg_take_i32_response(out, out_len, -1); \
}

#define VG_WRAP_I32_3(name, t1, a1, t2, a2, t3, a3) \
static int32_t name##_compat(t1 a1, t2 a2, t3 a3) { \
    int32_t out_len = 0; \
    uint8_t *out = name(a1, a2, a3, &out_len); \
    return vfg_take_i32_response(out, out_len, -1); \
}

#define VG_WRAP_STATUS_1(name, t1, a1) \
static int32_t name##_compat(t1 a1) { \
    int32_t out_len = 0; \
    uint8_t *out = name(a1, &out_len); \
    return vfg_take_status_response(out); \
}

#define VG_WRAP_STATUS_2(name, t1, a1, t2, a2) \
static int32_t name##_compat(t1 a1, t2 a2) { \
    int32_t out_len = 0; \
    uint8_t *out = name(a1, a2, &out_len); \
    return vfg_take_status_response(out); \
}

#define VG_WRAP_STATUS_3(name, t1, a1, t2, a2, t3, a3) \
static int32_t name##_compat(t1 a1, t2 a2, t3 a3) { \
    int32_t out_len = 0; \
    uint8_t *out = name(a1, a2, a3, &out_len); \
    return vfg_take_status_response(out); \
}

#define VG_WRAP_STATUS_4(name, t1, a1, t2, a2, t3, a3, t4, a4) \
static int32_t name##_compat(t1 a1, t2 a2, t3 a3, t4 a4) { \
    int32_t out_len = 0; \
    uint8_t *out = name(a1, a2, a3, a4, &out_len); \
    return vfg_take_status_response(out); \
}

#define VG_WRAP_STATUS_5(name, t1, a1, t2, a2, t3, a3, t4, a4, t5, a5) \
static int32_t name##_compat(t1 a1, t2 a2, t3 a3, t4 a4, t5 a5) { \
    int32_t out_len = 0; \
    uint8_t *out = name(a1, a2, a3, a4, a5, &out_len); \
    return vfg_take_status_response(out); \
}

#define VG_WRAP_STATUS_9(name, t1, a1, t2, a2, t3, a3, t4, a4, t5, a5, t6, a6, t7, a7, t8, a8, t9, a9) \
static int32_t name##_compat(t1 a1, t2 a2, t3 a3, t4 a4, t5 a5, t6 a6, t7 a7, t8 a8, t9 a9) { \
    int32_t out_len = 0; \
    uint8_t *out = name(a1, a2, a3, a4, a5, a6, a7, a8, a9, &out_len); \
    return vfg_take_status_response(out); \
}

VG_WRAP_STATUS_4(volvox_grid_add_item, int64_t, grid_id, const uint8_t*, item, int32_t, item_len, int32_t, index)
VG_WRAP_STATUS_1(volvox_grid_destroy_grid, int64_t, id)
VG_WRAP_STATUS_3(volvox_grid_edit_cell, int64_t, grid_id, int32_t, row, int32_t, col)
VG_WRAP_I32_3(volvox_grid_get_cell_checked, int64_t, grid_id, int32_t, row, int32_t, col)
VG_WRAP_I32_1(volvox_grid_get_col, int64_t, id)
VG_WRAP_I32_2(volvox_grid_get_col_is_visible, int64_t, grid_id, int32_t, index)
VG_WRAP_I32_2(volvox_grid_get_col_width, int64_t, grid_id, int32_t, index)
VG_WRAP_I32_1(volvox_grid_get_cols, int64_t, id)
VG_WRAP_I32_2(volvox_grid_get_is_collapsed, int64_t, grid_id, int32_t, index)
VG_WRAP_I32_2(volvox_grid_get_is_subtotal, int64_t, grid_id, int32_t, index)
VG_WRAP_I32_1(volvox_grid_get_row, int64_t, id)
VG_WRAP_I32_2(volvox_grid_get_row_height, int64_t, grid_id, int32_t, index)
VG_WRAP_I32_2(volvox_grid_get_row_is_visible, int64_t, grid_id, int32_t, index)
VG_WRAP_I32_2(volvox_grid_get_row_outline_level, int64_t, grid_id, int32_t, index)
VG_WRAP_I32_1(volvox_grid_get_rows, int64_t, id)
VG_WRAP_STATUS_2(volvox_grid_remove_item, int64_t, grid_id, int32_t, index)
VG_WRAP_STATUS_5(volvox_grid_select, int64_t, grid_id, int32_t, row1, int32_t, col1, int32_t, row2, int32_t, col2)
VG_WRAP_STATUS_4(volvox_grid_set_cell_checked, int64_t, grid_id, int32_t, row, int32_t, col, int32_t, state)
VG_WRAP_STATUS_5(volvox_grid_set_cell_flood, int64_t, grid_id, int32_t, row, int32_t, col, uint32_t, color, float, percent)
VG_WRAP_STATUS_4(volvox_grid_set_col_combo_list, int64_t, grid_id, int32_t, col, const uint8_t*, list, int32_t, list_len)
VG_WRAP_STATUS_3(volvox_grid_set_col_data_type, int64_t, grid_id, int32_t, col, int32_t, data_type)
VG_WRAP_STATUS_3(volvox_grid_set_col_width, int64_t, grid_id, int32_t, col, int32_t, width)
VG_WRAP_STATUS_2(volvox_grid_set_fixed_cols, int64_t, grid_id, int32_t, fixed_cols)
VG_WRAP_STATUS_2(volvox_grid_set_fixed_rows, int64_t, grid_id, int32_t, fixed_rows)
VG_WRAP_STATUS_3(volvox_grid_set_is_collapsed, int64_t, grid_id, int32_t, row, int32_t, collapsed)
VG_WRAP_STATUS_3(volvox_grid_set_is_subtotal, int64_t, grid_id, int32_t, row, int32_t, is_subtotal)
VG_WRAP_STATUS_4(volvox_grid_set_row_data, int64_t, grid_id, int32_t, col, const uint8_t*, data, int32_t, data_len)
VG_WRAP_STATUS_3(volvox_grid_set_row_height, int64_t, grid_id, int32_t, row, int32_t, height)
VG_WRAP_STATUS_2(volvox_grid_set_show_combo_button, int64_t, grid_id, int32_t, mode)
VG_WRAP_STATUS_2(volvox_grid_set_subtotal_position, int64_t, grid_id, int32_t, position)
VG_WRAP_STATUS_5(volvox_grid_set_text_matrix, int64_t, grid_id, int32_t, row, int32_t, col, const uint8_t*, text, int32_t, text_len)

static int32_t volvox_grid_auto_size_compat(
    int64_t grid_id, int32_t col_from, int32_t col_to, int32_t equal, int32_t max_width)
{
    int32_t out_len = 0;
    uint8_t *out = volvox_grid_auto_size(grid_id, col_from, col_to, equal, max_width, &out_len);
    return vfg_take_status_response(out);
}

static int32_t volvox_grid_clear_compat(int64_t grid_id, int32_t scope, int32_t region) {
    int32_t out_len = 0;
    uint8_t *out = volvox_grid_clear(grid_id, scope, region, &out_len);
    return vfg_take_status_response(out);
}

static int32_t volvox_grid_refresh_compat(int64_t id) {
    int32_t out_len = 0;
    uint8_t *out = volvox_grid_refresh(id, &out_len);
    return vfg_take_status_response(out);
}

/* Forward-declare protobuf-based Sort (generated header may be stale). */
uint8_t* volvox_grid_sort_pb(const uint8_t* data, int32_t data_len, int32_t* out_len);
int32_t volvox_grid_set_grid_color_fixed(int64_t id, uint32_t color);

/* Encode a varint into buf, return number of bytes written. */
static int vfg_write_varint(uint8_t *buf, uint64_t v) {
    int n = 0;
    while (v > 0x7F) {
        buf[n++] = (uint8_t)((v & 0x7F) | 0x80);
        v >>= 7;
    }
    buf[n++] = (uint8_t)v;
    return n;
}

/* Sort now uses protobuf-encoded SortRequest (repeated SortColumn). */
static int32_t volvox_grid_sort_compat(int64_t grid_id, int32_t order, int32_t col) {
    /*  SortRequest {
     *    int64 grid_id      = 1;  // varint
     *    repeated SortColumn sort_columns = 2;  // length-delimited
     *      SortColumn { int32 col = 1; SortOrder order = 2; }
     *  }
     */
    uint8_t buf[64];
    int pos = 0;

    /* field 1: grid_id (varint, tag = 0x08) */
    buf[pos++] = 0x08;
    pos += vfg_write_varint(buf + pos, (uint64_t)grid_id);

    /* field 2: SortColumn (length-delimited, tag = 0x12) */
    uint8_t inner[16];
    int ilen = 0;
    /* SortColumn.col (field 1, varint, tag = 0x08) */
    inner[ilen++] = 0x08;
    ilen += vfg_write_varint(inner + ilen, (uint64_t)(uint32_t)col);
    /* SortColumn.order (field 2, varint, tag = 0x10) */
    if (order != 0) {
        inner[ilen++] = 0x10;
        ilen += vfg_write_varint(inner + ilen, (uint64_t)(uint32_t)order);
    }
    buf[pos++] = 0x12;
    pos += vfg_write_varint(buf + pos, (uint64_t)ilen);
    memcpy(buf + pos, inner, ilen);
    pos += ilen;

    int32_t out_len = 0;
    uint8_t *out = volvox_grid_sort_pb(buf, pos, &out_len);
    return vfg_take_status_response(out);
}

static int32_t volvox_grid_subtotal_compat(
    int64_t grid_id,
    int32_t aggregate,
    int32_t group_on_col,
    int32_t aggregate_col,
    const uint8_t* caption,
    int32_t caption_len,
    uint32_t back_color,
    uint32_t fore_color,
    int32_t add_outline)
{
    int32_t out_len = 0;
    uint8_t *out = volvox_grid_subtotal(
        grid_id,
        aggregate,
        group_on_col,
        aggregate_col,
        caption, caption_len,
        back_color,
        fore_color,
        add_outline,
        &out_len);
    return vfg_take_status_response(out);
}

/* Compat wrappers for generated dispatch (simple int set/get properties) */
VG_WRAP_STATUS_2(volvox_grid_set_rows, int64_t, grid_id, int32_t, rows)
VG_WRAP_STATUS_2(volvox_grid_set_cols, int64_t, grid_id, int32_t, cols)
VG_WRAP_STATUS_2(volvox_grid_set_row, int64_t, grid_id, int32_t, row)
VG_WRAP_STATUS_2(volvox_grid_set_col, int64_t, grid_id, int32_t, col)
VG_WRAP_STATUS_2(volvox_grid_set_frozen_rows, int64_t, grid_id, int32_t, value)
VG_WRAP_STATUS_2(volvox_grid_set_frozen_cols, int64_t, grid_id, int32_t, value)
VG_WRAP_STATUS_2(volvox_grid_set_scroll_bars, int64_t, grid_id, int32_t, mode)
VG_WRAP_STATUS_2(volvox_grid_set_top_row, int64_t, grid_id, int32_t, row)
VG_WRAP_STATUS_2(volvox_grid_set_left_col, int64_t, grid_id, int32_t, col)
VG_WRAP_STATUS_2(volvox_grid_set_focus_rect, int64_t, grid_id, int32_t, style)
VG_WRAP_STATUS_2(volvox_grid_set_high_light, int64_t, grid_id, int32_t, style)
VG_WRAP_STATUS_2(volvox_grid_set_editable, int64_t, grid_id, int32_t, mode)
VG_WRAP_STATUS_2(volvox_grid_set_row_sel, int64_t, grid_id, int32_t, row_sel)
VG_WRAP_STATUS_2(volvox_grid_set_col_sel, int64_t, grid_id, int32_t, col_sel)
VG_WRAP_STATUS_2(volvox_grid_set_fill_style, int64_t, grid_id, int32_t, style)
VG_WRAP_STATUS_2(volvox_grid_set_word_wrap, int64_t, grid_id, int32_t, value)
VG_WRAP_STATUS_2(volvox_grid_set_selection_mode, int64_t, grid_id, int32_t, mode)
VG_WRAP_STATUS_2(volvox_grid_set_allow_selection, int64_t, grid_id, int32_t, value)
VG_WRAP_STATUS_2(volvox_grid_set_allow_big_selection, int64_t, grid_id, int32_t, value)
VG_WRAP_STATUS_2(volvox_grid_set_allow_user_resizing, int64_t, grid_id, int32_t, mode)
VG_WRAP_STATUS_2(volvox_grid_set_ellipsis, int64_t, grid_id, int32_t, value)
VG_WRAP_STATUS_2(volvox_grid_set_extend_last_col, int64_t, grid_id, int32_t, value)
VG_WRAP_STATUS_2(volvox_grid_set_merge_cells, int64_t, grid_id, int32_t, mode)
VG_WRAP_STATUS_2(volvox_grid_set_outline_bar, int64_t, grid_id, int32_t, style)
VG_WRAP_STATUS_2(volvox_grid_set_outline_col, int64_t, grid_id, int32_t, col)
VG_WRAP_STATUS_3(volvox_grid_set_merge_row, int64_t, grid_id, int32_t, row, int32_t, merge)
VG_WRAP_STATUS_3(volvox_grid_set_merge_col, int64_t, grid_id, int32_t, col, int32_t, merge)
VG_WRAP_STATUS_3(volvox_grid_set_row_outline_level, int64_t, grid_id, int32_t, row, int32_t, level)
VG_WRAP_STATUS_3(volvox_grid_set_col_alignment, int64_t, grid_id, int32_t, col, int32_t, alignment)
VG_WRAP_STATUS_3(volvox_grid_set_fixed_alignment, int64_t, grid_id, int32_t, col, int32_t, alignment)
VG_WRAP_STATUS_3(volvox_grid_set_row_hidden, int64_t, grid_id, int32_t, row, int32_t, hidden)
VG_WRAP_STATUS_3(volvox_grid_set_col_hidden, int64_t, grid_id, int32_t, col, int32_t, hidden)
VG_WRAP_I32_1(volvox_grid_get_top_row, int64_t, id)
VG_WRAP_I32_1(volvox_grid_get_left_col, int64_t, id)

static int32_t volvox_grid_set_redraw_compat(int64_t grid_id, int32_t value) {
    int32_t out_len = 0;
    uint8_t *out = volvox_grid_set_redraw(grid_id, value, &out_len);
    return vfg_take_status_response(out);
}

#define volvox_grid_add_item volvox_grid_add_item_compat
#define volvox_grid_auto_size volvox_grid_auto_size_compat
#define volvox_grid_clear volvox_grid_clear_compat
#define volvox_grid_destroy_grid volvox_grid_destroy_grid_compat
#define volvox_grid_edit_cell volvox_grid_edit_cell_compat
#define volvox_grid_get_cell_checked volvox_grid_get_cell_checked_compat
#define volvox_grid_get_col volvox_grid_get_col_compat
#define volvox_grid_get_col_is_visible volvox_grid_get_col_is_visible_compat
#define volvox_grid_get_col_width volvox_grid_get_col_width_compat
#define volvox_grid_get_cols volvox_grid_get_cols_compat
#define volvox_grid_get_is_collapsed volvox_grid_get_is_collapsed_compat
#define volvox_grid_get_is_subtotal volvox_grid_get_is_subtotal_compat
#define volvox_grid_get_left_col volvox_grid_get_left_col_compat
#define volvox_grid_get_row volvox_grid_get_row_compat
#define volvox_grid_get_row_height volvox_grid_get_row_height_compat
#define volvox_grid_get_row_is_visible volvox_grid_get_row_is_visible_compat
#define volvox_grid_get_row_outline_level volvox_grid_get_row_outline_level_compat
#define volvox_grid_get_rows volvox_grid_get_rows_compat
#define volvox_grid_get_top_row volvox_grid_get_top_row_compat
#define volvox_grid_refresh volvox_grid_refresh_compat
#define volvox_grid_remove_item volvox_grid_remove_item_compat
#define volvox_grid_select volvox_grid_select_compat
#define volvox_grid_set_allow_big_selection volvox_grid_set_allow_big_selection_compat
#define volvox_grid_set_allow_selection volvox_grid_set_allow_selection_compat
#define volvox_grid_set_allow_user_resizing volvox_grid_set_allow_user_resizing_compat
#define volvox_grid_set_cell_checked volvox_grid_set_cell_checked_compat
#define volvox_grid_set_cell_flood volvox_grid_set_cell_flood_compat
#define volvox_grid_set_col volvox_grid_set_col_compat
#define volvox_grid_set_col_alignment volvox_grid_set_col_alignment_compat
#define volvox_grid_set_col_combo_list volvox_grid_set_col_combo_list_compat
#define volvox_grid_set_col_data_type volvox_grid_set_col_data_type_compat
#define volvox_grid_set_col_hidden volvox_grid_set_col_hidden_compat
#define volvox_grid_set_col_sel volvox_grid_set_col_sel_compat
#define volvox_grid_set_col_width volvox_grid_set_col_width_compat
#define volvox_grid_set_cols volvox_grid_set_cols_compat
#define volvox_grid_set_editable volvox_grid_set_editable_compat
#define volvox_grid_set_ellipsis volvox_grid_set_ellipsis_compat
#define volvox_grid_set_extend_last_col volvox_grid_set_extend_last_col_compat
#define volvox_grid_set_fill_style volvox_grid_set_fill_style_compat
#define volvox_grid_set_fixed_alignment volvox_grid_set_fixed_alignment_compat
#define volvox_grid_set_fixed_cols volvox_grid_set_fixed_cols_compat
#define volvox_grid_set_fixed_rows volvox_grid_set_fixed_rows_compat
#define volvox_grid_set_focus_rect volvox_grid_set_focus_rect_compat
#define volvox_grid_set_frozen_cols volvox_grid_set_frozen_cols_compat
#define volvox_grid_set_frozen_rows volvox_grid_set_frozen_rows_compat
#define volvox_grid_set_high_light volvox_grid_set_high_light_compat
#define volvox_grid_set_is_collapsed volvox_grid_set_is_collapsed_compat
#define volvox_grid_set_is_subtotal volvox_grid_set_is_subtotal_compat
#define volvox_grid_set_left_col volvox_grid_set_left_col_compat
#define volvox_grid_set_merge_cells volvox_grid_set_merge_cells_compat
#define volvox_grid_set_merge_col volvox_grid_set_merge_col_compat
#define volvox_grid_set_merge_row volvox_grid_set_merge_row_compat
#define volvox_grid_set_outline_bar volvox_grid_set_outline_bar_compat
#define volvox_grid_set_outline_col volvox_grid_set_outline_col_compat
#define volvox_grid_set_redraw volvox_grid_set_redraw_compat
#define volvox_grid_set_row volvox_grid_set_row_compat
#define volvox_grid_set_row_data volvox_grid_set_row_data_compat
#define volvox_grid_set_row_height volvox_grid_set_row_height_compat
#define volvox_grid_set_row_hidden volvox_grid_set_row_hidden_compat
#define volvox_grid_set_row_outline_level volvox_grid_set_row_outline_level_compat
#define volvox_grid_set_row_sel volvox_grid_set_row_sel_compat
#define volvox_grid_set_rows volvox_grid_set_rows_compat
#define volvox_grid_set_scroll_bars volvox_grid_set_scroll_bars_compat
#define volvox_grid_set_selection_mode volvox_grid_set_selection_mode_compat
#define volvox_grid_set_show_combo_button volvox_grid_set_show_combo_button_compat
#define volvox_grid_set_subtotal_position volvox_grid_set_subtotal_position_compat
#define volvox_grid_set_text_matrix volvox_grid_set_text_matrix_compat
#define volvox_grid_set_top_row volvox_grid_set_top_row_compat
#define volvox_grid_set_word_wrap volvox_grid_set_word_wrap_compat
#define volvox_grid_sort volvox_grid_sort_compat
#define volvox_grid_subtotal volvox_grid_subtotal_compat

/* DISPIDs, name table, and simple dispatch cases are now generated.
 * See ../include/volvoxgrid_activex.h (produced by protoc-gen-synurang-ffi). */

/* Constant aliases for backward compatibility in this file.
 * The generated header uses the full property name (e.g., BACKCOLORALTERNATE). */
#define DISPID_VG_BACKCOLORALT    DISPID_VG_BACKCOLORALTERNATE
#define DISPID_VG_SUBTOTALPOS     DISPID_VG_SUBTOTALPOSITION

/* Compat DISPIDs for members not yet emitted by the generated
 * ActiveX dispatch header. Keep values outside generated range. */
#define DISPID_VG_FINDROW_COMPAT      10001
#define DISPID_VG_FINDROWREGEX_COMPAT 10002

/* ════════════════════════════════════════════════════════════════ */
/* VolvoxGrid COM Object                                           */
/* ════════════════════════════════════════════════════════════════ */

/* Forward vtable declarations */
static IDispatchVtbl   g_VFGDispatchVtbl;
static IViewObjectVtbl g_VFGViewObjectVtbl;

typedef struct {
    IDispatchVtbl   *lpVtblDispatch;
    IViewObjectVtbl *lpVtblViewObject;
    LONG cRef;
    int64_t grid_id;   /* Active grid handle (-1 = none) */
    int32_t fixed_rows_cached;
    int32_t fixed_cols_cached;
    int32_t show_combo_button_explicit;
    struct FloodColorEntry *flood_colors;
} VolvoxGridObject;

typedef struct FloodColorEntry {
    int32_t row;
    int32_t col;
    uint32_t color_argb;
    struct FloodColorEntry *next;
} FloodColorEntry;

static void vfg_set_flood_color_cached(
    VolvoxGridObject *obj, int32_t row, int32_t col, uint32_t color_argb);
static uint32_t vfg_get_flood_color_cached(
    VolvoxGridObject *obj, int32_t row, int32_t col);
static void vfg_clear_flood_color_cache(VolvoxGridObject *obj);

/* Offset macro for secondary interface */
#define VIEWOBJECT_OFFSET offsetof(VolvoxGridObject, lpVtblViewObject)
#define OBJ_FROM_VIEWOBJECT(pv) \
    ((VolvoxGridObject *)((char *)(pv) - VIEWOBJECT_OFFSET))

/* ── IUnknown ─────────────────────────────────────────────────── */

static HRESULT STDMETHODCALLTYPE VFG_QueryInterface(
    IDispatch *This, REFIID riid, void **ppv)
{
    VolvoxGridObject *obj = (VolvoxGridObject *)This;
    if (IsEqualIID(riid, &IID_IUnknown) ||
        IsEqualIID(riid, &IID_IDispatch) ||
        IsEqualIID(riid, &IID_IVolvoxGrid))
    {
        *ppv = &obj->lpVtblDispatch;
        InterlockedIncrement(&obj->cRef);
        return S_OK;
    }
    if (IsEqualIID(riid, &IID_IViewObject)) {
        *ppv = &obj->lpVtblViewObject;
        InterlockedIncrement(&obj->cRef);
        return S_OK;
    }
    *ppv = NULL;
    return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE VFG_AddRef(IDispatch *This) {
    VolvoxGridObject *obj = (VolvoxGridObject *)This;
    return InterlockedIncrement(&obj->cRef);
}

static ULONG STDMETHODCALLTYPE VFG_Release(IDispatch *This) {
    VolvoxGridObject *obj = (VolvoxGridObject *)This;
    LONG c = InterlockedDecrement(&obj->cRef);
    if (c == 0) {
        vfg_clear_flood_color_cache(obj);
        if (obj->grid_id >= 0) {
            volvox_grid_destroy_grid(obj->grid_id);
        }
        HeapFree(GetProcessHeap(), 0, obj);
    }
    return c;
}

/* ── IDispatch ────────────────────────────────────────────────── */

static HRESULT STDMETHODCALLTYPE VFG_GetTypeInfoCount(
    IDispatch *This, UINT *pctinfo)
{
    (void)This;
    *pctinfo = 0;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_GetTypeInfo(
    IDispatch *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo)
{
    (void)This; (void)iTInfo; (void)lcid;
    *ppTInfo = NULL;
    return DISP_E_BADINDEX;
}

static HRESULT STDMETHODCALLTYPE VFG_GetIDsOfNames(
    IDispatch *This, REFIID riid, LPOLESTR *rgszNames,
    UINT cNames, LCID lcid, DISPID *rgDispId)
{
    (void)This; (void)riid; (void)lcid;

    HRESULT hrFinal = S_OK;
    for (UINT i = 0; i < cNames; i++) {
        BOOL found = FALSE;
        for (const VG_NameEntry *e = vg_activex_names; e->name; e++) {
            if (_wcsicmp(rgszNames[i], e->name) == 0) {
                rgDispId[i] = e->id;
                found = TRUE;
                break;
            }
        }
        if (!found && _wcsicmp(rgszNames[i], L"FindRow") == 0) {
            rgDispId[i] = DISPID_VG_FINDROW_COMPAT;
            found = TRUE;
        }
        if (!found && _wcsicmp(rgszNames[i], L"FindRowRegex") == 0) {
            rgDispId[i] = DISPID_VG_FINDROWREGEX_COMPAT;
            found = TRUE;
        }
        if (!found) {
            rgDispId[i] = DISPID_UNKNOWN;
            hrFinal = DISP_E_UNKNOWNNAME;
        }
    }
    return hrFinal;
}

/* ── Helpers ──────────────────────────────────────────────────── */

/* Convert BSTR -> UTF-8 bytes (caller must free).  *out_len = byte length. */
static char *bstr_to_utf8(BSTR bstr, int *out_len) {
    if (!bstr) { *out_len = 0; return NULL; }
    int wlen = SysStringLen(bstr);
    if (wlen == 0) { *out_len = 0; return NULL; }
    int needed = WideCharToMultiByte(CP_UTF8, 0, bstr, wlen, NULL, 0, NULL, NULL);
    char *buf = (char *)HeapAlloc(GetProcessHeap(), 0, needed + 1);
    if (!buf) { *out_len = 0; return NULL; }
    WideCharToMultiByte(CP_UTF8, 0, bstr, wlen, buf, needed, NULL, NULL);
    buf[needed] = '\0';
    *out_len = needed;
    return buf;
}

/* Convert UTF-8 bytes -> BSTR. */
static BSTR utf8_to_bstr(const char *utf8, int len) {
    if (!utf8 || len <= 0) return SysAllocString(L"");
    int wlen = MultiByteToWideChar(CP_UTF8, 0, utf8, len, NULL, 0);
    if (wlen <= 0) return SysAllocString(L"");
    BSTR bstr = SysAllocStringLen(NULL, wlen);
    if (!bstr) return NULL;
    MultiByteToWideChar(CP_UTF8, 0, utf8, len, bstr, wlen);
    return bstr;
}

/* Append bytes to a growable UTF-8 buffer. */
static int utf8_append_bytes(char **buf, int *len, int *cap, const char *src, int n) {
    if (!buf || !len || !cap || !src || n <= 0) return 1;
    if (*len + n + 1 > *cap) {
        int new_cap = (*cap > 0) ? *cap : 128;
        while (new_cap < (*len + n + 1)) {
            new_cap *= 2;
        }
        char *new_buf = *buf
            ? (char *)HeapReAlloc(GetProcessHeap(), 0, *buf, new_cap)
            : (char *)HeapAlloc(GetProcessHeap(), 0, new_cap);
        if (!new_buf) return 0;
        *buf = new_buf;
        *cap = new_cap;
    }
    memcpy(*buf + *len, src, (size_t)n);
    *len += n;
    (*buf)[*len] = '\0';
    return 1;
}

/* Clamp and normalize a cell rectangle to the current grid bounds. */
static void vfg_normalize_cell_rect(
    int64_t gid, int32_t *row1, int32_t *col1, int32_t *row2, int32_t *col2)
{
    int32_t rows = volvox_grid_get_rows(gid);
    int32_t cols = volvox_grid_get_cols(gid);
    if (rows <= 0) {
        *row1 = *row2 = 0;
    } else {
        if (*row1 < 0) *row1 = 0;
        if (*row1 >= rows) *row1 = rows - 1;
        if (*row2 < 0) *row2 = 0;
        if (*row2 >= rows) *row2 = rows - 1;
        if (*row1 > *row2) {
            int32_t t = *row1;
            *row1 = *row2;
            *row2 = t;
        }
    }

    if (cols <= 0) {
        *col1 = *col2 = 0;
    } else {
        if (*col1 < 0) *col1 = 0;
        if (*col1 >= cols) *col1 = cols - 1;
        if (*col2 < 0) *col2 = 0;
        if (*col2 >= cols) *col2 = cols - 1;
        if (*col1 > *col2) {
            int32_t t = *col1;
            *col1 = *col2;
            *col2 = t;
        }
    }
}

/* Build Cell(0, r1,c1,r2,c2) text payload:
 * columns separated by TAB, rows separated by CRLF. */
static BSTR vfg_get_cell_text_range(
    int64_t gid, int32_t row1, int32_t col1, int32_t row2, int32_t col2)
{
    char *buf = NULL;
    int len = 0, cap = 0;

    for (int32_t r = row1; r <= row2; ++r) {
        for (int32_t c = col1; c <= col2; ++c) {
            int32_t cell_len = 0;
            uint8_t *cell = volvox_grid_get_text_matrix(gid, r, c, &cell_len);
            if (cell && cell_len > 0) {
                if (!utf8_append_bytes(&buf, &len, &cap, (const char *)cell, cell_len)) {
                    volvox_grid_free(cell, cell_len);
                    if (buf) HeapFree(GetProcessHeap(), 0, buf);
                    return NULL;
                }
            }
            if (cell) volvox_grid_free(cell, cell_len);

            if (c < col2) {
                if (!utf8_append_bytes(&buf, &len, &cap, "\t", 1)) {
                    if (buf) HeapFree(GetProcessHeap(), 0, buf);
                    return NULL;
                }
            }
        }
        if (r < row2) {
            if (!utf8_append_bytes(&buf, &len, &cap, "\r\n", 2)) {
                if (buf) HeapFree(GetProcessHeap(), 0, buf);
                return NULL;
            }
        }
    }

    BSTR out = utf8_to_bstr(buf, len);
    if (buf) HeapFree(GetProcessHeap(), 0, buf);
    return out;
}

/* Apply Cell(0, r1,c1,r2,c2) text payload with TAB/CRLF separators. */
static void vfg_set_cell_text_range(
    int64_t gid, int32_t row1, int32_t col1, int32_t row2, int32_t col2,
    const char *utf8, int utf8len)
{
    const char *p = utf8 ? utf8 : "";
    const char *end = utf8 ? (utf8 + utf8len) : p;

    for (int32_t r = row1; r <= row2; ++r) {
        for (int32_t c = col1; c <= col2; ++c) {
            const char *start = p;
            while (p < end && *p != '\t' && *p != '\r' && *p != '\n') {
                p++;
            }
            volvox_grid_set_text_matrix(
                gid, r, c, (const uint8_t *)start, (int32_t)(p - start));

            if (c < col2) {
                if (p < end && *p == '\t') {
                    p++;
                } else {
                    for (int32_t cc = c + 1; cc <= col2; ++cc) {
                        volvox_grid_set_text_matrix(gid, r, cc, (const uint8_t *)"", 0);
                    }
                    c = col2;
                }
            } else {
                while (p < end && *p != '\r' && *p != '\n') {
                    p++;
                }
            }
        }

        if (p < end && *p == '\r') {
            p++;
            if (p < end && *p == '\n') p++;
        } else if (p < end && *p == '\n') {
            p++;
        }
    }
}

/* Coerce a VARIANT to VT_I4 */
static HRESULT variant_to_i4(VARIANT *pv, int32_t *out) {
    if (V_VT(pv) == VT_I4) { *out = V_I4(pv); return S_OK; }
    VARIANT tmp;
    VariantInit(&tmp);
    HRESULT hr = VariantChangeType(&tmp, pv, 0, VT_I4);
    if (SUCCEEDED(hr)) *out = V_I4(&tmp);
    VariantClear(&tmp);
    return hr;
}

static int variant_is_missing(const VARIANT *pv) {
    return pv && V_VT(pv) == VT_ERROR && V_ERROR(pv) == DISP_E_PARAMNOTFOUND;
}

/* Coerce a VARIANT to VT_BSTR.  Returns BSTR (borrowed or from *tmp).
 * Caller must VariantClear(tmp) after done with the returned BSTR. */
static BSTR variant_to_bstr(VARIANT *pv, VARIANT *tmp) {
    VariantInit(tmp);
    if (V_VT(pv) == VT_BSTR) return V_BSTR(pv);
    if (SUCCEEDED(VariantChangeType(tmp, pv, 0, VT_BSTR)))
        return V_BSTR(tmp);
    return NULL;
}

/* Coerce a VARIANT to uint32_t (OLE_COLOR) */
static HRESULT variant_to_u32(VARIANT *pv, uint32_t *out) {
    VARIANT tmp;
    HRESULT hr;

    if (!pv || !out) return E_POINTER;

    switch (V_VT(pv)) {
    case VT_UI4:
    case VT_UINT:
        *out = V_UI4(pv);
        return S_OK;
    case VT_I4:
    case VT_INT: {
        int32_t v = 0;
        hr = variant_to_i4(pv, &v);
        if (FAILED(hr)) return hr;
        if (v < 0) {
            uint32_t raw = (uint32_t)v;
            if ((raw & 0xFF000000u) == 0x80000000u) {
                *out = raw;
                return S_OK;
            }
            return DISP_E_OVERFLOW;
        }
        *out = (uint32_t)v;
        return S_OK;
    }
    case VT_I2:
    case VT_I1: {
        int32_t v = 0;
        hr = variant_to_i4(pv, &v);
        if (FAILED(hr)) return hr;
        if (v < 0) return DISP_E_OVERFLOW;
        *out = (uint32_t)v;
        return S_OK;
    }
    default:
        break;
    }

    VariantInit(&tmp);
    hr = VariantChangeType(&tmp, pv, 0, VT_UI4);
    if (SUCCEEDED(hr)) {
        *out = V_UI4(&tmp);
    }
    VariantClear(&tmp);
    return hr;
}

/*
 * OLE_COLOR (0x00BBGGRR) <-> engine ARGB (0xAARRGGBB) conversion.
 * VBScript / COM controls pass colours in OLE_COLOR byte order.
 * Our engine stores colours as 0xAARRGGBB with 0xFF = opaque.
 */
static uint32_t olecolor_to_argb(uint32_t ole) {
    uint8_t r = (uint8_t)(ole);
    uint8_t g = (uint8_t)(ole >> 8);
    uint8_t b = (uint8_t)(ole >> 16);
    return 0xFF000000u | ((uint32_t)r << 16) | ((uint32_t)g << 8) | b;
}

static uint32_t argb_to_olecolor(uint32_t argb) {
    uint8_t r = (uint8_t)(argb >> 16);
    uint8_t g = (uint8_t)(argb >> 8);
    uint8_t b = (uint8_t)(argb);
    return ((uint32_t)b << 16) | ((uint32_t)g << 8) | r;
}

static void vfg_set_flood_color_cached(
    VolvoxGridObject *obj, int32_t row, int32_t col, uint32_t color_argb)
{
    FloodColorEntry *cur = obj->flood_colors;
    while (cur) {
        if (cur->row == row && cur->col == col) {
            cur->color_argb = color_argb;
            return;
        }
        cur = cur->next;
    }

    FloodColorEntry *node =
        (FloodColorEntry *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*node));
    if (!node) return;
    node->row = row;
    node->col = col;
    node->color_argb = color_argb;
    node->next = obj->flood_colors;
    obj->flood_colors = node;
}

static uint32_t vfg_get_flood_color_cached(VolvoxGridObject *obj, int32_t row, int32_t col) {
    FloodColorEntry *cur = obj->flood_colors;
    while (cur) {
        if (cur->row == row && cur->col == col) {
            return cur->color_argb;
        }
        cur = cur->next;
    }
    return 0;
}

static void vfg_clear_flood_color_cache(VolvoxGridObject *obj) {
    FloodColorEntry *cur = obj->flood_colors;
    while (cur) {
        FloodColorEntry *next = cur->next;
        HeapFree(GetProcessHeap(), 0, cur);
        cur = next;
    }
    obj->flood_colors = NULL;
}

/* Coerce a VARIANT to float */
static HRESULT variant_to_float(VARIANT *pv, float *out) {
    if (V_VT(pv) == VT_R4) { *out = V_R4(pv); return S_OK; }
    if (V_VT(pv) == VT_R8) { *out = (float)V_R8(pv); return S_OK; }
    VARIANT tmp;
    VariantInit(&tmp);
    HRESULT hr = VariantChangeType(&tmp, pv, 0, VT_R4);
    if (SUCCEEDED(hr)) *out = V_R4(&tmp);
    VariantClear(&tmp);
    return hr;
}

/* ActiveX ColDataType constants -> engine ColDataType enum. */
static int32_t activex_col_data_type_to_engine(int32_t dt) {
    switch (dt) {
        case 11: /* flexDTBoolean */
            return 3; /* COL_DATA_BOOLEAN */
        case 7:  /* flexDTDate */
            return 2; /* COL_DATA_DATE */
        case 6:  /* flexDTCurrency */
            return 4; /* COL_DATA_CURRENCY */
        case 2:  /* flexDTShort */
        case 3:  /* flexDTLong */
        case 4:  /* flexDTSingle */
        case 5:  /* flexDTDouble */
        case 14: /* flexDTDecimal */
        case 20: /* flexDTLong8 */
            return 1; /* COL_DATA_NUMBER */
        default:
            return 0; /* COL_DATA_STRING */
    }
}

/* CellChecked constants -> engine CheckedState enum. */
static int32_t activex_checked_to_engine(int32_t state) {
    switch (state) {
        case 1: /* FlexChecked */
        case 3: /* FlexTSChecked */
            return 1; /* CHECKED_CHECKED */
        case 2: /* FlexUnchecked */
        case 5: /* FlexTSUnchecked */
            /* Keep explicit unchecked distinct from "no checkbox" so
             * non-boolean columns can still render an empty checkbox. */
            return 3; /* internal explicit-unchecked marker */
        case 4: /* FlexTSGrayed */
            return 2; /* CHECKED_GRAYED */
        case 0: /* FlexNoCheckbox */
        default:
            return 0; /* CHECKED_UNCHECKED */
    }
}

/* Engine CheckedState enum -> CellChecked constants. */
static int32_t engine_checked_to_activex(int32_t engine_state) {
    switch (engine_state) {
        case 1:
            return 1; /* FlexChecked */
        case 2:
            return 4; /* FlexTSGrayed */
        case 3:
            return 2; /* FlexUnchecked */
        case 0:
        default:
            return 0; /* FlexNoCheckbox */
    }
}

/* IsCollapsed settings -> engine collapsed flag. */
static int32_t activex_outline_state_to_engine_collapsed(int32_t state) {
    return state != 0 ? 1 : 0;
}

/* Engine collapsed flag -> IsCollapsed setting. */
static int32_t engine_collapsed_to_activex_outline_state(int32_t collapsed) {
    return collapsed ? 2 /* FlexOutlineCollapsed */ : 0 /* FlexOutlineExpanded */;
}

/* ShowComboButton -> engine mode mapping.
 * ActiveX: 0=never, 1=current/focus, 2=always.
 * Engine: 0=never, 1=always, 2=editing, 3=current/focus(compat). */
static int32_t activex_show_combo_to_engine(int32_t mode) {
    switch (mode) {
        case 0: return 0; /* never */
        case 1: return 3; /* current/focus */
        case 2: return 1; /* always */
        default: return mode;
    }
}

/* RowHidden/ColHidden are boolean-style properties:
 * hidden = -1 (True), visible = 0 (False).
 * Engine exposes visibility as 1/0, so invert + normalize. */
static int32_t vg_get_row_hidden(int64_t gid, int32_t row) {
    int32_t visible = volvox_grid_get_row_is_visible(gid, row);
    if (visible < 0) return 0;
    return visible ? 0 : -1;
}

static int32_t vg_get_col_hidden(int64_t gid, int32_t col) {
    int32_t visible = volvox_grid_get_col_is_visible(gid, col);
    if (visible < 0) return 0;
    return visible ? 0 : -1;
}

/* IsCollapsed(row) accepts any row in a node's branch.
 * If the row is not itself a subtotal node, apply to its parent node. */
static int32_t vfg_resolve_outline_node_row(int64_t gid, int32_t row) {
    int32_t rows = volvox_grid_get_rows(gid);
    if (rows <= 0) return row;
    if (row < 0) row = 0;
    if (row >= rows) row = rows - 1;

    if (volvox_grid_get_is_subtotal(gid, row)) {
        return row;
    }

    {
        int32_t level = volvox_grid_get_row_outline_level(gid, row);

        /* Subtotal-above trees: parent subtotal is typically above. */
        for (int32_t r = row - 1; r >= 0; --r) {
            int32_t rl = volvox_grid_get_row_outline_level(gid, r);
            if (volvox_grid_get_is_subtotal(gid, r) && rl > level) {
                return r;
            }
            if (rl < level) break;
        }

        /* Subtotal-below trees: parent subtotal may be below. */
        for (int32_t r = row + 1; r < rows; ++r) {
            int32_t rl = volvox_grid_get_row_outline_level(gid, r);
            if (volvox_grid_get_is_subtotal(gid, r) && rl > level) {
                return r;
            }
            if (rl < level) break;
        }
    }

    /* No parent node found; keep original row as conservative fallback. */
    return row;
}

/* ── Macros for common IDispatch property patterns ────────────── */

/* Simple int get/put via generated native API (set_xxx(gid, val) / get_xxx(gid)) */
#define CASE_INT_GETPUT(DISPID_NAME, set_fn, get_fn) \
    case DISPID_NAME: \
        if (wFlags & DISPATCH_PROPERTYGET) { \
            if (!pVarResult) return E_POINTER; \
            V_VT(pVarResult) = VT_I4; \
            V_I4(pVarResult) = get_fn(gid); \
            return S_OK; \
        } \
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) { \
            int32_t val = 0; variant_to_i4(NAMED_ARG(0), &val); \
            set_fn(gid, val); \
            return S_OK; \
        } \
        break;

/* Simple int put-only */
#define CASE_INT_PUT(DISPID_NAME, set_fn) \
    case DISPID_NAME: \
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) { \
            int32_t val = 0; variant_to_i4(NAMED_ARG(0), &val); \
            set_fn(gid, val); \
            return S_OK; \
        } \
        break;

/* Color get/put (OLE_COLOR <-> ARGB conversion) */
#define CASE_COLOR_GETPUT(DISPID_NAME, set_fn, get_fn) \
    case DISPID_NAME: \
        if (wFlags & DISPATCH_PROPERTYGET) { \
            if (!pVarResult) return E_POINTER; \
            V_VT(pVarResult) = VT_I4; \
            V_I4(pVarResult) = (int32_t)argb_to_olecolor(get_fn(gid)); \
            return S_OK; \
        } \
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) { \
            uint32_t val = 0; \
            HRESULT hr = variant_to_u32(NAMED_ARG(0), &val); \
            if (FAILED(hr)) return hr; \
            set_fn(gid, olecolor_to_argb(val)); \
            return S_OK; \
        } \
        break;

/* Indexed int property: PropName(index) = val / val = PropName(index) */
#define CASE_INDEXED_INT_GETPUT(DISPID_NAME, set_fn, get_fn) \
    case DISPID_NAME: \
        if (wFlags & DISPATCH_PROPERTYGET) { \
            if (!pVarResult) return E_POINTER; \
            int32_t idx = 0; \
            if (pDispParams->cArgs >= 1) variant_to_i4(&pDispParams->rgvarg[0], &idx); \
            V_VT(pVarResult) = VT_I4; \
            V_I4(pVarResult) = get_fn(gid, idx); \
            return S_OK; \
        } \
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) { \
            int32_t idx = 0, val = 0; \
            if (pDispParams->cArgs >= 2) { \
                variant_to_i4(&pDispParams->rgvarg[1], &idx); \
                variant_to_i4(&pDispParams->rgvarg[0], &val); \
            } \
            set_fn(gid, idx, val); \
            return S_OK; \
        } \
        break;

/* Indexed int property: put-only with 2 args (index, value) */
#define CASE_INDEXED_INT_PUT(DISPID_NAME, set_fn) \
    case DISPID_NAME: \
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) { \
            int32_t idx = 0, val = 0; \
            if (pDispParams->cArgs >= 2) { \
                variant_to_i4(&pDispParams->rgvarg[1], &idx); \
                variant_to_i4(&pDispParams->rgvarg[0], &val); \
            } \
            set_fn(gid, idx, val); \
            return S_OK; \
        } \
        break;

/* ── VFG_Invoke ───────────────────────────────────────────────── */

static HRESULT STDMETHODCALLTYPE VFG_Invoke(
    IDispatch *This, DISPID dispIdMember, REFIID riid, LCID lcid,
    WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult,
    EXCEPINFO *pExcepInfo, UINT *puArgErr)
{
    (void)riid; (void)lcid; (void)pExcepInfo; (void)puArgErr;
    VolvoxGridObject *obj = (VolvoxGridObject *)This;
    int64_t gid = obj->grid_id;

    /* IDispatch args are in reverse order in rgvarg[] */
#define ARG(i) (&pDispParams->rgvarg[pDispParams->cArgs - 1 - (i)])
#define NAMED_ARG(i) (&pDispParams->rgvarg[i])

    switch (dispIdMember) {

    /* ══════════════════════════════════════════════════════════ */
    /* Generated dispatch cases (simple int/indexed properties)   */
    /* ══════════════════════════════════════════════════════════ */
#define VG_DISPATCH_IMPL
#include "../include/volvoxgrid_activex.h"
#undef VG_DISPATCH_IMPL

    /* ══════════════════════════════════════════════════════════ */
    /* Custom dispatch cases (hand-written)                       */
    /* ══════════════════════════════════════════════════════════ */

    /* FixedRows / FixedCols getters are served from OCX-side cache. */
    case DISPID_VG_FIXEDROWS:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t rows = volvox_grid_get_rows(gid);
            int32_t v = obj->fixed_rows_cached;
            if (rows > 0) {
                if (v < 0) v = 0;
                if (v > rows) v = rows;
            } else {
                v = 0;
            }
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = v;
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t val = 0;
            variant_to_i4(NAMED_ARG(0), &val);
            volvox_grid_set_fixed_rows(gid, val);
            {
                int32_t rows = volvox_grid_get_rows(gid);
                int32_t v = val;
                if (rows > 0) {
                    if (v < 0) v = 0;
                    if (v > rows) v = rows;
                } else {
                    v = 0;
                }
                obj->fixed_rows_cached = v;
            }
            return S_OK;
        }
        break;

    case DISPID_VG_FIXEDCOLS:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t cols = volvox_grid_get_cols(gid);
            int32_t v = obj->fixed_cols_cached;
            if (cols > 0) {
                if (v < 0) v = 0;
                if (v > cols) v = cols;
            } else {
                v = 0;
            }
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = v;
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t val = 0;
            variant_to_i4(NAMED_ARG(0), &val);
            volvox_grid_set_fixed_cols(gid, val);
            {
                int32_t cols = volvox_grid_get_cols(gid);
                int32_t v = val;
                if (cols > 0) {
                    if (v < 0) v = 0;
                    if (v > cols) v = cols;
                } else {
                    v = 0;
                }
                obj->fixed_cols_cached = v;
            }
            return S_OK;
        }
        break;

    /* ── TextMatrix(row, col) ────────────────────────────────── */
    case DISPID_VG_TEXTMATRIX:
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t row = 0, col = 0;
            BSTR text = NULL;
            VARIANT vtmp; VariantInit(&vtmp);
            if (pDispParams->cArgs >= 3) {
                variant_to_i4(&pDispParams->rgvarg[2], &row);
                variant_to_i4(&pDispParams->rgvarg[1], &col);
                text = variant_to_bstr(&pDispParams->rgvarg[0], &vtmp);
            }
            if (text) {
                int utf8len = 0;
                char *utf8 = bstr_to_utf8(text, &utf8len);
                if (utf8) {
                    volvox_grid_set_text_matrix(gid, row, col,
                        (const uint8_t *)utf8, utf8len);
                    HeapFree(GetProcessHeap(), 0, utf8);
                }
            }
            VariantClear(&vtmp);
            return S_OK;
        }
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            int32_t row = 0, col = 0;
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(&pDispParams->rgvarg[1], &row);
                variant_to_i4(&pDispParams->rgvarg[0], &col);
            }
            int32_t out_len = 0;
            uint8_t *utf8 = volvox_grid_get_text_matrix(gid, row, col, &out_len);
            if (utf8 && out_len > 0) {
                int wlen = MultiByteToWideChar(CP_UTF8, 0, (char*)utf8, out_len, NULL, 0);
                BSTR bstr = SysAllocStringLen(NULL, wlen);
                if (bstr) {
                    MultiByteToWideChar(CP_UTF8, 0, (char*)utf8, out_len, bstr, wlen);
                    V_VT(pVarResult) = VT_BSTR;
                    V_BSTR(pVarResult) = bstr;
                }
                volvox_grid_free(utf8, out_len);
            } else {
                V_VT(pVarResult) = VT_BSTR;
                V_BSTR(pVarResult) = SysAllocString(L"");
            }
            return S_OK;
        }
        break;

    /* ── RowHeight(row) / ColWidth(col) — indexed, twips ←→ pixels ── */
    /* The flex grid API uses twips (1 inch = 1440 twips).              */
    /* At 96 DPI: 1 pixel = 15 twips.  We convert at the OCX boundary. */
    /* Special value -1 means "reset to default" — pass through as-is. */

    case DISPID_VG_ROWHEIGHT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            int32_t idx = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(&pDispParams->rgvarg[0], &idx);
            int32_t px = volvox_grid_get_row_height(gid, idx);
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = px * 15;  /* pixels → twips */
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t idx = 0, val = 0;
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(&pDispParams->rgvarg[1], &idx);
                variant_to_i4(&pDispParams->rgvarg[0], &val);
            }
            int32_t px = (val == -1) ? -1 : (val + 7) / 15;  /* twips → pixels, round */
            volvox_grid_set_row_height(gid, idx, px);
            return S_OK;
        }
        break;

    case DISPID_VG_COLWIDTH:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            int32_t idx = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(&pDispParams->rgvarg[0], &idx);
            int32_t px = volvox_grid_get_col_width(gid, idx);
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = px * 15;  /* pixels → twips */
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t idx = 0, val = 0;
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(&pDispParams->rgvarg[1], &idx);
                variant_to_i4(&pDispParams->rgvarg[0], &val);
            }
            int32_t px = (val == -1) ? -1 : (val + 7) / 15;  /* twips → pixels, round */
            volvox_grid_set_col_width(gid, idx, px);
            return S_OK;
        }
        break;

    case DISPID_VG_SHOWCOMBOBUTTON:
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t combo_mode = 0;
            variant_to_i4(NAMED_ARG(0), &combo_mode);
            obj->show_combo_button_explicit = 1;
            volvox_grid_set_show_combo_button(
                gid, activex_show_combo_to_engine(combo_mode));
            return S_OK;
        }
        break;
    case DISPID_VG_SUBTOTALPOS:
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t legacy_pos = 0;
            variant_to_i4(NAMED_ARG(0), &legacy_pos);
            /* ActiveX ADO uses opposite numeric values:
             * 0 = below, 1 = above. Map to engine enum values. */
            int32_t engine_pos = legacy_pos;
            if (legacy_pos == 0) engine_pos = 1;
            else if (legacy_pos == 1) engine_pos = 0;
            volvox_grid_set_subtotal_position(gid, engine_pos);
            return S_OK;
        }
        break;

    /* ══════════════════════════════════════════════════════════ */
    /* Color properties (u32 ARGB)                                */
    /* ══════════════════════════════════════════════════════════ */

    CASE_COLOR_GETPUT(DISPID_VG_BACKCOLOR,      volvox_grid_set_back_color,           volvox_grid_get_back_color)
    CASE_COLOR_GETPUT(DISPID_VG_FORECOLOR,      volvox_grid_set_fore_color,           volvox_grid_get_fore_color)
    CASE_COLOR_GETPUT(DISPID_VG_GRIDCOLOR,      volvox_grid_set_grid_color,           volvox_grid_get_grid_color)
    CASE_COLOR_GETPUT(DISPID_VG_BACKCOLORFIXED, volvox_grid_set_back_color_fixed,     volvox_grid_get_back_color_fixed)
    CASE_COLOR_GETPUT(DISPID_VG_FORECOLORFIXED, volvox_grid_set_fore_color_fixed,     volvox_grid_get_fore_color_fixed)
    CASE_COLOR_GETPUT(DISPID_VG_BACKCOLORSEL,   volvox_grid_set_back_color_sel,       volvox_grid_get_back_color_sel)
    CASE_COLOR_GETPUT(DISPID_VG_FORECOLORSEL,   volvox_grid_set_fore_color_sel,       volvox_grid_get_fore_color_sel)
    CASE_COLOR_GETPUT(DISPID_VG_BACKCOLORALT,   volvox_grid_set_back_color_alternate, volvox_grid_get_back_color_alternate)
    CASE_COLOR_GETPUT(DISPID_VG_TREECOLOR,      volvox_grid_set_tree_color_native,    volvox_grid_get_tree_color)

    /* GridLines / GridLinesFixed (i32, but use the _native wrappers) */
    CASE_INT_GETPUT(DISPID_VG_GRIDLINES,      volvox_grid_set_grid_lines_native,       volvox_grid_get_grid_lines)
    CASE_INT_GETPUT(DISPID_VG_GRIDLINESFIXED,  volvox_grid_set_grid_lines_fixed_native, volvox_grid_get_grid_lines_fixed)

    /* FontSize (float, stored as Single / VT_R4)                       */
    /* The flex grid API uses typographic points (72 per inch).          */
    /* At 96 DPI: 1 point = 96/72 = 4/3 pixels.  Convert at boundary.  */
    case DISPID_VG_FONTSIZE:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return DISP_E_PARAMNOTOPTIONAL;
            pVarResult->vt = VT_R4;
            float px = volvox_grid_get_font_size(gid);
            pVarResult->fltVal = px * 72.0f / 96.0f;  /* pixels → points */
            return S_OK;
        }
        if (wFlags & DISPATCH_PROPERTYPUT) {
            VARIANT v; VariantInit(&v);
            VariantChangeType(&v, &pDispParams->rgvarg[0], 0, VT_R4);
            float pt = v.fltVal;
            volvox_grid_set_font_size(gid, pt * 96.0f / 72.0f);  /* points → pixels */
            return S_OK;
        }
        return DISP_E_MEMBERNOTFOUND;

    case DISPID_VG_FONTNAME:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return DISP_E_PARAMNOTOPTIONAL;
            int32_t len = 0;
            uint8_t *data = volvox_grid_get_font_name(gid, &len);
            if (data && len > 0) {
                int wlen = MultiByteToWideChar(CP_UTF8, 0, (const char *)data, len, NULL, 0);
                BSTR bs = SysAllocStringLen(NULL, wlen);
                MultiByteToWideChar(CP_UTF8, 0, (const char *)data, len, bs, wlen);
                pVarResult->vt = VT_BSTR;
                pVarResult->bstrVal = bs;
                volvox_grid_free(data, len);
            } else {
                pVarResult->vt = VT_BSTR;
                pVarResult->bstrVal = SysAllocString(L"");
                if (data) volvox_grid_free(data, len);
            }
            return S_OK;
        }
        if (wFlags & DISPATCH_PROPERTYPUT) {
            VARIANT v; VariantInit(&v);
            VariantChangeType(&v, &pDispParams->rgvarg[0], 0, VT_BSTR);
            if (v.bstrVal) {
                int u8len = WideCharToMultiByte(CP_UTF8, 0, v.bstrVal, -1, NULL, 0, NULL, NULL);
                char u8buf[256];
                WideCharToMultiByte(CP_UTF8, 0, v.bstrVal, -1, u8buf, sizeof(u8buf), NULL, NULL);
                if (u8len > 0) u8len--;  /* exclude NUL */
                volvox_grid_set_font_name(gid, (const uint8_t *)u8buf, u8len);
            }
            VariantClear(&v);
            return S_OK;
        }
        return DISP_E_MEMBERNOTFOUND;

    /* ══════════════════════════════════════════════════════════ */
    /* Indexed row/col properties                                 */
    /* ══════════════════════════════════════════════════════════ */

    CASE_INDEXED_INT_GETPUT(DISPID_VG_ROWHIDDEN,    volvox_grid_set_row_hidden, vg_get_row_hidden)
    CASE_INDEXED_INT_GETPUT(DISPID_VG_COLHIDDEN,    volvox_grid_set_col_hidden, vg_get_col_hidden)

    /* ColDataType(col) values are VARIANT/VT_xxx style constants.
     * Map them to engine column type enum values. */
    case DISPID_VG_COLDATATYPE:
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t col = 0, dt = 0;
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(&pDispParams->rgvarg[1], &col);
                variant_to_i4(&pDispParams->rgvarg[0], &dt);
            }
            volvox_grid_set_col_data_type(gid, col, activex_col_data_type_to_engine(dt));
            return S_OK;
        }
        if (wFlags & DISPATCH_PROPERTYGET) {
            /* Engine currently exposes set-only for col data type over FFI.
             * Return a stable default for compatibility probes. */
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = 8; /* FlexDTString */
            return S_OK;
        }
        break;

    case DISPID_VG_ROWDATA:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            int32_t row = 0;
            if (pDispParams->cArgs >= 1) {
                variant_to_i4(&pDispParams->rgvarg[0], &row);
            }
            int32_t out_len = 0;
            uint8_t *utf8 = volvox_grid_get_row_data(gid, row, &out_len);
            V_VT(pVarResult) = VT_BSTR;
            if (utf8 && out_len > 0) {
                V_BSTR(pVarResult) = utf8_to_bstr((const char *)utf8, out_len);
                volvox_grid_free(utf8, out_len);
            } else {
                V_BSTR(pVarResult) = SysAllocString(L"");
                if (utf8) volvox_grid_free(utf8, out_len);
            }
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t row = 0;
            VARIANT vtmp; VariantInit(&vtmp);
            BSTR text = NULL;
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(&pDispParams->rgvarg[1], &row);
                text = variant_to_bstr(&pDispParams->rgvarg[0], &vtmp);
            }
            if (text) {
                int utf8len = 0;
                char *utf8 = bstr_to_utf8(text, &utf8len);
                if (utf8 && utf8len > 0) {
                    volvox_grid_set_row_data(gid, row, (const uint8_t *)utf8, utf8len);
                    HeapFree(GetProcessHeap(), 0, utf8);
                } else {
                    volvox_grid_set_row_data(gid, row, NULL, 0);
                    if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
                }
            } else {
                volvox_grid_set_row_data(gid, row, NULL, 0);
            }
            VariantClear(&vtmp);
            return S_OK;
        }
        break;

    case DISPID_VG_COLCOMBOLIST:
        if (wFlags & DISPATCH_PROPERTYGET) {
            /* FFI currently exposes set-only ColComboList.
             * Return empty string for compatibility probes. */
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_BSTR;
            V_BSTR(pVarResult) = SysAllocString(L"");
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t col = 0;
            VARIANT vtmp; VariantInit(&vtmp);
            BSTR list = NULL;
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(&pDispParams->rgvarg[1], &col);
                list = variant_to_bstr(&pDispParams->rgvarg[0], &vtmp);
            }
            if (list) {
                int utf8len = 0;
                char *utf8 = bstr_to_utf8(list, &utf8len);
                if (utf8 && utf8len > 0) {
                    volvox_grid_set_col_combo_list(gid, col, (const uint8_t *)utf8, utf8len);
                    HeapFree(GetProcessHeap(), 0, utf8);
                } else {
                    volvox_grid_set_col_combo_list(gid, col, NULL, 0);
                    if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
                }
            } else {
                volvox_grid_set_col_combo_list(gid, col, NULL, 0);
            }
            /* Combo button stays hidden by default until
             * ShowComboButton is explicitly set. */
            if (!obj->show_combo_button_explicit) {
                volvox_grid_set_show_combo_button(gid, 0);
            }
            VariantClear(&vtmp);
            return S_OK;
        }
        break;

    /* IsSubtotal(row) behaves like a VB boolean (-1 for True, 0 for False). */
    case DISPID_VG_ISSUBTOTAL:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            int32_t row = 0;
            if (pDispParams->cArgs >= 1) {
                variant_to_i4(&pDispParams->rgvarg[0], &row);
            }
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = volvox_grid_get_is_subtotal(gid, row) ? -1 : 0;
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t row = 0, val = 0;
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(&pDispParams->rgvarg[1], &row);
                variant_to_i4(&pDispParams->rgvarg[0], &val);
            }
            volvox_grid_set_is_subtotal(gid, row, val != 0 ? 1 : 0);
            return S_OK;
        }
        break;

    /* IsCollapsed(row) uses outline-state enum:
     *   0=expanded, 1=subtotals, 2=collapsed.
     * Also, setting a non-node row applies to its parent node. */
    case DISPID_VG_ISCOLLAPSED:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            int32_t row = 0;
            if (pDispParams->cArgs >= 1) {
                variant_to_i4(&pDispParams->rgvarg[0], &row);
            }
            /* GET does not walk to parent node for non-subtotal rows. */
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = engine_collapsed_to_activex_outline_state(
                volvox_grid_get_is_collapsed(gid, row));
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t row = 0, state = 0;
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(&pDispParams->rgvarg[1], &row);
                variant_to_i4(&pDispParams->rgvarg[0], &state);
            }
            row = vfg_resolve_outline_node_row(gid, row);
            volvox_grid_set_is_collapsed(
                gid,
                row,
                activex_outline_state_to_engine_collapsed(state));
            return S_OK;
        }
        break;

    /* ── Cell(prop, row1, col1, row2, col2) ────────────────── */
    case DISPID_VG_CELL:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;

            int32_t prop = 0;
            int32_t row1 = volvox_grid_get_row(gid);
            int32_t col1 = volvox_grid_get_col(gid);
            int32_t row2 = row1;
            int32_t col2 = col1;

            if (pDispParams->cArgs >= 1) variant_to_i4(&pDispParams->rgvarg[pDispParams->cArgs - 1], &prop);
            if (pDispParams->cArgs >= 2) variant_to_i4(&pDispParams->rgvarg[pDispParams->cArgs - 2], &row1);
            if (pDispParams->cArgs >= 3) variant_to_i4(&pDispParams->rgvarg[pDispParams->cArgs - 3], &col1);
            if (pDispParams->cArgs >= 4) variant_to_i4(&pDispParams->rgvarg[pDispParams->cArgs - 4], &row2);
            if (pDispParams->cArgs >= 5) variant_to_i4(&pDispParams->rgvarg[pDispParams->cArgs - 5], &col2);

            if (pDispParams->cArgs < 4) row2 = row1;
            if (pDispParams->cArgs < 5) col2 = col1;
            vfg_normalize_cell_rect(gid, &row1, &col1, &row2, &col2);

            if (prop == 0) {
                BSTR b = vfg_get_cell_text_range(gid, row1, col1, row2, col2);
                if (!b) return E_OUTOFMEMORY;
                V_VT(pVarResult) = VT_BSTR;
                V_BSTR(pVarResult) = b;
                return S_OK;
            }

            /* Keep unsupported Cell properties non-fatal for script compatibility. */
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = 0;
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t prop = 0;
            int32_t row1 = volvox_grid_get_row(gid);
            int32_t col1 = volvox_grid_get_col(gid);
            int32_t row2 = row1;
            int32_t col2 = col1;

            VARIANT vtmp;
            BSTR text = variant_to_bstr(&pDispParams->rgvarg[0], &vtmp);

            if (pDispParams->cArgs >= 2) variant_to_i4(&pDispParams->rgvarg[pDispParams->cArgs - 1], &prop);
            if (pDispParams->cArgs >= 3) variant_to_i4(&pDispParams->rgvarg[pDispParams->cArgs - 2], &row1);
            if (pDispParams->cArgs >= 4) variant_to_i4(&pDispParams->rgvarg[pDispParams->cArgs - 3], &col1);
            if (pDispParams->cArgs >= 5) variant_to_i4(&pDispParams->rgvarg[pDispParams->cArgs - 4], &row2);
            if (pDispParams->cArgs >= 6) variant_to_i4(&pDispParams->rgvarg[pDispParams->cArgs - 5], &col2);

            if (pDispParams->cArgs < 5) row2 = row1;
            if (pDispParams->cArgs < 6) col2 = col1;
            vfg_normalize_cell_rect(gid, &row1, &col1, &row2, &col2);

            if (prop == 0) {
                int utf8len = 0;
                char *utf8 = bstr_to_utf8(text, &utf8len);
                vfg_set_cell_text_range(gid, row1, col1, row2, col2, utf8, utf8len);
                if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
            }

            VariantClear(&vtmp);
            return S_OK;
        }
        break;

    /* ── CellChecked(row, col) — 2-index property ────────────── */
    case DISPID_VG_CELLCHECKED:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(&pDispParams->rgvarg[1], &row);
                variant_to_i4(&pDispParams->rgvarg[0], &col);
            }
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = engine_checked_to_activex(volvox_grid_get_cell_checked(gid, row, col));
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            int32_t state = 0;
            if (pDispParams->cArgs >= 3) {
                variant_to_i4(&pDispParams->rgvarg[2], &row);
                variant_to_i4(&pDispParams->rgvarg[1], &col);
                variant_to_i4(&pDispParams->rgvarg[0], &state);
            } else if (pDispParams->cArgs >= 1) {
                variant_to_i4(&pDispParams->rgvarg[0], &state);
            }
            volvox_grid_set_cell_checked(gid, row, col, activex_checked_to_engine(state));
            return S_OK;
        }
        break;

    /* ── CellFlood(row, col) = color, percent ────────────────── */
    case DISPID_VG_CELLFLOOD:
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF | DISPATCH_METHOD)) {
            int32_t row = 0, col = 0;
            uint32_t color = 0;
            float percent = 0.0f;
            if (pDispParams->cArgs >= 4) {
                variant_to_i4(&pDispParams->rgvarg[3], &row);
                variant_to_i4(&pDispParams->rgvarg[2], &col);
                variant_to_u32(&pDispParams->rgvarg[1], &color);
                variant_to_float(&pDispParams->rgvarg[0], &percent);
            }
            /* Accept both 0..1 and 0..100 percent conventions. */
            if (percent > 1.0f) percent /= 100.0f;
            if (percent < 0.0f) percent = 0.0f;
            if (percent > 1.0f) percent = 1.0f;
            {
                uint32_t color_argb = olecolor_to_argb(color);
                vfg_set_flood_color_cached(obj, row, col, color_argb);
                volvox_grid_set_cell_flood(gid, row, col, color_argb, percent);
            }
            return S_OK;
        }
        break;

    /* CellFloodColor applies to current Row/Col. */
    case DISPID_VG_CELLFLOODCOLOR:
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            uint32_t color = 0;
            if (pDispParams->cArgs >= 3) {
                variant_to_i4(&pDispParams->rgvarg[2], &row);
                variant_to_i4(&pDispParams->rgvarg[1], &col);
                variant_to_u32(&pDispParams->rgvarg[0], &color);
            } else if (pDispParams->cArgs >= 1) {
                variant_to_u32(&pDispParams->rgvarg[0], &color);
            }
            vfg_set_flood_color_cached(obj, row, col, olecolor_to_argb(color));
            return S_OK;
        }
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(&pDispParams->rgvarg[1], &row);
                variant_to_i4(&pDispParams->rgvarg[0], &col);
            }
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) =
                (int32_t)argb_to_olecolor(vfg_get_flood_color_cached(obj, row, col));
            return S_OK;
        }
        break;

    /* CellFloodPercent applies to current Row/Col and uses -100..100. */
    case DISPID_VG_CELLFLOODPERCENT:
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            float percent = 0.0f;
            if (pDispParams->cArgs >= 1) {
                variant_to_float(&pDispParams->rgvarg[0], &percent);
            }
            if (percent < 0.0f) percent = -percent;
            if (percent > 1.0f) percent /= 100.0f;
            if (percent > 1.0f) percent = 1.0f;
            volvox_grid_set_cell_flood(
                gid,
                row,
                col,
                vfg_get_flood_color_cached(obj, row, col),
                percent);
            return S_OK;
        }
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = 0;
            return S_OK;
        }
        break;

    /* ══════════════════════════════════════════════════════════ */
    /* Methods (DISPATCH_METHOD)                                   */
    /* ══════════════════════════════════════════════════════════ */

    /* FindRow(text, startRow, col, caseSense, fullMatch)
     * with optional arguments. */
    case DISPID_VG_FINDROW_COMPAT:
        if (wFlags & DISPATCH_METHOD) {
            BSTR text = NULL;
            VARIANT vtxt; VariantInit(&vtxt);
            int32_t start_row = 0;
            int32_t col = -1;
            int32_t case_sense = 0;
            int32_t full_match = 0;
            int32_t out_len = 0;
            int32_t found_row = -1;
            uint8_t *resp = NULL;
            char *utf8 = NULL;
            int utf8len = 0;

            if (pDispParams->cArgs >= 1) text = variant_to_bstr(ARG(0), &vtxt);
            if (pDispParams->cArgs >= 2 && !variant_is_missing(ARG(1))) variant_to_i4(ARG(1), &start_row);
            if (pDispParams->cArgs >= 3 && !variant_is_missing(ARG(2))) variant_to_i4(ARG(2), &col);
            if (pDispParams->cArgs >= 4 && !variant_is_missing(ARG(3))) variant_to_i4(ARG(3), &case_sense);
            if (pDispParams->cArgs >= 5 && !variant_is_missing(ARG(4))) variant_to_i4(ARG(4), &full_match);

            utf8 = bstr_to_utf8(text, &utf8len);
            resp = volvox_grid_find_row(
                gid,
                (const uint8_t *)(utf8 ? utf8 : ""),
                utf8 ? utf8len : 0,
                start_row,
                col,
                case_sense ? 1 : 0,
                full_match ? 1 : 0,
                &out_len);
            found_row = vfg_take_i32_response(resp, out_len, -1);

            if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
            VariantClear(&vtxt);

            if (pVarResult) {
                V_VT(pVarResult) = VT_I4;
                V_I4(pVarResult) = found_row;
            }
            return S_OK;
        }
        break;

    case DISPID_VG_FINDROWREGEX_COMPAT:
        if (wFlags & DISPATCH_METHOD) {
            BSTR pattern = NULL;
            VARIANT vpat; VariantInit(&vpat);
            int32_t start_row = 0;
            int32_t col = -1;
            int32_t out_len = 0;
            int32_t found_row = -1;
            uint8_t *resp = NULL;
            char *utf8 = NULL;
            int utf8len = 0;

            if (pDispParams->cArgs >= 1) pattern = variant_to_bstr(ARG(0), &vpat);
            if (pDispParams->cArgs >= 2 && !variant_is_missing(ARG(1))) variant_to_i4(ARG(1), &start_row);
            if (pDispParams->cArgs >= 3 && !variant_is_missing(ARG(2))) variant_to_i4(ARG(2), &col);

            utf8 = bstr_to_utf8(pattern, &utf8len);
            resp = volvox_grid_find_row_regex(
                gid,
                (const uint8_t *)(utf8 ? utf8 : ""),
                utf8 ? utf8len : 0,
                start_row,
                col,
                &out_len);
            found_row = vfg_take_i32_response(resp, out_len, -1);

            if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
            VariantClear(&vpat);

            if (pVarResult) {
                V_VT(pVarResult) = VT_I4;
                V_I4(pVarResult) = found_row;
            }
            return S_OK;
        }
        break;

    /* Sort compatibility:
     *  - property form: Sort = order (uses Col..ColSel key range)
     *  - method form: Sort(order, col) */
    case DISPID_VG_SORT:
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t order = 0;
            variant_to_i4(NAMED_ARG(0), &order);
            /* Property-style Sort uses currently selected key column(s). */
            volvox_grid_sort(gid, order, -1);
            return S_OK;
        }
        if (wFlags & DISPATCH_METHOD) {
            int32_t order = 0, col = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &order);
            if (pDispParams->cArgs >= 2) variant_to_i4(ARG(1), &col);
            volvox_grid_sort(gid, order, col);
            return S_OK;
        }
        break;

    /* Subtotal signature:
     *   Subtotal(Function, GroupOn, TotalOn, Format, BackColor, ForeColor,
     *            FontBold, Caption, MatchFrom, TotalOnly)
     *
     * Engine FFI currently exposes a simplified API:
     *   subtotal(aggregate, group_on_col, aggregate_col, caption, back, fore, add_outline)
     *
     * For classic datagrid compatibility, interpret positional args in the original API order.
     * We currently forward Caption/BackColor/ForeColor and always enable outline,
     * while tolerating extra args (Format/FontBold/MatchFrom/TotalOnly).
     */
    case DISPID_VG_SUBTOTAL:
        if (wFlags & DISPATCH_METHOD) {
            int32_t aggregate = 0, group_col = 0, agg_col = 0;
            uint32_t bcolor = 0, fcolor = 0;
            int32_t font_bold = 0;
            int32_t match_from = -1;
            int32_t total_only = 0;
            BSTR fmt = NULL;
            BSTR caption = NULL;  /* 8th argument */
            VARIANT vfmt, vcap;
            VariantInit(&vfmt); VariantInit(&vcap);
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &aggregate);
            if (pDispParams->cArgs >= 2) variant_to_i4(ARG(1), &group_col);
            if (pDispParams->cArgs >= 3) variant_to_i4(ARG(2), &agg_col);
            if (pDispParams->cArgs >= 4) fmt = variant_to_bstr(ARG(3), &vfmt);
            if (pDispParams->cArgs >= 5) variant_to_u32(ARG(4), &bcolor);
            if (pDispParams->cArgs >= 6) variant_to_u32(ARG(5), &fcolor);
            if (pDispParams->cArgs >= 7) variant_to_i4(ARG(6), &font_bold);
            if (pDispParams->cArgs >= 8) caption = variant_to_bstr(ARG(7), &vcap);
            if (pDispParams->cArgs >= 9) variant_to_i4(ARG(8), &match_from);
            if (pDispParams->cArgs >= 10) variant_to_i4(ARG(9), &total_only);

            (void)fmt;
            (void)font_bold;
            (void)match_from;
            (void)total_only;

            int utf8len = 0;
            char *utf8 = bstr_to_utf8(caption, &utf8len);
            volvox_grid_subtotal(gid, aggregate, group_col, agg_col,
                (const uint8_t *)(utf8 ? utf8 : ""), utf8 ? utf8len : 0,
                olecolor_to_argb(bcolor), olecolor_to_argb(fcolor), 1);
            if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
            VariantClear(&vfmt); VariantClear(&vcap);
            return S_OK;
        }
        break;

    /* AutoSize(col_from, col_to, equal, max_width) */
    case DISPID_VG_AUTOSIZE:
        if (wFlags & DISPATCH_METHOD) {
            int32_t from = 0, to = 0, equal = 0, max_w = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &from);
            if (pDispParams->cArgs >= 2) variant_to_i4(ARG(1), &to);
            if (pDispParams->cArgs >= 3) variant_to_i4(ARG(2), &equal);
            if (pDispParams->cArgs >= 4) variant_to_i4(ARG(3), &max_w);
            volvox_grid_auto_size(gid, from, to, equal, max_w);
            return S_OK;
        }
        break;

    /* AddItem(item, index) */
    case DISPID_VG_ADDITEM:
        if (wFlags & DISPATCH_METHOD) {
            BSTR item = NULL;
            VARIANT vitm; VariantInit(&vitm);
            int32_t index = -1;
            if (pDispParams->cArgs >= 1) item = variant_to_bstr(ARG(0), &vitm);
            if (pDispParams->cArgs >= 2) variant_to_i4(ARG(1), &index);
            int utf8len = 0;
            char *utf8 = bstr_to_utf8(item, &utf8len);
            volvox_grid_add_item(gid,
                (const uint8_t *)(utf8 ? utf8 : ""), utf8 ? utf8len : 0, index);
            if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
            VariantClear(&vitm);
            return S_OK;
        }
        break;

    /* RemoveItem(index) */
    case DISPID_VG_REMOVEITEM:
        if (wFlags & DISPATCH_METHOD) {
            int32_t index = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &index);
            volvox_grid_remove_item(gid, index);
            return S_OK;
        }
        break;

    /* Clear(scope, region) */
    case DISPID_VG_CLEAR:
        if (wFlags & DISPATCH_METHOD) {
            int32_t scope = 0, region = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &scope);
            if (pDispParams->cArgs >= 2) variant_to_i4(ARG(1), &region);
            volvox_grid_clear(gid, scope, region);
            return S_OK;
        }
        break;

    /* Select(row1, col1, row2, col2) */
    case DISPID_VG_SELECT:
        if (wFlags & DISPATCH_METHOD) {
            int32_t r1 = 0, c1 = 0, r2 = 0, c2 = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &r1);
            if (pDispParams->cArgs >= 2) variant_to_i4(ARG(1), &c1);
            if (pDispParams->cArgs >= 3) variant_to_i4(ARG(2), &r2);
            if (pDispParams->cArgs >= 4) variant_to_i4(ARG(3), &c2);
            volvox_grid_select(gid, r1, c1, r2, c2);
            return S_OK;
        }
        break;

    /* Refresh() */
    case DISPID_VG_REFRESH:
        if (wFlags & DISPATCH_METHOD) {
            volvox_grid_refresh(gid);
            return S_OK;
        }
        break;

    case DISPID_VG_EDITCELL:
        if (wFlags & DISPATCH_METHOD) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &row);
            if (pDispParams->cArgs >= 2) variant_to_i4(ARG(1), &col);
            volvox_grid_edit_cell(gid, row, col);
            return S_OK;
        }
        break;

    default:
        break;
    }

#undef ARG
#undef NAMED_ARG

    return DISP_E_MEMBERNOTFOUND;
}

/* ── IViewObject ──────────────────────────────────────────────── */

static HRESULT STDMETHODCALLTYPE VFG_VO_QueryInterface(
    IViewObject *This, REFIID riid, void **ppv)
{
    VolvoxGridObject *obj = OBJ_FROM_VIEWOBJECT(This);
    return VFG_QueryInterface((IDispatch *)obj, riid, ppv);
}

static ULONG STDMETHODCALLTYPE VFG_VO_AddRef(IViewObject *This) {
    VolvoxGridObject *obj = OBJ_FROM_VIEWOBJECT(This);
    return InterlockedIncrement(&obj->cRef);
}

static ULONG STDMETHODCALLTYPE VFG_VO_Release(IViewObject *This) {
    VolvoxGridObject *obj = OBJ_FROM_VIEWOBJECT(This);
    return VFG_Release((IDispatch *)obj);
}

static HRESULT STDMETHODCALLTYPE VFG_VO_Draw(
    IViewObject *This,
    DWORD dwDrawAspect,
    LONG lindex,
    void *pvAspect,
    DVTARGETDEVICE *ptd,
    HDC hdcTargetDev,
    HDC hdcDraw,
    LPCRECTL lprcBounds,
    LPCRECTL lprcWBounds,
    BOOL (STDMETHODCALLTYPE *pfnContinue)(ULONG_PTR dwContinue),
    ULONG_PTR dwContinue)
{
    (void)lindex; (void)pvAspect; (void)ptd; (void)hdcTargetDev;
    (void)lprcWBounds; (void)pfnContinue; (void)dwContinue;

    if (dwDrawAspect != DVASPECT_CONTENT)
        return DV_E_DVASPECT;
    if (!lprcBounds || !hdcDraw)
        return E_INVALIDARG;

    VolvoxGridObject *obj = OBJ_FROM_VIEWOBJECT(This);
    int w = (int)(lprcBounds->right - lprcBounds->left);
    int h = (int)(lprcBounds->bottom - lprcBounds->top);
    if (w <= 0 || h <= 0) return S_OK;

    /* Allocate BGRA pixel buffer */
    int stride = w * 4;
    uint8_t *pixels = (uint8_t *)HeapAlloc(GetProcessHeap(), 0, stride * h);
    if (!pixels) return E_OUTOFMEMORY;

    /* Render grid directly to BGRA buffer */
    int32_t rc = volvox_grid_render_bgra(obj->grid_id, pixels, w, h);
    if (rc != 0) {
        HeapFree(GetProcessHeap(), 0, pixels);
        RECT rect = { (LONG)lprcBounds->left, (LONG)lprcBounds->top,
                       (LONG)lprcBounds->right, (LONG)lprcBounds->bottom };
        FillRect(hdcDraw, &rect, (HBRUSH)GetStockObject(LTGRAY_BRUSH));
        return S_OK;
    }

    /* Blit BGRA pixels to the target DC via SetDIBitsToDevice */
    BITMAPINFO bmi;
    memset(&bmi, 0, sizeof(bmi));
    bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = w;
    bmi.bmiHeader.biHeight = -h;  /* top-down */
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 32;
    bmi.bmiHeader.biCompression = BI_RGB;

    SetDIBitsToDevice(hdcDraw,
        (int)lprcBounds->left, (int)lprcBounds->top, w, h,
        0, 0, 0, h,
        pixels, &bmi, DIB_RGB_COLORS);

    HeapFree(GetProcessHeap(), 0, pixels);
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_VO_GetColorSet(
    IViewObject *This, DWORD a, LONG b, void *c, DVTARGETDEVICE *d,
    HDC e, LOGPALETTE **f)
{
    (void)This;(void)a;(void)b;(void)c;(void)d;(void)e;(void)f;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE VFG_VO_Freeze(
    IViewObject *This, DWORD a, LONG b, void *c, DWORD *d)
{
    (void)This;(void)a;(void)b;(void)c;(void)d;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE VFG_VO_Unfreeze(
    IViewObject *This, DWORD a)
{
    (void)This;(void)a;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE VFG_VO_SetAdvise(
    IViewObject *This, DWORD a, DWORD b, IAdviseSink *c)
{
    (void)This;(void)a;(void)b;(void)c;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE VFG_VO_GetAdvise(
    IViewObject *This, DWORD *a, DWORD *b, IAdviseSink **c)
{
    (void)This;(void)a;(void)b;(void)c;
    return E_NOTIMPL;
}

/* ════════════════════════════════════════════════════════════════ */
/* Vtables                                                         */
/* ════════════════════════════════════════════════════════════════ */

static IDispatchVtbl g_VFGDispatchVtbl = {
    VFG_QueryInterface,
    VFG_AddRef,
    VFG_Release,
    VFG_GetTypeInfoCount,
    VFG_GetTypeInfo,
    VFG_GetIDsOfNames,
    VFG_Invoke,
};

static IViewObjectVtbl g_VFGViewObjectVtbl = {
    VFG_VO_QueryInterface,
    VFG_VO_AddRef,
    VFG_VO_Release,
    VFG_VO_Draw,
    VFG_VO_GetColorSet,
    VFG_VO_Freeze,
    VFG_VO_Unfreeze,
    VFG_VO_SetAdvise,
    VFG_VO_GetAdvise,
};

/* ════════════════════════════════════════════════════════════════ */
/* GDI text renderer callbacks                                     */
/* ════════════════════════════════════════════════════════════════ */

/* Convert UTF-8 (ptr, len) to a stack-allocated wchar_t buffer.
 * Returns the number of wide chars written (excluding NUL).
 * `wbuf` must have room for `wbuf_cap` wchar_t including NUL. */
static int utf8_to_wchar(const uint8_t *u8, int u8_len,
                         wchar_t *wbuf, int wbuf_cap) {
    if (u8_len <= 0 || !u8) { wbuf[0] = 0; return 0; }
    int n = MultiByteToWideChar(CP_UTF8, 0, (const char *)u8, u8_len,
                                wbuf, wbuf_cap - 1);
    wbuf[n] = 0;
    return n;
}

/* Create a GDI HFONT matching the engine parameters. */
static HFONT gdi_create_font(const uint8_t *font_name_ptr, int font_name_len,
                             float font_size, int bold, int italic) {
    wchar_t face[64];
    utf8_to_wchar(font_name_ptr, font_name_len, face, 64);
    /* lfHeight negative = character em-height in pixels */
    int height = -(int)(font_size + 0.5f);
    if (height == 0) height = -1;
    return CreateFontW(
        height, 0, 0, 0,
        bold ? FW_BOLD : FW_NORMAL,
        italic ? TRUE : FALSE,
        FALSE, FALSE,              /* underline, strikeout */
        DEFAULT_CHARSET,
        OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS,
        ANTIALIASED_QUALITY,
        DEFAULT_PITCH | FF_DONTCARE,
        face[0] ? face : L"Arial"
    );
}

/* Wine memory-DC text rendering can miss visual bold weight.
 * Detect Wine once and synthesize a subtle bold pass only there. */
static BOOL gdi_is_wine(void) {
    static int cached = -1;
    if (cached >= 0) return cached ? TRUE : FALSE;
    HMODULE ntdll = GetModuleHandleW(L"ntdll.dll");
    FARPROC wine_get_version = ntdll ? GetProcAddress(ntdll, "wine_get_version") : NULL;
    cached = wine_get_version ? 1 : 0;
    return cached ? TRUE : FALSE;
}

static int gdi_clamp_int(int v, int lo, int hi) {
    if (v < lo) return lo;
    if (v > hi) return hi;
    return v;
}

static uint8_t gdi_dib_green_at(
    const uint8_t *dib, int dib_stride, int rw, int rh, int sx, int sy)
{
    sx = gdi_clamp_int(sx, 0, rw - 1);
    sy = gdi_clamp_int(sy, 0, rh - 1);
    return dib[sy * dib_stride + sx * 4 + 1];
}

static void gdi_measure_text(
    const uint8_t *text_ptr, int32_t text_len,
    const uint8_t *font_name_ptr, int32_t font_name_len,
    float font_size, int32_t bold, int32_t italic,
    float max_width,
    float *out_width, float *out_height,
    void *user_data)
{
    (void)user_data;
    *out_width = 0; *out_height = 0;
    if (text_len <= 0) { *out_height = font_size * 1.2f; return; }

    wchar_t wtext[2048];
    int wlen = utf8_to_wchar(text_ptr, text_len, wtext, 2048);
    if (wlen <= 0) { *out_height = font_size * 1.2f; return; }

    HDC hdc = CreateCompatibleDC(NULL);
    HFONT hfont = gdi_create_font(font_name_ptr, font_name_len,
                                  font_size, bold, italic);
    HFONT old = (HFONT)SelectObject(hdc, hfont);

    if (max_width < 0) {
        /* Single-line measurement */
        SIZE sz;
        GetTextExtentPoint32W(hdc, wtext, wlen, &sz);
        *out_width  = (float)sz.cx;
        if (bold && gdi_is_wine()) *out_width += 1.0f;
        *out_height = (float)sz.cy;
    } else {
        /* Word-wrap measurement */
        RECT rc = { 0, 0, (LONG)(max_width + 0.5f), 0 };
        DrawTextW(hdc, wtext, wlen, &rc,
                  DT_CALCRECT | DT_WORDBREAK | DT_NOPREFIX | DT_EXPANDTABS);
        *out_width  = (float)(rc.right - rc.left);
        if (bold && gdi_is_wine()) *out_width += 1.0f;
        *out_height = (float)(rc.bottom - rc.top);
    }

    SelectObject(hdc, old);
    DeleteObject(hfont);
    DeleteDC(hdc);
}

static float gdi_render_text(
    uint8_t *buffer, int32_t buf_width, int32_t buf_height, int32_t stride,
    int32_t x, int32_t y, int32_t clip_w, int32_t clip_h,
    const uint8_t *text_ptr, int32_t text_len,
    const uint8_t *font_name_ptr, int32_t font_name_len,
    float font_size, int32_t bold, int32_t italic,
    uint32_t color, float max_width,
    void *user_data)
{
    (void)user_data;
    if (text_len <= 0 || clip_w <= 0 || clip_h <= 0)
        return 0.0f;

    wchar_t wtext[2048];
    int wlen = utf8_to_wchar(text_ptr, text_len, wtext, 2048);
    if (wlen <= 0) return 0.0f;

    /* Parse engine color 0xAARRGGBB */
    uint8_t src_r = (uint8_t)((color >> 16) & 0xFF);
    uint8_t src_g = (uint8_t)((color >>  8) & 0xFF);
    uint8_t src_b = (uint8_t)((color      ) & 0xFF);
    uint8_t src_a = (uint8_t)((color >> 24) & 0xFF);
    if (src_a == 0) return 0.0f;

    int dw = clip_w;
    int dh = clip_h;
    int rw = dw;
    int rh = dh;
    if (rw < 1) rw = 1;
    if (rh < 1) rh = 1;

    HFONT hfont = gdi_create_font(font_name_ptr, font_name_len,
                                  font_size,
                                  bold, italic);

    UINT fmt = DT_NOPREFIX | DT_EXPANDTABS;
    if (max_width >= 0)
        fmt |= DT_WORDBREAK;
    else
        fmt |= DT_SINGLELINE;

    /* Offscreen white-on-black rendering with alpha extraction.
     * Wine does not antialias text on memory DCs; this is a known
     * limitation that only affects the comparison tests under Wine.
     * On real Windows, GDI produces proper antialiased text here. */
    HDC screen_dc = GetDC(NULL);
    HDC hdc = CreateCompatibleDC(screen_dc);
    HBITMAP hbmp = CreateCompatibleBitmap(screen_dc, rw, rh);
    ReleaseDC(NULL, screen_dc);
    if (!hbmp) {
        DeleteDC(hdc);
        DeleteObject(hfont);
        return 0.0f;
    }

    HBITMAP old_bmp = (HBITMAP)SelectObject(hdc, hbmp);
    HFONT old_font = (HFONT)SelectObject(hdc, hfont);

    /* Clear to black, draw white text → luminance = alpha coverage */
    RECT fill_rc = { 0, 0, rw, rh };
    FillRect(hdc, &fill_rc, (HBRUSH)GetStockObject(BLACK_BRUSH));

    SetBkMode(hdc, TRANSPARENT);
    SetTextColor(hdc, RGB(255, 255, 255));

    RECT rc = { 0, 0, rw, rh };
    DrawTextW(hdc, wtext, wlen, &rc, fmt);
    if (bold && gdi_is_wine()) {
        RECT rc_bold = { 1, 0, rw + 1, rh };
        DrawTextW(hdc, wtext, wlen, &rc_bold, fmt);
    }

    /* Measure the rendered width */
    RECT mrc = { 0, 0, rw, rh };
    DrawTextW(hdc, wtext, wlen, &mrc, fmt | DT_CALCRECT);
    float rendered_w = (float)(mrc.right - mrc.left);
    if (bold && gdi_is_wine()) rendered_w += 1.0f;

    /* Read back */
    BITMAPINFO bmi;
    memset(&bmi, 0, sizeof(bmi));
    bmi.bmiHeader.biSize        = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth       = rw;
    bmi.bmiHeader.biHeight      = -rh;
    bmi.bmiHeader.biPlanes      = 1;
    bmi.bmiHeader.biBitCount    = 32;
    bmi.bmiHeader.biCompression = BI_RGB;

    int dib_stride = rw * 4;
    uint8_t *dib = (uint8_t *)HeapAlloc(GetProcessHeap(), 0, dib_stride * rh);
    if (!dib) {
        SelectObject(hdc, old_font);
        DeleteObject(hfont);
        SelectObject(hdc, old_bmp);
        DeleteObject(hbmp);
        DeleteDC(hdc);
        return 0.0f;
    }
    GetDIBits(hdc, hbmp, 0, rh, dib, &bmi, DIB_RGB_COLORS);

    /* Composite into the target RGBA buffer.
     * DIB readback is BGRA (B at byte 0), target is RGBA (R at byte 0). */
    for (int py = 0; py < dh; py++) {
        int by = y + py;
        if (by < 0 || by >= buf_height) continue;
        for (int px = 0; px < dw; px++) {
            int bx = x + px;
            if (bx < 0 || bx >= buf_width) continue;

            /* Resample source alpha back to destination size (1:1 currently). */
            double src_x = ((double)px + 0.5) - 0.5;
            double src_y = ((double)py + 0.5) - 0.5;
            if (src_x < 0.0) src_x = 0.0;
            if (src_y < 0.0) src_y = 0.0;
            if (src_x > (double)(rw - 1)) src_x = (double)(rw - 1);
            if (src_y > (double)(rh - 1)) src_y = (double)(rh - 1);

            int sx0 = (int)src_x;
            int sy0 = (int)src_y;
            int sx1 = (sx0 + 1 < rw) ? (sx0 + 1) : sx0;
            int sy1 = (sy0 + 1 < rh) ? (sy0 + 1) : sy0;
            double wx = src_x - (double)sx0;
            double wy = src_y - (double)sy0;

            uint32_t a00 = gdi_dib_green_at(dib, dib_stride, rw, rh, sx0, sy0);
            uint32_t a10 = gdi_dib_green_at(dib, dib_stride, rw, rh, sx1, sy0);
            uint32_t a01 = gdi_dib_green_at(dib, dib_stride, rw, rh, sx0, sy1);
            uint32_t a11 = gdi_dib_green_at(dib, dib_stride, rw, rh, sx1, sy1);
            double alpha_f = ((double)a00 * (1.0 - wx) * (1.0 - wy)) +
                             ((double)a10 * wx * (1.0 - wy)) +
                             ((double)a01 * (1.0 - wx) * wy) +
                             ((double)a11 * wx * wy);
            uint32_t alpha = (uint32_t)(alpha_f + 0.5);
            if (alpha == 0) continue;

            /* Scale by source alpha */
            alpha = (alpha * src_a + 127) / 255;
            if (alpha == 0) continue;

            int dst_off = by * stride + bx * 4;
            if (dst_off + 3 >= stride * buf_height) continue;

            if (alpha >= 255) {
                buffer[dst_off]     = src_r;
                buffer[dst_off + 1] = src_g;
                buffer[dst_off + 2] = src_b;
                buffer[dst_off + 3] = 255;
            } else {
                uint32_t inv = 255 - alpha;
                uint32_t dr = buffer[dst_off];
                uint32_t dg = buffer[dst_off + 1];
                uint32_t db = buffer[dst_off + 2];
                uint32_t da = buffer[dst_off + 3];
                buffer[dst_off]     = (uint8_t)((src_r * alpha + dr * inv + 127) / 255);
                buffer[dst_off + 1] = (uint8_t)((src_g * alpha + dg * inv + 127) / 255);
                buffer[dst_off + 2] = (uint8_t)((src_b * alpha + db * inv + 127) / 255);
                uint32_t out_a = alpha + (da * inv + 127) / 255;
                buffer[dst_off + 3] = (uint8_t)(out_a > 255 ? 255 : out_a);
            }
        }
    }

    HeapFree(GetProcessHeap(), 0, dib);
    SelectObject(hdc, old_font);
    DeleteObject(hfont);
    SelectObject(hdc, old_bmp);
    DeleteObject(hbmp);
    DeleteDC(hdc);

    return rendered_w;
}

/* ════════════════════════════════════════════════════════════════ */
/* Factory helper (called from dllexports.c)                       */
/* ════════════════════════════════════════════════════════════════ */

HRESULT VolvoxGrid_CreateInstance(IUnknown *pOuter, REFIID riid, void **ppv) {
    if (pOuter) return CLASS_E_NOAGGREGATION;

    VolvoxGridObject *obj = HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*obj));
    if (!obj) return E_OUTOFMEMORY;

    obj->lpVtblDispatch = &g_VFGDispatchVtbl;
    obj->lpVtblViewObject = &g_VFGViewObjectVtbl;
    obj->cRef = 1;
    obj->fixed_rows_cached = 1;
    obj->fixed_cols_cached = 1;
    /* Create a default grid (640x480, 10 rows, 5 cols) */
    obj->grid_id = volvox_grid_create_grid(640, 480, 10, 5, 1, 1, 1.0f);

    /* Register GDI text renderer for pixel-perfect Windows text */
    volvox_grid_set_text_renderer(obj->grid_id,
        gdi_measure_text, gdi_render_text, NULL);

    /* Match classic FlexGrid's system-driven palette defaults. */
    volvox_grid_set_back_color(
        obj->grid_id,
        olecolor_to_argb((uint32_t)GetSysColor(COLOR_WINDOW)));
    volvox_grid_set_fore_color(
        obj->grid_id,
        olecolor_to_argb((uint32_t)GetSysColor(COLOR_WINDOWTEXT)));
    volvox_grid_set_back_color_fixed(
        obj->grid_id,
        olecolor_to_argb((uint32_t)GetSysColor(COLOR_BTNFACE)));
    volvox_grid_set_fore_color_fixed(
        obj->grid_id,
        olecolor_to_argb((uint32_t)GetSysColor(COLOR_BTNTEXT)));
    volvox_grid_set_grid_color(
        obj->grid_id,
        olecolor_to_argb((uint32_t)GetSysColor(COLOR_BTNFACE)));
    volvox_grid_set_grid_color_fixed(
        obj->grid_id,
        olecolor_to_argb((uint32_t)GetSysColor(COLOR_BTNFACE)));
    volvox_grid_set_back_color_sel(
        obj->grid_id,
        olecolor_to_argb((uint32_t)GetSysColor(COLOR_HIGHLIGHT)));
    volvox_grid_set_fore_color_sel(
        obj->grid_id,
        olecolor_to_argb((uint32_t)GetSysColor(COLOR_HIGHLIGHTTEXT)));

    HRESULT hr = VFG_QueryInterface((IDispatch *)obj, riid, ppv);
    VFG_Release((IDispatch *)obj);
    return hr;
}
