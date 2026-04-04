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

/* MSDATASRC.DataSource IID {7C0FFAB3-CD84-11D0-949A-00A0C91110ED}. */
static const GUID IID_VFG_DataSource = {
    0x7c0ffab3, 0xcd84, 0x11d0,
    {0x94, 0x9a, 0x00, 0xa0, 0xc9, 0x11, 0x10, 0xed}
};

#define VFG_DEFAULT_DPI 96
#define VFG_BOUND_HEADER_ROWS 1
#define VFG_BOUND_SELECTOR_COL_WIDTH_PX 13
#define VFG_BOUND_AUTOSIZE_TEXT_PAD_PX 13
#define VFG_BOUND_AUTOSIZE_MIN_COL_WIDTH_PX 20

static void gdi_measure_text(
    const uint8_t *text_ptr, int32_t text_len,
    const uint8_t *font_name_ptr, int32_t font_name_len,
    float font_size, int32_t bold, int32_t italic,
    float max_width,
    float *out_width, float *out_height,
    void *user_data);

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
VG_WRAP_I32_1(volvox_grid_get_auto_resize, int64_t, id)
VG_WRAP_I32_1(volvox_grid_get_col, int64_t, id)
VG_WRAP_I32_3(volvox_grid_get_col_index, int64_t, grid_id, const uint8_t*, key, int32_t, key_len)
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
VG_WRAP_STATUS_4(volvox_grid_set_cell_checked, int64_t, grid_id, int32_t, row, int32_t, col, int32_t, state)
VG_WRAP_STATUS_5(volvox_grid_set_cell_flood, int64_t, grid_id, int32_t, row, int32_t, col, uint32_t, color, float, percent)
VG_WRAP_STATUS_4(volvox_grid_set_col_combo_list, int64_t, grid_id, int32_t, col, const uint8_t*, list, int32_t, list_len)
VG_WRAP_STATUS_3(volvox_grid_set_col_data_type, int64_t, grid_id, int32_t, col, int32_t, data_type)
VG_WRAP_STATUS_3(volvox_grid_set_col_width, int64_t, grid_id, int32_t, col, int32_t, width)
VG_WRAP_STATUS_2(volvox_grid_set_auto_resize, int64_t, grid_id, int32_t, value)
VG_WRAP_STATUS_2(volvox_grid_set_fixed_cols, int64_t, grid_id, int32_t, fixed_cols)
VG_WRAP_STATUS_2(volvox_grid_set_fixed_rows, int64_t, grid_id, int32_t, fixed_rows)
VG_WRAP_STATUS_3(volvox_grid_set_is_collapsed, int64_t, grid_id, int32_t, row, int32_t, collapsed)
VG_WRAP_STATUS_3(volvox_grid_set_is_subtotal, int64_t, grid_id, int32_t, row, int32_t, is_subtotal)
VG_WRAP_STATUS_4(volvox_grid_set_row_data, int64_t, grid_id, int32_t, col, const uint8_t*, data, int32_t, data_len)
VG_WRAP_STATUS_3(volvox_grid_set_row_height, int64_t, grid_id, int32_t, row, int32_t, height)
VG_WRAP_STATUS_2(volvox_grid_set_show_combo_button, int64_t, grid_id, int32_t, mode)
VG_WRAP_STATUS_2(volvox_grid_set_subtotal_position, int64_t, grid_id, int32_t, position)
VG_WRAP_STATUS_5(volvox_grid_set_text_matrix, int64_t, grid_id, int32_t, row, int32_t, col, const uint8_t*, text, int32_t, text_len)
VG_WRAP_STATUS_3(volvox_grid_load_demo, int64_t, grid_id, const uint8_t*, demo, int32_t, demo_len)

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

static int32_t vfg_engine_auto_resize_enabled(int64_t grid_id, int32_t fallback) {
    int32_t value = volvox_grid_get_auto_resize_compat(grid_id);
    if (value < 0) return fallback ? 1 : 0;
    return value != 0;
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
     *      SortColumn { int32 col = 1; FlexSortSpec order = 2; }
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
        NULL,
        0,
        &out_len);
    return vfg_take_status_response(out);
}

static int vfg_encode_resize_policy(uint8_t *buf, int32_t mode) {
    int pos = 0;
    int columns = 0;
    int rows = 0;
    int uniform = 0;

    switch (mode) {
    case 1:
        columns = 1;
        break;
    case 2:
        rows = 1;
        break;
    case 3:
        columns = 1;
        rows = 1;
        break;
    case 4:
        columns = 1;
        uniform = 1;
        break;
    case 5:
        rows = 1;
        uniform = 1;
        break;
    case 6:
        columns = 1;
        rows = 1;
        uniform = 1;
        break;
    default:
        break;
    }

    if (columns) {
        buf[pos++] = 0x08; /* field 1, varint */
        buf[pos++] = 0x01;
    }
    if (rows) {
        buf[pos++] = 0x10; /* field 2, varint */
        buf[pos++] = 0x01;
    }
    if (uniform) {
        buf[pos++] = 0x18; /* field 3, varint */
        buf[pos++] = 0x01;
    }
    return pos;
}

static int32_t volvox_grid_set_resize_policy_compat(int64_t grid_id, int32_t mode) {
    uint8_t policy[8];
    int32_t out_len = 0;
    int policy_len = vfg_encode_resize_policy(policy, mode);
    uint8_t *out = volvox_grid_set_resize_policy(grid_id, policy, policy_len, &out_len);
    return vfg_take_status_response(out);
}

typedef struct VolvoxGridObject VolvoxGridObject;
static int32_t volvox_grid_set_editable_compat(int64_t grid_id, int32_t mode);
static VolvoxGridObject *vfg_find_object_by_grid_id(int64_t grid_id);
static HRESULT vfg_rebind_ado_source(VolvoxGridObject *obj);
static int32_t vfg_bound_selector_cols(VolvoxGridObject *obj);
static int32_t vfg_bound_allows_zero_fixed_cols(VolvoxGridObject *obj);


static uint8_t *vfg_native_set_rows(int64_t grid_id, int32_t rows, int32_t *out_len) {
    return volvox_grid_set_rows(grid_id, rows, out_len);
}

static uint8_t *vfg_native_set_cols(int64_t grid_id, int32_t cols, int32_t *out_len) {
    return volvox_grid_set_cols(grid_id, cols, out_len);
}

static uint8_t *vfg_native_set_row(int64_t grid_id, int32_t row, int32_t *out_len) {
    return volvox_grid_set_row(grid_id, row, out_len);
}

static uint8_t *vfg_native_set_col(int64_t grid_id, int32_t col, int32_t *out_len) {
    return volvox_grid_set_col(grid_id, col, out_len);
}

static uint8_t *vfg_native_set_frozen_rows(int64_t grid_id, int32_t value, int32_t *out_len) {
    return volvox_grid_set_frozen_rows(grid_id, value, out_len);
}

static uint8_t *vfg_native_set_frozen_cols(int64_t grid_id, int32_t value, int32_t *out_len) {
    return volvox_grid_set_frozen_cols(grid_id, value, out_len);
}

static uint8_t *vfg_native_set_editable(int64_t grid_id, int32_t mode, int32_t *out_len) {
    return volvox_grid_set_editable(grid_id, mode, out_len);
}

static uint8_t *vfg_native_set_row_sel(int64_t grid_id, int32_t row_sel, int32_t *out_len) {
    return volvox_grid_set_row_sel(grid_id, row_sel, out_len);
}

static uint8_t *vfg_native_set_col_sel(int64_t grid_id, int32_t col_sel, int32_t *out_len) {
    return volvox_grid_set_col_sel(grid_id, col_sel, out_len);
}

static uint8_t *vfg_native_select(
    int64_t grid_id, int32_t row1, int32_t col1, int32_t row2, int32_t col2, int32_t *out_len)
{
    return volvox_grid_select(grid_id, row1, col1, row2, col2, out_len);
}

/* Compat wrappers for generated dispatch (simple int set/get properties) */
VG_WRAP_STATUS_2(volvox_grid_set_scroll_bars, int64_t, grid_id, int32_t, mode)
VG_WRAP_STATUS_2(volvox_grid_set_top_row, int64_t, grid_id, int32_t, row)
VG_WRAP_STATUS_2(volvox_grid_set_left_col, int64_t, grid_id, int32_t, col)
VG_WRAP_STATUS_2(volvox_grid_set_focus_rect, int64_t, grid_id, int32_t, style)
VG_WRAP_STATUS_2(volvox_grid_set_high_light, int64_t, grid_id, int32_t, style)
static int32_t volvox_grid_set_editable_compat(int64_t grid_id, int32_t mode);
VG_WRAP_STATUS_2(volvox_grid_set_fill_style, int64_t, grid_id, int32_t, style)
VG_WRAP_STATUS_2(volvox_grid_set_word_wrap, int64_t, grid_id, int32_t, value)
VG_WRAP_STATUS_2(volvox_grid_set_selection_mode, int64_t, grid_id, int32_t, mode)
VG_WRAP_STATUS_2(volvox_grid_set_allow_selection, int64_t, grid_id, int32_t, value)
VG_WRAP_STATUS_2(volvox_grid_set_allow_big_selection, int64_t, grid_id, int32_t, value)
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
#define volvox_grid_get_col_index volvox_grid_get_col_index_compat
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
#define volvox_grid_set_resize_policy volvox_grid_set_resize_policy_compat
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
#define DISPID_VG_DATASOURCE_COMPAT   10003
#define DISPID_VG_DATAMODE_COMPAT     10004
#define DISPID_VG_DATAMEMBER_COMPAT   10005
#define DISPID_VG_VIRTUALDATA_COMPAT  10006
#define DISPID_VG_DATAREFRESH_COMPAT  10007
#define DISPID_VG_AUTORESIZE_COMPAT  10008
#define DISPID_VG_COLINDEX_COMPAT    10009

/* ════════════════════════════════════════════════════════════════ */
/* VolvoxGrid COM Object                                           */
/* ════════════════════════════════════════════════════════════════ */

/* Forward vtable declarations */
static IDispatchVtbl   g_VFGDispatchVtbl;
static IViewObjectVtbl g_VFGViewObjectVtbl;

struct VolvoxGridObject {
    IDispatchVtbl   *lpVtblDispatch;
    IViewObjectVtbl *lpVtblViewObject;
    LONG cRef;
    int64_t grid_id;   /* Active grid handle (-1 = none) */
    int32_t fixed_rows_cached;
    int32_t fixed_cols_cached;
    int32_t bound_fixed_cols;
    int32_t bound_data_col_offset;
    int32_t bound_col_width_uses_data_offset;
    int32_t has_bound_layout;
    int32_t show_combo_button_explicit;
    int32_t editable_cached;
    int32_t frozen_rows_cached;
    int32_t frozen_cols_cached;
    int32_t row_sel_cached;
    int32_t col_sel_cached;
    int32_t data_mode;
    int32_t virtual_data;
    int32_t auto_resize;
    int32_t suppress_bound_cursor_sync;
    int32_t suppress_bound_text_writes;
    int32_t *col_data_type_cache;
    int32_t col_data_type_cache_len;
    IDispatch *data_source;
    IDispatch *recordset;
    BSTR data_member;
    struct FloodColorEntry *flood_colors;
    VolvoxGridObject *registry_next;
};

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
static void vfg_release_dispatch(IDispatch **ppDisp);
static void vfg_clear_ado_binding(VolvoxGridObject *obj);
static HRESULT vfg_raise_vb_error(EXCEPINFO *pExcepInfo, WORD wCode, LPCOLESTR description);
static HRESULT vfg_dispatch_get(IDispatch *pDisp, LPCOLESTR name, VARIANT *pResult);
static HRESULT vfg_dispatch_get_indexed(IDispatch *pDisp, LPCOLESTR name, long index, VARIANT *pResult);
static HRESULT vfg_rebind_ado_source(VolvoxGridObject *obj);
static HRESULT vfg_sync_bound_state(VolvoxGridObject *obj, DISPID dispid, WORD wFlags);
static HRESULT vfg_bound_add_item(VolvoxGridObject *obj, BSTR item, int32_t index);
static HRESULT vfg_bound_remove_item(VolvoxGridObject *obj, int32_t index);
static HRESULT vfg_variant_to_display_bstr(VARIANT *pv, BSTR *pValue);
static int32_t activex_col_data_type_to_engine(int32_t dt);
static void vfg_sync_selection_cache_from_cursor(VolvoxGridObject *obj);

static VolvoxGridObject *g_vfg_objects = NULL;

static VolvoxGridObject *vfg_find_object_by_grid_id(int64_t grid_id) {
    VolvoxGridObject *obj = g_vfg_objects;
    while (obj) {
        if (obj->grid_id == grid_id) return obj;
        obj = obj->registry_next;
    }
    return NULL;
}

static void vfg_register_object(VolvoxGridObject *obj) {
    if (!obj) return;
    obj->registry_next = g_vfg_objects;
    g_vfg_objects = obj;
}

static void vfg_unregister_object(VolvoxGridObject *obj) {
    VolvoxGridObject **link = &g_vfg_objects;
    while (*link) {
        if (*link == obj) {
            *link = obj->registry_next;
            obj->registry_next = NULL;
            return;
        }
        link = &(*link)->registry_next;
    }
}

static int32_t vfg_clamp_cached_index(int32_t value, int32_t count, int32_t fallback) {
    int32_t v = value;
    if (count <= 0) return 0;
    if (v < 0) v = fallback;
    if (v < 0) v = 0;
    if (v >= count) v = count - 1;
    return v;
}

static int32_t vfg_clamp_cached_extent(int32_t value, int32_t count) {
    int32_t v = value;
    if (count <= 0) return 0;
    if (v < 0) v = 0;
    if (v > count) v = count;
    return v;
}

static void vfg_sync_selection_cache_from_cursor(VolvoxGridObject *obj) {
    int32_t rows;
    int32_t cols;
    int32_t row;
    int32_t col;
    if (!obj) return;
    rows = volvox_grid_get_rows(obj->grid_id);
    cols = volvox_grid_get_cols(obj->grid_id);
    row = volvox_grid_get_row(obj->grid_id);
    col = volvox_grid_get_col(obj->grid_id);
    obj->row_sel_cached = vfg_clamp_cached_index(row, rows, obj->row_sel_cached);
    obj->col_sel_cached = vfg_clamp_cached_index(col, cols, obj->col_sel_cached);
}

static void vfg_set_cached_col_data_type(VolvoxGridObject *obj, int32_t col, int32_t data_type) {
    int32_t new_len;
    int32_t *updated;
    if (!obj || col < 0) return;
    if (col >= obj->col_data_type_cache_len) {
        new_len = col + 1;
        if (obj->col_data_type_cache) {
            updated = HeapReAlloc(
                GetProcessHeap(),
                HEAP_ZERO_MEMORY,
                obj->col_data_type_cache,
                (SIZE_T)new_len * sizeof(int32_t));
        } else {
            updated = HeapAlloc(
                GetProcessHeap(),
                HEAP_ZERO_MEMORY,
                (SIZE_T)new_len * sizeof(int32_t));
        }
        if (!updated) return;
        obj->col_data_type_cache = updated;
        obj->col_data_type_cache_len = new_len;
    }
    obj->col_data_type_cache[col] = data_type;
}

static int32_t vfg_get_cached_col_data_type(VolvoxGridObject *obj, int32_t col) {
    if (!obj || col < 0 || col >= obj->col_data_type_cache_len) return 0;
    return obj->col_data_type_cache[col];
}

static int vfg_recordset_has_active_connection(IDispatch *recordset) {
    VARIANT vConn;
    int connected = 0;
    if (!recordset) return 0;
    VariantInit(&vConn);
    if (SUCCEEDED(vfg_dispatch_get(recordset, L"ActiveConnection", &vConn))) {
        switch (V_VT(&vConn)) {
        case VT_DISPATCH:
            connected = V_DISPATCH(&vConn) != NULL;
            break;
        case VT_UNKNOWN:
            connected = V_UNKNOWN(&vConn) != NULL;
            break;
        case VT_BSTR:
            connected = V_BSTR(&vConn) && SysStringLen(V_BSTR(&vConn)) > 0;
            break;
        default:
            connected = 0;
            break;
        }
    }
    VariantClear(&vConn);
    return connected;
}

static int32_t vfg_get_frozen_rows_cached(int64_t grid_id) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    int32_t rows = volvox_grid_get_rows(grid_id);
    return vfg_clamp_cached_extent(obj ? obj->frozen_rows_cached : 0, rows);
}

static int32_t vfg_get_frozen_cols_cached(int64_t grid_id) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    int32_t cols = volvox_grid_get_cols(grid_id);
    return vfg_clamp_cached_extent(obj ? obj->frozen_cols_cached : 0, cols);
}

static int32_t vfg_bound_uses_data_col_property_offset(VolvoxGridObject *obj) {
    return obj && obj->bound_data_col_offset > 0 && obj->bound_col_width_uses_data_offset;
}

static int32_t vfg_bound_physical_col_offset(VolvoxGridObject *obj) {
    if (!obj || !obj->has_bound_layout || obj->bound_data_col_offset <= 0) return 0;
    return obj->bound_data_col_offset;
}

static int32_t vfg_bound_method_col_to_engine(VolvoxGridObject *obj, int32_t col) {
    int32_t offset = vfg_bound_physical_col_offset(obj);
    if (col < 0 || offset <= 0) return col;
    return col + offset;
}

static int32_t vfg_is_bound_selector_header_cell(VolvoxGridObject *obj, int32_t row, int32_t col) {
    return obj && row >= 0 && row < VFG_BOUND_HEADER_ROWS && col >= 0 &&
        col < vfg_bound_physical_col_offset(obj);
}

static int32_t vfg_should_preserve_blank_bound_header(
    VolvoxGridObject *obj, int32_t row, int32_t col, BSTR text)
{
    VARIANT vFields, vField, vName;
    HRESULT hr;
    int matched = 0;
    if (!obj || !obj->recordset || !text) return 0;
    if (!vfg_is_bound_selector_header_cell(obj, row, col)) return 0;
    VariantInit(&vFields);
    hr = vfg_dispatch_get(obj->recordset, L"Fields", &vFields);
    if (FAILED(hr) || V_VT(&vFields) != VT_DISPATCH || !V_DISPATCH(&vFields)) {
        VariantClear(&vFields);
        return 0;
    }
    VariantInit(&vField);
    hr = vfg_dispatch_get_indexed(V_DISPATCH(&vFields), L"Item", 0, &vField);
    if (SUCCEEDED(hr) && V_VT(&vField) == VT_DISPATCH && V_DISPATCH(&vField)) {
        VariantInit(&vName);
        hr = vfg_dispatch_get(V_DISPATCH(&vField), L"Name", &vName);
        if (SUCCEEDED(hr) && V_VT(&vName) == VT_BSTR && V_BSTR(&vName)) {
            matched = _wcsicmp(V_BSTR(&vName), text) == 0;
        }
        VariantClear(&vName);
    }
    VariantClear(&vField);
    VariantClear(&vFields);
    return matched;
}

static int32_t vfg_col_property_from_engine(VolvoxGridObject *obj, int32_t col) {
    if (obj && vfg_bound_uses_data_col_property_offset(obj) && col >= obj->bound_data_col_offset) {
        return col - obj->bound_data_col_offset;
    }
    return col;
}

static int32_t vfg_col_engine_from_property(VolvoxGridObject *obj, int32_t col) {
    if (obj && vfg_bound_uses_data_col_property_offset(obj) && col >= 0) {
        return col + obj->bound_data_col_offset;
    }
    return col;
}

static int32_t vfg_get_col_cached(int64_t grid_id) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    int32_t cols = volvox_grid_get_cols(grid_id);
    int32_t fallback = volvox_grid_get_col(grid_id);
    int32_t engine_col = vfg_clamp_cached_index(fallback, cols, fallback);
    if (obj && obj->has_bound_layout && obj->bound_data_col_offset > 0 &&
        obj->col_sel_cached >= 0 && obj->col_sel_cached < obj->bound_data_col_offset) {
        return obj->col_sel_cached;
    }
    return vfg_col_property_from_engine(obj, engine_col);
}

static int32_t vfg_get_left_col_cached(int64_t grid_id) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    int32_t cols = volvox_grid_get_cols(grid_id);
    int32_t fallback = volvox_grid_get_left_col(grid_id);
    int32_t engine_col = vfg_clamp_cached_index(fallback, cols, fallback);
    return vfg_col_property_from_engine(obj, engine_col);
}

static int32_t vfg_get_row_sel_cached(int64_t grid_id) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    int32_t rows = volvox_grid_get_rows(grid_id);
    int32_t fallback = volvox_grid_get_row(grid_id);
    return vfg_clamp_cached_index(obj ? obj->row_sel_cached : fallback, rows, fallback);
}

static int32_t vfg_get_col_sel_cached(int64_t grid_id) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    int32_t cols = volvox_grid_get_cols(grid_id);
    int32_t fallback = volvox_grid_get_col(grid_id);
    int32_t engine_col = vfg_clamp_cached_index(obj ? obj->col_sel_cached : fallback, cols, fallback);
    return vfg_col_property_from_engine(obj, engine_col);
}

static int32_t vfg_get_editable_cached(int64_t grid_id) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    return obj ? obj->editable_cached : 0;
}

static int32_t volvox_grid_get_frozen_rows_cached(int64_t grid_id) {
    return vfg_get_frozen_rows_cached(grid_id);
}

static int32_t volvox_grid_get_frozen_cols_cached(int64_t grid_id) {
    return vfg_get_frozen_cols_cached(grid_id);
}

static int32_t volvox_grid_get_col_cached(int64_t grid_id) {
    return vfg_get_col_cached(grid_id);
}

static int32_t volvox_grid_get_left_col_cached(int64_t grid_id) {
    return vfg_get_left_col_cached(grid_id);
}

static int32_t volvox_grid_get_row_sel_cached(int64_t grid_id) {
    return vfg_get_row_sel_cached(grid_id);
}

static int32_t volvox_grid_get_col_sel_cached(int64_t grid_id) {
    return vfg_get_col_sel_cached(grid_id);
}

static int32_t volvox_grid_get_editable_cached(int64_t grid_id) {
    return vfg_get_editable_cached(grid_id);
}

static int32_t volvox_grid_set_rows_compat(int64_t grid_id, int32_t rows) {
    int32_t out_len = 0;
    uint8_t *out = vfg_native_set_rows(grid_id, rows, &out_len);
    int32_t status = vfg_take_status_response(out);
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    if (obj) {
        int32_t count = volvox_grid_get_rows(grid_id);
        obj->frozen_rows_cached = vfg_clamp_cached_extent(obj->frozen_rows_cached, count);
        obj->row_sel_cached = vfg_clamp_cached_index(obj->row_sel_cached, count, volvox_grid_get_row(grid_id));
    }
    return status;
}

static int32_t volvox_grid_set_cols_compat(int64_t grid_id, int32_t cols) {
    int32_t out_len = 0;
    uint8_t *out = vfg_native_set_cols(grid_id, cols, &out_len);
    int32_t status = vfg_take_status_response(out);
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    if (obj) {
        int32_t count = volvox_grid_get_cols(grid_id);
        obj->frozen_cols_cached = vfg_clamp_cached_extent(obj->frozen_cols_cached, count);
        obj->col_sel_cached = vfg_clamp_cached_index(obj->col_sel_cached, count, volvox_grid_get_col(grid_id));
    }
    return status;
}

static int32_t volvox_grid_set_row_compat(int64_t grid_id, int32_t row) {
    int32_t out_len = 0;
    uint8_t *out = vfg_native_set_row(grid_id, row, &out_len);
    int32_t status = vfg_take_status_response(out);
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    if (obj) {
        int32_t rows = volvox_grid_get_rows(grid_id);
        obj->row_sel_cached = vfg_clamp_cached_index(volvox_grid_get_row(grid_id), rows, row);
    }
    return status;
}

static int32_t volvox_grid_set_col_compat(int64_t grid_id, int32_t col) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    int32_t engine_col = vfg_col_engine_from_property(obj, col);
    int32_t out_len = 0;
    uint8_t *out = vfg_native_set_col(grid_id, engine_col, &out_len);
    int32_t status = vfg_take_status_response(out);
    if (obj) {
        int32_t cols = volvox_grid_get_cols(grid_id);
        if (col >= 0 && col < vfg_bound_physical_col_offset(obj)) {
            obj->col_sel_cached = col;
        } else {
            obj->col_sel_cached = vfg_clamp_cached_index(volvox_grid_get_col(grid_id), cols, engine_col);
        }
    }
    return status;
}

static int32_t volvox_grid_set_frozen_rows_compat(int64_t grid_id, int32_t value) {
    int32_t out_len = 0;
    uint8_t *out = vfg_native_set_frozen_rows(grid_id, value, &out_len);
    int32_t status = vfg_take_status_response(out);
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    if (obj) {
        obj->frozen_rows_cached = value;
    }
    return status;
}

static int32_t volvox_grid_set_frozen_cols_compat(int64_t grid_id, int32_t value) {
    int32_t out_len = 0;
    uint8_t *out = vfg_native_set_frozen_cols(grid_id, value, &out_len);
    int32_t status = vfg_take_status_response(out);
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    if (obj) {
        obj->frozen_cols_cached = value;
    }
    return status;
}

static int32_t volvox_grid_set_editable_compat(int64_t grid_id, int32_t mode) {
    int32_t out_len = 0;
    uint8_t *out = vfg_native_set_editable(grid_id, mode, &out_len);
    int32_t status = vfg_take_status_response(out);
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    if (obj) {
        obj->editable_cached = mode;
    }
    return status;
}

static int32_t volvox_grid_set_row_sel_compat(int64_t grid_id, int32_t row_sel) {
    int32_t out_len = 0;
    uint8_t *out = vfg_native_set_row_sel(grid_id, row_sel, &out_len);
    int32_t status = vfg_take_status_response(out);
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    if (obj) {
        obj->row_sel_cached = row_sel;
    }
    return status;
}

static int32_t volvox_grid_set_col_sel_compat(int64_t grid_id, int32_t col_sel) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    int32_t engine_col_sel = vfg_col_engine_from_property(obj, col_sel);
    int32_t out_len = 0;
    uint8_t *out = vfg_native_set_col_sel(grid_id, engine_col_sel, &out_len);
    int32_t status = vfg_take_status_response(out);
    if (obj) {
        obj->col_sel_cached = engine_col_sel;
    }
    return status;
}

static int32_t volvox_grid_select_compat(
    int64_t grid_id, int32_t row1, int32_t col1, int32_t row2, int32_t col2)
{
    int32_t out_len = 0;
    uint8_t *out = vfg_native_select(grid_id, row1, col1, row2, col2, &out_len);
    int32_t status = vfg_take_status_response(out);
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    if (obj) {
        obj->row_sel_cached = row2;
        obj->col_sel_cached = col2;
    }
    return status;
}

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
        vfg_unregister_object(obj);
        vfg_clear_flood_color_cache(obj);
        vfg_clear_ado_binding(obj);
        if (obj->col_data_type_cache) {
            HeapFree(GetProcessHeap(), 0, obj->col_data_type_cache);
        }
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
        if (!found && _wcsicmp(rgszNames[i], L"DataSource") == 0) {
            rgDispId[i] = DISPID_VG_DATASOURCE_COMPAT;
            found = TRUE;
        }
        if (!found && _wcsicmp(rgszNames[i], L"DataMode") == 0) {
            rgDispId[i] = DISPID_VG_DATAMODE_COMPAT;
            found = TRUE;
        }
        if (!found && _wcsicmp(rgszNames[i], L"DataMember") == 0) {
            rgDispId[i] = DISPID_VG_DATAMEMBER_COMPAT;
            found = TRUE;
        }
        if (!found && _wcsicmp(rgszNames[i], L"VirtualData") == 0) {
            rgDispId[i] = DISPID_VG_VIRTUALDATA_COMPAT;
            found = TRUE;
        }
        if (!found && _wcsicmp(rgszNames[i], L"DataRefresh") == 0) {
            rgDispId[i] = DISPID_VG_DATAREFRESH_COMPAT;
            found = TRUE;
        }
        if (!found && _wcsicmp(rgszNames[i], L"AutoResize") == 0) {
            rgDispId[i] = DISPID_VG_AUTORESIZE_COMPAT;
            found = TRUE;
        }
        if (!found && _wcsicmp(rgszNames[i], L"ColIndex") == 0) {
            rgDispId[i] = DISPID_VG_COLINDEX_COMPAT;
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


static int32_t vfg_get_screen_dpi_x(void) {
    HDC hdc = GetDC(NULL);
    int32_t dpi = VFG_DEFAULT_DPI;
    if (hdc) {
        int cap = GetDeviceCaps(hdc, LOGPIXELSX);
        if (cap > 0) dpi = cap;
        ReleaseDC(NULL, hdc);
    }
    return dpi;
}

static int32_t vfg_get_screen_dpi_y(void) {
    HDC hdc = GetDC(NULL);
    int32_t dpi = VFG_DEFAULT_DPI;
    if (hdc) {
        int cap = GetDeviceCaps(hdc, LOGPIXELSY);
        if (cap > 0) dpi = cap;
        ReleaseDC(NULL, hdc);
    }
    return dpi;
}

static int32_t vfg_px_to_twips_x(int32_t px) {
    if (px < 0) return px;
    return MulDiv(px, 1440, vfg_get_screen_dpi_x());
}

static int32_t vfg_px_to_twips_y(int32_t px) {
    if (px < 0) return px;
    return MulDiv(px, 1440, vfg_get_screen_dpi_y());
}

static int32_t vfg_twips_to_px_x(int32_t twips) {
    if (twips < 0) return twips;
    return MulDiv(twips, vfg_get_screen_dpi_x(), 1440);
}

static int32_t vfg_twips_to_px_y(int32_t twips) {
    if (twips < 0) return twips;
    return MulDiv(twips, vfg_get_screen_dpi_y(), 1440);
}

static int32_t *vfg_capture_col_widths(int64_t gid, int32_t cols) {
    int32_t *widths;
    if (cols <= 0) return NULL;
    widths = (int32_t *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(int32_t) * cols);
    if (!widths) return NULL;
    for (int32_t col = 0; col < cols; ++col) {
        widths[col] = volvox_grid_get_col_width(gid, col);
    }
    return widths;
}

static void vfg_apply_bound_col_widths(
    int64_t gid,
    int32_t dataColOffset,
    int32_t fieldCount,
    const int32_t *preserved_widths,
    int32_t preserved_cols,
    int32_t preserved_data_col_offset)
{
    for (int32_t col = 0; col < dataColOffset; ++col) {
        int32_t width = VFG_BOUND_SELECTOR_COL_WIDTH_PX;
        if (preserved_widths && col < preserved_data_col_offset &&
            col < preserved_cols && preserved_widths[col] > 0) {
            width = preserved_widths[col];
        }
        volvox_grid_set_col_width(gid, col, width);
    }
    for (int32_t field = 0; field < fieldCount; ++field) {
        int32_t oldCol = preserved_data_col_offset + field;
        int32_t newCol = dataColOffset + field;
        int32_t width = -1;
        if (preserved_widths && oldCol >= 0 && oldCol < preserved_cols &&
            preserved_widths[oldCol] > 0) {
            width = preserved_widths[oldCol];
        }
        if (width > 0) {
            volvox_grid_set_col_width(gid, newCol, width);
        }
    }
}

static int32_t vfg_measure_grid_cell_text_width_px(
    int64_t gid,
    int32_t row,
    int32_t col,
    const uint8_t *font_name_ptr,
    int32_t font_name_len,
    float font_size)
{
    int32_t best_width = 0;
    int32_t text_len = 0;
    uint8_t *text = volvox_grid_get_text_matrix(gid, row, col, &text_len);
    if (!text || text_len <= 0) {
        if (text) volvox_grid_free(text, text_len);
        return 0;
    }
    {
        int32_t start = 0;
        for (int32_t i = 0; i <= text_len; ++i) {
            int at_end = (i == text_len);
            int line_break = (!at_end && (text[i] == 13 || text[i] == 10));
            if (!at_end && !line_break) continue;
            if (i > start) {
                float width = 0.0f;
                float height = 0.0f;
                gdi_measure_text(
                    text + start,
                    i - start,
                    font_name_ptr,
                    font_name_len,
                    font_size,
                    0,
                    0,
                    -1.0f,
                    &width,
                    &height,
                    NULL);
                if (width > 0.0f) {
                    int32_t measured = (int32_t)(width + 0.999f);
                    if (measured > best_width) best_width = measured;
                }
            }
            if (!at_end && text[i] == 13 && i + 1 < text_len && text[i + 1] == 10) {
                ++i;
            }
            start = i + 1;
        }
    }
    volvox_grid_free(text, text_len);
    return best_width;
}

static void vfg_apply_bound_autosize_compat_widths(
    int64_t gid,
    int32_t dataColOffset,
    int32_t colFrom,
    int32_t colTo)
{
    int32_t rows = volvox_grid_get_rows(gid);
    int32_t totalCols = volvox_grid_get_cols(gid);
    int32_t font_name_len = 0;
    uint8_t *font_name = NULL;
    float font_size = volvox_grid_get_font_size(gid);
    if (rows <= 0 || totalCols <= 0 || colTo < colFrom) return;
    if (colFrom < 0) colFrom = 0;
    if (colTo >= totalCols) colTo = totalCols - 1;
    if (colFrom > colTo) return;
    if (dataColOffset > 0 && colFrom < dataColOffset) {
        int32_t selectorTo = colTo < dataColOffset ? colTo : (dataColOffset - 1);
        for (int32_t col = colFrom; col <= selectorTo; ++col) {
            volvox_grid_set_col_width(gid, col, VFG_BOUND_SELECTOR_COL_WIDTH_PX);
        }
    }
    if (colTo < dataColOffset) return;
    if (font_size <= 0.0f) font_size = 13.0f;
    font_name = volvox_grid_get_font_name(gid, &font_name_len);
    for (int32_t col = colFrom < dataColOffset ? dataColOffset : colFrom; col <= colTo; ++col) {
        int32_t basis_px = 0;
        for (int32_t row = 0; row < rows; ++row) {
            int32_t text_px = vfg_measure_grid_cell_text_width_px(
                gid, row, col, font_name, font_name_len, font_size);
            if (text_px > basis_px) basis_px = text_px;
        }
        {
            int32_t width_px = basis_px + VFG_BOUND_AUTOSIZE_TEXT_PAD_PX;
            if (width_px < VFG_BOUND_AUTOSIZE_MIN_COL_WIDTH_PX) {
                width_px = VFG_BOUND_AUTOSIZE_MIN_COL_WIDTH_PX;
            }
            volvox_grid_set_col_width(gid, col, width_px);
        }
    }
    if (font_name) volvox_grid_free(font_name, font_name_len);
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


static void vfg_release_dispatch(IDispatch **ppDisp) {
    if (ppDisp && *ppDisp) {
        IDispatch_Release(*ppDisp);
        *ppDisp = NULL;
    }
}

static void vfg_set_bstr_copy(BSTR *target, BSTR value) {
    if (!target) return;
    if (*target) {
        SysFreeString(*target);
        *target = NULL;
    }
    if (value) {
        *target = SysAllocStringLen(value, SysStringLen(value));
    }
}

static HRESULT vfg_get_dispid(IDispatch *pDisp, LPCOLESTR name, DISPID *pDispid) {
    LPOLESTR names[1];
    if (!pDisp || !name || !pDispid) return E_POINTER;
    names[0] = (LPOLESTR)name;
    return IDispatch_GetIDsOfNames(pDisp, &IID_NULL, names, 1, LOCALE_USER_DEFAULT, pDispid);
}

static HRESULT vfg_get_dispid_bstr(IDispatch *pDisp, BSTR name, DISPID *pDispid) {
    if (!name) return DISP_E_UNKNOWNNAME;
    return vfg_get_dispid(pDisp, name, pDispid);
}

static HRESULT vfg_dispatch_get_by_dispid(IDispatch *pDisp, DISPID dispid, VARIANT *pResult) {
    DISPPARAMS dp = { NULL, NULL, 0, 0 };
    EXCEPINFO ei;
    HRESULT hr;
    if (!pDisp || !pResult) return E_POINTER;
    VariantInit(pResult);
    memset(&ei, 0, sizeof(ei));
    hr = IDispatch_Invoke(
        pDisp,
        dispid,
        &IID_NULL,
        LOCALE_USER_DEFAULT,
        DISPATCH_PROPERTYGET,
        &dp,
        pResult,
        &ei,
        NULL);
    if (hr == DISP_E_EXCEPTION) {
        if (ei.scode) hr = ei.scode;
        else if (ei.wCode) hr = MAKE_HRESULT(SEVERITY_ERROR, FACILITY_DISPATCH, ei.wCode);
    }
    SysFreeString(ei.bstrSource);
    SysFreeString(ei.bstrDescription);
    SysFreeString(ei.bstrHelpFile);
    return hr;
}

static HRESULT vfg_dispatch_get(IDispatch *pDisp, LPCOLESTR name, VARIANT *pResult) {
    DISPID dispid = 0;
    HRESULT hr = vfg_get_dispid(pDisp, name, &dispid);
    if (FAILED(hr)) return hr;
    return vfg_dispatch_get_by_dispid(pDisp, dispid, pResult);
}

static void vfg_free_excepinfo(EXCEPINFO *ei) {
    if (!ei) return;
    SysFreeString(ei->bstrSource);
    SysFreeString(ei->bstrDescription);
    SysFreeString(ei->bstrHelpFile);
}

static HRESULT vfg_map_excepinfo(HRESULT hr, EXCEPINFO *ei) {
    if (hr == DISP_E_EXCEPTION && ei) {
        if (ei->scode) hr = ei->scode;
        else if (ei->wCode) hr = MAKE_HRESULT(SEVERITY_ERROR, FACILITY_DISPATCH, ei->wCode);
    }
    vfg_free_excepinfo(ei);
    return hr;
}

static HRESULT vfg_dispatch_get_indexed(IDispatch *pDisp, LPCOLESTR name, long index, VARIANT *pResult) {
    DISPID dispid = 0;
    VARIANT arg;
    DISPPARAMS dp;
    EXCEPINFO ei;
    HRESULT hr = vfg_get_dispid(pDisp, name, &dispid);
    if (FAILED(hr)) return hr;
    if (!pResult) return E_POINTER;
    VariantInit(&arg);
    arg.vt = VT_I4;
    arg.lVal = index;
    VariantInit(pResult);
    memset(&ei, 0, sizeof(ei));
    dp.rgvarg = &arg;
    dp.rgdispidNamedArgs = NULL;
    dp.cArgs = 1;
    dp.cNamedArgs = 0;
    hr = IDispatch_Invoke(
        pDisp,
        dispid,
        &IID_NULL,
        LOCALE_USER_DEFAULT,
        DISPATCH_PROPERTYGET,
        &dp,
        pResult,
        &ei,
        NULL);
    return vfg_map_excepinfo(hr, &ei);
}

static HRESULT vfg_dispatch_call(IDispatch *pDisp, LPCOLESTR name) {
    DISPID dispid = 0;
    DISPPARAMS dp = { NULL, NULL, 0, 0 };
    EXCEPINFO ei;
    HRESULT hr = vfg_get_dispid(pDisp, name, &dispid);
    if (FAILED(hr)) return hr;
    memset(&ei, 0, sizeof(ei));
    hr = IDispatch_Invoke(
        pDisp,
        dispid,
        &IID_NULL,
        LOCALE_USER_DEFAULT,
        DISPATCH_METHOD,
        &dp,
        NULL,
        &ei,
        NULL);
    return vfg_map_excepinfo(hr, &ei);
}

static HRESULT vfg_dispatch_put_by_dispid(IDispatch *pDisp, DISPID dispid, VARIANT *pValue) {
    DISPID named = DISPID_PROPERTYPUT;
    DISPPARAMS dp;
    EXCEPINFO ei;
    HRESULT hr;
    if (!pDisp || !pValue) return E_POINTER;
    memset(&ei, 0, sizeof(ei));
    dp.rgvarg = pValue;
    dp.rgdispidNamedArgs = &named;
    dp.cArgs = 1;
    dp.cNamedArgs = 1;
    hr = IDispatch_Invoke(
        pDisp,
        dispid,
        &IID_NULL,
        LOCALE_USER_DEFAULT,
        DISPATCH_PROPERTYPUT,
        &dp,
        NULL,
        &ei,
        NULL);
    return vfg_map_excepinfo(hr, &ei);
}

static HRESULT vfg_dispatch_put(IDispatch *pDisp, LPCOLESTR name, VARIANT *pValue) {
    DISPID dispid = 0;
    HRESULT hr = vfg_get_dispid(pDisp, name, &dispid);
    if (FAILED(hr)) return hr;
    return vfg_dispatch_put_by_dispid(pDisp, dispid, pValue);
}

static HRESULT vfg_dispatch_put_i4(IDispatch *pDisp, LPCOLESTR name, int32_t value) {
    VARIANT v;
    VariantInit(&v);
    V_VT(&v) = VT_I4;
    V_I4(&v) = value;
    return vfg_dispatch_put(pDisp, name, &v);
}

static HRESULT vfg_recordset_get_field_count(IDispatch *pRS, long *pFieldCount) {
    VARIANT vFields, vCount;
    HRESULT hr;
    if (!pFieldCount) return E_POINTER;
    *pFieldCount = 0;
    VariantInit(&vFields);
    hr = vfg_dispatch_get(pRS, L"Fields", &vFields);
    if (FAILED(hr) || V_VT(&vFields) != VT_DISPATCH || !V_DISPATCH(&vFields)) {
        VariantClear(&vFields);
        return FAILED(hr) ? hr : E_FAIL;
    }
    VariantInit(&vCount);
    hr = vfg_dispatch_get(V_DISPATCH(&vFields), L"Count", &vCount);
    if (SUCCEEDED(hr)) {
        if (V_VT(&vCount) == VT_I4) *pFieldCount = V_I4(&vCount);
        else if (V_VT(&vCount) == VT_I2) *pFieldCount = V_I2(&vCount);
        else variant_to_i4(&vCount, (int32_t *)pFieldCount);
    }
    VariantClear(&vCount);
    VariantClear(&vFields);
    return hr;
}

static HRESULT vfg_recordset_get_record_count(IDispatch *pRS, long *pRecordCount) {
    VARIANT vCount;
    HRESULT hr;
    if (!pRecordCount) return E_POINTER;
    *pRecordCount = -1;
    VariantInit(&vCount);
    hr = vfg_dispatch_get(pRS, L"RecordCount", &vCount);
    if (SUCCEEDED(hr)) {
        if (V_VT(&vCount) == VT_I4) *pRecordCount = V_I4(&vCount);
        else if (V_VT(&vCount) == VT_I2) *pRecordCount = V_I2(&vCount);
        else variant_to_i4(&vCount, (int32_t *)pRecordCount);
    }
    VariantClear(&vCount);
    return hr;
}

static HRESULT vfg_recordset_get_absolute_position(IDispatch *pRS, long *pPos) {
    VARIANT vPos;
    HRESULT hr;
    if (!pPos) return E_POINTER;
    *pPos = -1;
    VariantInit(&vPos);
    hr = vfg_dispatch_get(pRS, L"AbsolutePosition", &vPos);
    if (SUCCEEDED(hr)) {
        if (V_VT(&vPos) == VT_I4) *pPos = V_I4(&vPos);
        else if (V_VT(&vPos) == VT_I2) *pPos = V_I2(&vPos);
        else variant_to_i4(&vPos, (int32_t *)pPos);
    }
    VariantClear(&vPos);
    return hr;
}

static HRESULT vfg_recordset_get_current_key(IDispatch *pRS, BSTR *pText) {
    VARIANT vFields, vField, vValue;
    HRESULT hr;
    if (!pText) return E_POINTER;
    *pText = NULL;
    VariantInit(&vFields);
    hr = vfg_dispatch_get(pRS, L"Fields", &vFields);
    if (FAILED(hr) || V_VT(&vFields) != VT_DISPATCH || !V_DISPATCH(&vFields)) {
        VariantClear(&vFields);
        return FAILED(hr) ? hr : E_FAIL;
    }
    VariantInit(&vField);
    hr = vfg_dispatch_get_indexed(V_DISPATCH(&vFields), L"Item", 0, &vField);
    if (FAILED(hr) || V_VT(&vField) != VT_DISPATCH || !V_DISPATCH(&vField)) {
        VariantClear(&vField);
        VariantClear(&vFields);
        return FAILED(hr) ? hr : E_FAIL;
    }
    VariantInit(&vValue);
    hr = vfg_dispatch_get(V_DISPATCH(&vField), L"Value", &vValue);
    if (SUCCEEDED(hr)) hr = vfg_variant_to_display_bstr(&vValue, pText);
    VariantClear(&vValue);
    VariantClear(&vField);
    VariantClear(&vFields);
    return hr;
}

static int32_t vfg_bound_selector_cols(VolvoxGridObject *obj) {
    if (!obj) return 0;
    if (obj->has_bound_layout) {
        return obj->bound_data_col_offset > 0 ? 1 : 0;
    }
    /* FlexGrid adds the leading selector column unless the caller
     * explicitly forced FixedCols = 0 before the first bind. */
    return obj->fixed_cols_cached == 0 ? 0 : 1;
}

static int32_t vfg_bound_allows_zero_fixed_cols(VolvoxGridObject *obj) {
    if (!obj || !obj->has_bound_layout) return 0;
    if (obj->bound_data_col_offset <= 0) return 1;
    if (obj->data_mode != 0) return 0;
    if (!obj->recordset || !obj->data_source) return 0;
    return obj->recordset == obj->data_source;
}

static int32_t vfg_bound_effective_fixed_cols(
    VolvoxGridObject *obj, int32_t totalCols, int32_t requested)
{
    int32_t minFixedCols = vfg_bound_selector_cols(obj);
    int32_t v = requested;
    if (minFixedCols > 0 && v <= 0 && vfg_bound_allows_zero_fixed_cols(obj)) {
        minFixedCols = 0;
    }
    if (totalCols <= 0) return 0;
    if (v < minFixedCols) v = minFixedCols;
    if (v < 0) v = 0;
    if (v > totalCols) v = totalCols;
    return v;
}

static void vfg_bound_apply_visible_state(
    VolvoxGridObject *obj,
    int32_t preserve_existing,
    int32_t saved_row,
    int32_t saved_col,
    int32_t saved_row_sel,
    int32_t saved_col_sel,
    int32_t saved_top_row,
    int32_t saved_left_col)
{
    int32_t rows;
    int32_t cols;
    int32_t default_row;
    int32_t default_prop_col;
    int32_t default_engine_col;
    int32_t row;
    int32_t row_sel;
    int32_t prop_col;
    int32_t prop_col_sel;
    int32_t top_row;
    int32_t left_prop_col;
    int32_t left_engine_col;
    int32_t engine_col;
    int32_t engine_col_sel;

    if (!obj) return;
    rows = volvox_grid_get_rows(obj->grid_id);
    cols = volvox_grid_get_cols(obj->grid_id);
    if (rows <= 0 || cols <= 0) return;

    default_row = rows > VFG_BOUND_HEADER_ROWS ? VFG_BOUND_HEADER_ROWS : rows - 1;
    default_prop_col = obj->bound_col_width_uses_data_offset ? 0 : obj->bound_data_col_offset;
    if (default_prop_col < 0) default_prop_col = 0;

    default_engine_col = vfg_col_engine_from_property(obj, default_prop_col);
    default_engine_col = vfg_clamp_cached_index(default_engine_col, cols, default_engine_col);
    default_prop_col = vfg_col_property_from_engine(obj, default_engine_col);

    row = vfg_clamp_cached_index(preserve_existing ? saved_row : default_row, rows, default_row);
    row_sel = vfg_clamp_cached_index(
        preserve_existing ? saved_row_sel : row,
        rows,
        row);
    prop_col = preserve_existing ? saved_col : default_prop_col;
    prop_col_sel = preserve_existing ? saved_col_sel : prop_col;
    top_row = vfg_clamp_cached_index(
        preserve_existing ? saved_top_row : row,
        rows,
        row);
    left_prop_col = preserve_existing ? saved_left_col : default_prop_col;

    engine_col = vfg_col_engine_from_property(obj, prop_col);
    engine_col = vfg_clamp_cached_index(engine_col, cols, default_engine_col);
    prop_col = vfg_col_property_from_engine(obj, engine_col);

    engine_col_sel = vfg_col_engine_from_property(obj, prop_col_sel);
    engine_col_sel = vfg_clamp_cached_index(engine_col_sel, cols, engine_col);
    prop_col_sel = vfg_col_property_from_engine(obj, engine_col_sel);

    left_engine_col = vfg_col_engine_from_property(obj, left_prop_col);
    left_engine_col = vfg_clamp_cached_index(left_engine_col, cols, engine_col);

    volvox_grid_set_row(obj->grid_id, row);
    volvox_grid_set_col(obj->grid_id, prop_col);
    volvox_grid_set_row_sel(obj->grid_id, row_sel);
    volvox_grid_set_col_sel(obj->grid_id, prop_col_sel);
    volvox_grid_set_top_row(obj->grid_id, top_row);
    volvox_grid_set_left_col(obj->grid_id, left_engine_col);
}

static HRESULT vfg_bound_sync_cursor(VolvoxGridObject *obj) {
    long pos = -1;
    int32_t rows;
    int32_t target_row = -1;
    int32_t target_prop_col;
    HRESULT hr;
    BSTR key = NULL;

    if (!obj || !obj->recordset) return S_OK;

    hr = vfg_recordset_get_absolute_position(obj->recordset, &pos);
    if (SUCCEEDED(hr) && pos >= 1) {
        target_row = VFG_BOUND_HEADER_ROWS + (int32_t)pos - 1;
    }

    hr = vfg_recordset_get_current_key(obj->recordset, &key);
    if (SUCCEEDED(hr) && key) {
        int32_t data_col = obj->bound_data_col_offset;
        int32_t data_start_row = VFG_BOUND_HEADER_ROWS;
        int utf8len = 0;
        char *utf8 = bstr_to_utf8(key, &utf8len);
        if (utf8 && utf8len > 0) {
            rows = volvox_grid_get_rows(obj->grid_id);
            for (int32_t row = data_start_row; row < rows; ++row) {
                int32_t cell_len = 0;
                uint8_t *cell = volvox_grid_get_text_matrix(obj->grid_id, row, data_col, &cell_len);
                int matched = cell && cell_len == utf8len && memcmp(cell, utf8, (size_t)utf8len) == 0;
                if (cell) volvox_grid_free(cell, cell_len);
                if (matched) {
                    target_row = row;
                    break;
                }
            }
        }
        if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
    }
    if (key) SysFreeString(key);

    rows = volvox_grid_get_rows(obj->grid_id);
    if (rows <= 0 || target_row < 0) return S_OK;

    target_row = vfg_clamp_cached_index(target_row, rows, VFG_BOUND_HEADER_ROWS);
    target_prop_col = obj->bound_col_width_uses_data_offset ? 0 : obj->bound_data_col_offset;
    if (target_prop_col < 0) target_prop_col = 0;

    volvox_grid_set_row(obj->grid_id, target_row);
    volvox_grid_set_col(obj->grid_id, target_prop_col);
    volvox_grid_set_row_sel(obj->grid_id, target_row);
    volvox_grid_set_col_sel(obj->grid_id, target_prop_col);
    return S_OK;
}

static int32_t vfg_bound_materialized_row_count(VolvoxGridObject *obj) {
    int32_t rows;
    int32_t count = 0;
    if (!obj) return 0;
    rows = volvox_grid_get_rows(obj->grid_id);
    if (rows <= 0) return 0;
    count = rows < VFG_BOUND_HEADER_ROWS ? rows : VFG_BOUND_HEADER_ROWS;
    for (int32_t row = VFG_BOUND_HEADER_ROWS; row < rows; ++row) {
        if (!volvox_grid_get_is_subtotal(obj->grid_id, row)) {
            count++;
        }
    }
    return count;
}

static HRESULT vfg_sync_bound_state(VolvoxGridObject *obj, DISPID dispid, WORD wFlags) {
    long fieldCount = 0;
    long recordCount = -1;
    int32_t expectedCols;
    int32_t expectedRows;
    int32_t materializedRows;
    HRESULT hr;
    (void)wFlags;
    if (!obj || !obj->recordset || !obj->data_source) return S_OK;
    switch (dispid) {
    case DISPID_VG_COLINDEX_COMPAT:
    case DISPID_VG_DATASOURCE_COMPAT:
    case DISPID_VG_DATAMODE_COMPAT:
    case DISPID_VG_DATAMEMBER_COMPAT:
    case DISPID_VG_VIRTUALDATA_COMPAT:
    case DISPID_VG_AUTORESIZE_COMPAT:
    case DISPID_VG_DATAREFRESH_COMPAT:
        return S_OK;
    default:
        break;
    }
    hr = vfg_recordset_get_field_count(obj->recordset, &fieldCount);
    if (SUCCEEDED(hr)) {
        expectedCols = vfg_bound_selector_cols(obj) +
            (fieldCount > 0 ? (int32_t)fieldCount : 0);
        if (volvox_grid_get_cols(obj->grid_id) != expectedCols) {
            hr = vfg_rebind_ado_source(obj);
            if (FAILED(hr)) return hr;
        }
    }
    hr = vfg_recordset_get_record_count(obj->recordset, &recordCount);
    if (SUCCEEDED(hr) && recordCount >= 0) {
        expectedRows = VFG_BOUND_HEADER_ROWS + (int32_t)recordCount;
        if (expectedRows < VFG_BOUND_HEADER_ROWS) expectedRows = VFG_BOUND_HEADER_ROWS;
        materializedRows = vfg_bound_materialized_row_count(obj);
        if (materializedRows != expectedRows) {
            hr = vfg_rebind_ado_source(obj);
            if (FAILED(hr)) return hr;
        }
    }
    if ((wFlags & DISPATCH_PROPERTYGET) &&
        obj->data_mode != 0 &&
        !obj->suppress_bound_cursor_sync) {
        switch (dispid) {
        case DISPID_VG_ROW:
        case DISPID_VG_COL:
        case DISPID_VG_ROWSEL:
        case DISPID_VG_COLSEL:
            return vfg_bound_sync_cursor(obj);
        default:
            break;
        }
    }
    return S_OK;
}

static HRESULT vfg_bound_add_item(VolvoxGridObject *obj, BSTR item, int32_t index) {
    VARIANT vFields;
    HRESULT hr;
    long fieldCount = 0;
    int32_t visual_offset = 0;
    char *utf8 = NULL;
    int utf8len = 0;
    const char *p;
    const char *end;
    if (!obj || !obj->recordset) return S_FALSE;
    if (index >= 0) return S_FALSE;
    hr = vfg_recordset_get_field_count(obj->recordset, &fieldCount);
    if (FAILED(hr) || fieldCount <= 0) return FAILED(hr) ? hr : S_FALSE;
    visual_offset = vfg_bound_physical_col_offset(obj);
    hr = vfg_dispatch_call(obj->recordset, L"AddNew");
    if (FAILED(hr)) return hr;
    VariantInit(&vFields);
    hr = vfg_dispatch_get(obj->recordset, L"Fields", &vFields);
    if (FAILED(hr) || V_VT(&vFields) != VT_DISPATCH || !V_DISPATCH(&vFields)) {
        VariantClear(&vFields);
        return FAILED(hr) ? hr : E_FAIL;
    }
    utf8 = bstr_to_utf8(item, &utf8len);
    p = utf8 ? utf8 : "";
    end = utf8 ? (utf8 + utf8len) : p;
    for (int32_t skip = 0; skip < visual_offset; ++skip) {
        while (p < end && *p != '	') p++;
        if (p < end && *p == '	') p++;
    }
    for (long col = 0; col < fieldCount; ++col) {
        const char *start = p;
        VARIANT vField;
        BSTR cell;
        VARIANT vValue;
        while (p < end && *p != '	') p++;
        cell = utf8_to_bstr(start, (int)(p - start));
        VariantInit(&vField);
        hr = vfg_dispatch_get_indexed(V_DISPATCH(&vFields), L"Item", col, &vField);
        if (SUCCEEDED(hr) && V_VT(&vField) == VT_DISPATCH && V_DISPATCH(&vField)) {
            VariantInit(&vValue);
            V_VT(&vValue) = VT_BSTR;
            V_BSTR(&vValue) = cell ? cell : SysAllocString(L"");
            hr = vfg_dispatch_put(V_DISPATCH(&vField), L"Value", &vValue);
            VariantClear(&vValue);
        } else if (cell) {
            SysFreeString(cell);
        }
        VariantClear(&vField);
        if (p < end && *p == '	') p++;
        if (FAILED(hr)) {
            VariantClear(&vFields);
            if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
            return hr;
        }
    }
    VariantClear(&vFields);
    hr = vfg_dispatch_call(obj->recordset, L"Update");
    if (FAILED(hr)) {
        if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
        return hr;
    }
    if (volvox_grid_add_item(
            obj->grid_id,
            (const uint8_t *)(utf8 ? utf8 : ""),
            utf8 ? utf8len : 0,
            index) != 0) {
        if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
        return E_FAIL;
    }
    if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
    if (obj->data_mode != 0) {
        hr = vfg_bound_sync_cursor(obj);
        if (FAILED(hr)) return hr;
    }
    return S_OK;
}

static HRESULT vfg_bound_remove_item(VolvoxGridObject *obj, int32_t index) {
    int32_t pos;
    int32_t desired_pos = -1;
    long current_pos = -1;
    HRESULT hr;
    if (!obj || !obj->recordset) return S_FALSE;
    pos = index - VFG_BOUND_HEADER_ROWS + 1;
    if (pos < 1) return S_FALSE;
    (void)vfg_recordset_get_absolute_position(obj->recordset, &current_pos);
    if (current_pos >= 1) {
        desired_pos = (int32_t)current_pos;
        if (desired_pos > pos) desired_pos--;
    }
    hr = vfg_dispatch_put_i4(obj->recordset, L"AbsolutePosition", pos);
    if (FAILED(hr)) return hr;
    hr = vfg_dispatch_call(obj->recordset, L"Delete");
    if (FAILED(hr)) return hr;
    if (desired_pos >= 1) {
        (void)vfg_dispatch_put_i4(obj->recordset, L"AbsolutePosition", desired_pos);
    }
    hr = vfg_rebind_ado_source(obj);
    if (FAILED(hr)) return hr;
    if (obj->data_mode != 0) {
        hr = vfg_bound_sync_cursor(obj);
        if (FAILED(hr)) return hr;
        obj->suppress_bound_cursor_sync = 1;
    }
    return S_OK;
}

static int vfg_variant_is_true(const VARIANT *pv) {
    int32_t numeric = 0;
    if (!pv) return 0;
    if (V_VT(pv) == VT_BOOL) return V_BOOL(pv) != VARIANT_FALSE;
    if (SUCCEEDED(variant_to_i4((VARIANT *)pv, &numeric))) {
        return numeric != 0;
    }
    return 0;
}

static HRESULT vfg_variant_to_display_bstr(VARIANT *pv, BSTR *pValue) {
    VARIANT tmp;
    if (!pValue) return E_POINTER;
    *pValue = NULL;
    if (!pv || V_VT(pv) == VT_EMPTY || V_VT(pv) == VT_NULL) {
        *pValue = SysAllocString(L"");
        return *pValue ? S_OK : E_OUTOFMEMORY;
    }
    VariantInit(&tmp);
    if (SUCCEEDED(VariantChangeType(&tmp, pv, 0, VT_BSTR))) {
        BSTR src = V_BSTR(&tmp) ? V_BSTR(&tmp) : L"";
        UINT len = SysStringLen(src);
        *pValue = SysAllocStringLen(src, len);
        if (!*pValue && len > 0) {
            VariantClear(&tmp);
            return E_OUTOFMEMORY;
        }
        VariantClear(&tmp);
        return S_OK;
    }
    VariantClear(&tmp);
    return DISP_E_TYPEMISMATCH;
}

static HRESULT vfg_raise_vb_error(EXCEPINFO *pExcepInfo, WORD wCode, LPCOLESTR description) {
    if (pExcepInfo) {
        memset(pExcepInfo, 0, sizeof(*pExcepInfo));
        pExcepInfo->scode = (SCODE)wCode;
        pExcepInfo->bstrSource = SysAllocString(L"VolvoxGrid");
        if (description && *description) {
            pExcepInfo->bstrDescription = SysAllocString(description);
        }
    }
    return DISP_E_EXCEPTION;
}

static HRESULT vfg_get_col_index_compat_value(VolvoxGridObject *obj, BSTR key, int32_t *pIndex) {
    VARIANT vFields, vField, vName, vCount;
    HRESULT hr;
    long fieldCount = 0;
    if (!pIndex) return E_POINTER;
    *pIndex = -1;
    if (!key || SysStringLen(key) == 0) return S_OK;

    if (obj && obj->recordset) {
        VariantInit(&vFields);
        hr = vfg_dispatch_get(obj->recordset, L"Fields", &vFields);
        if (SUCCEEDED(hr) && V_VT(&vFields) == VT_DISPATCH && V_DISPATCH(&vFields)) {
            VariantInit(&vCount);
            hr = vfg_dispatch_get(V_DISPATCH(&vFields), L"Count", &vCount);
            if (SUCCEEDED(hr)) {
                if (V_VT(&vCount) == VT_I4) fieldCount = V_I4(&vCount);
                else if (V_VT(&vCount) == VT_I2) fieldCount = V_I2(&vCount);
                else variant_to_i4(&vCount, (int32_t *)&fieldCount);
            }
            VariantClear(&vCount);
            for (long col = 0; col < fieldCount; ++col) {
                VariantInit(&vField);
                hr = vfg_dispatch_get_indexed(V_DISPATCH(&vFields), L"Item", col, &vField);
                if (SUCCEEDED(hr) && V_VT(&vField) == VT_DISPATCH && V_DISPATCH(&vField)) {
                    VariantInit(&vName);
                    hr = vfg_dispatch_get(V_DISPATCH(&vField), L"Name", &vName);
                    if (SUCCEEDED(hr) && V_VT(&vName) == VT_BSTR && V_BSTR(&vName) &&
                        _wcsicmp(V_BSTR(&vName), key) == 0) {
                        *pIndex = vfg_bound_physical_col_offset(obj) + (int32_t)col;
                        VariantClear(&vName);
                        VariantClear(&vField);
                        VariantClear(&vFields);
                        return S_OK;
                    }
                    VariantClear(&vName);
                }
                VariantClear(&vField);
            }
        }
        VariantClear(&vFields);
    }

    if (obj) {
        int32_t cols = volvox_grid_get_cols(obj->grid_id);
        for (int32_t col = 0; col < cols; ++col) {
            int32_t out_len = 0;
            uint8_t *utf8 = volvox_grid_get_text_matrix(obj->grid_id, 0, col, &out_len);
            if (utf8 && out_len > 0) {
                BSTR header = utf8_to_bstr((const char *)utf8, out_len);
                volvox_grid_free(utf8, out_len);
                if (header) {
                    int matched = _wcsicmp(header, key) == 0;
                    SysFreeString(header);
                    if (matched) {
                        *pIndex = col;
                        return S_OK;
                    }
                }
            } else if (utf8) {
                volvox_grid_free(utf8, out_len);
            }
        }
    }
    return S_OK;
}

static HRESULT vfg_set_text_matrix_bstr(int64_t gid, int32_t row, int32_t col, BSTR text) {
    int utf8len = 0;
    char *utf8 = bstr_to_utf8(text, &utf8len);
    int32_t status = volvox_grid_set_text_matrix(
        gid,
        row,
        col,
        (const uint8_t *)(utf8 ? utf8 : ""),
        utf8 ? utf8len : 0);
    if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
    return status == 0 ? S_OK : E_FAIL;
}

static HRESULT vfg_require_datasource_iface(IDispatch *pSource) {
    IUnknown *pDataSource = NULL;
    HRESULT hr;
    VARIANT v;
    if (!pSource) return S_OK;
    /* Prefer the standard MSDATASRC IDataSource interface. */
    hr = IDispatch_QueryInterface(pSource, &IID_VFG_DataSource, (void **)&pDataSource);
    if (SUCCEEDED(hr) && pDataSource) {
        IUnknown_Release(pDataSource);
        return S_OK;
    }
    /* Wine's COM proxy may not forward the QI even with native MDAC.
     * Accept any IDispatch that exposes a Fields collection (i.e. a Recordset). */
    VariantInit(&v);
    hr = vfg_dispatch_get(pSource, L"Fields", &v);
    if (SUCCEEDED(hr) && V_VT(&v) == VT_DISPATCH && V_DISPATCH(&v)) {
        VariantClear(&v);
        return S_OK;
    }
    VariantClear(&v);
    return DISP_E_TYPEMISMATCH;
}

static HRESULT vfg_try_resolve_recordset(IDispatch *pSource, BSTR dataMember, IDispatch **ppRecordset) {
    VARIANT v;
    HRESULT hr;
    VariantInit(&v);
    if (!ppRecordset) return E_POINTER;
    *ppRecordset = NULL;
    if (!pSource) return S_OK;

    if (dataMember && SysStringLen(dataMember) > 0) {
        DISPID dispid = 0;
        hr = vfg_get_dispid_bstr(pSource, dataMember, &dispid);
        if (SUCCEEDED(hr)) {
            hr = vfg_dispatch_get_by_dispid(pSource, dispid, &v);
            if (SUCCEEDED(hr) && V_VT(&v) == VT_DISPATCH && V_DISPATCH(&v)) {
                *ppRecordset = V_DISPATCH(&v);
                IDispatch_AddRef(*ppRecordset);
                VariantClear(&v);
                return S_OK;
            }
            VariantClear(&v);
        }
    }

    hr = vfg_dispatch_get(pSource, L"Recordset", &v);
    if (SUCCEEDED(hr) && V_VT(&v) == VT_DISPATCH && V_DISPATCH(&v)) {
        *ppRecordset = V_DISPATCH(&v);
        IDispatch_AddRef(*ppRecordset);
        VariantClear(&v);
        return S_OK;
    }
    VariantClear(&v);

    hr = vfg_dispatch_get(pSource, L"Fields", &v);
    if (SUCCEEDED(hr) && V_VT(&v) == VT_DISPATCH && V_DISPATCH(&v)) {
        *ppRecordset = pSource;
        IDispatch_AddRef(*ppRecordset);
        VariantClear(&v);
        return S_OK;
    }
    VariantClear(&v);
    return DISP_E_TYPEMISMATCH;
}

static void vfg_clear_ado_binding(VolvoxGridObject *obj) {
    if (!obj) return;
    vfg_release_dispatch(&obj->recordset);
    vfg_release_dispatch(&obj->data_source);
    if (obj->data_member) {
        SysFreeString(obj->data_member);
        obj->data_member = NULL;
    }
    obj->has_bound_layout = 0;
    obj->bound_fixed_cols = 0;
    obj->bound_data_col_offset = 0;
    obj->bound_col_width_uses_data_offset = 0;
    obj->suppress_bound_cursor_sync = 0;
    obj->suppress_bound_text_writes = 0;
}

static HRESULT vfg_populate_from_recordset(VolvoxGridObject *obj, IDispatch *pRS) {
    VARIANT vFields, vCount, vEOF, vField, vName, vType, vValue;
    HRESULT hr;
    long fieldCount = 0;
    long recordCount = -1;
    long row = VFG_BOUND_HEADER_ROWS;
    int32_t dataColOffset = 0;
    int32_t fixedCols = 0;
    int32_t fixedRows = VFG_BOUND_HEADER_ROWS;
    int32_t totalCols = 0;
    int32_t priorCols = 0;
    int32_t priorDataColOffset = 0;
    int32_t preserve_visible_state = 0;
    int32_t saved_row = 0;
    int32_t saved_col = 0;
    int32_t saved_row_sel = 0;
    int32_t saved_col_sel = 0;
    int32_t saved_top_row = 0;
    int32_t saved_left_col = 0;
    long saved_record_pos = -1;
    int32_t *preservedWidths = NULL;
    int64_t gid;

    if (!obj) return E_POINTER;
    gid = obj->grid_id;

    if (!pRS) {
        volvox_grid_clear(gid, 0, 0);
        volvox_grid_set_rows(gid, 1);
        volvox_grid_set_cols(gid, 0);
        obj->fixed_rows_cached = 1;
        obj->has_bound_layout = 0;
        obj->bound_fixed_cols = 0;
        obj->bound_data_col_offset = 0;
        obj->bound_col_width_uses_data_offset = 0;
        vfg_sync_selection_cache_from_cursor(obj);
        return S_OK;
    }

    VariantInit(&vFields);
    hr = vfg_dispatch_get(pRS, L"Fields", &vFields);
    if (FAILED(hr) || V_VT(&vFields) != VT_DISPATCH || !V_DISPATCH(&vFields)) {
        VariantClear(&vFields);
        return E_FAIL;
    }

    VariantInit(&vCount);
    hr = vfg_dispatch_get(V_DISPATCH(&vFields), L"Count", &vCount);
    if (SUCCEEDED(hr)) {
        if (V_VT(&vCount) == VT_I4) fieldCount = V_I4(&vCount);
        else if (V_VT(&vCount) == VT_I2) fieldCount = V_I2(&vCount);
        else variant_to_i4(&vCount, (int32_t *)&fieldCount);
    }
    VariantClear(&vCount);

    dataColOffset = vfg_bound_selector_cols(obj);
    fixedCols = obj->has_bound_layout ? obj->bound_fixed_cols : obj->fixed_cols_cached;
    totalCols = dataColOffset + (fieldCount > 0 ? (int32_t)fieldCount : 0);
    fixedCols = vfg_bound_effective_fixed_cols(obj, totalCols, fixedCols);
    if (obj->fixed_rows_cached >= 0) fixedRows = obj->fixed_rows_cached;
    if (fixedRows < 0) fixedRows = 0;
    if (obj->data_mode != 0) {
        (void)vfg_recordset_get_absolute_position(pRS, &saved_record_pos);
    }

    if (obj->has_bound_layout) {
        priorCols = volvox_grid_get_cols(gid);
        priorDataColOffset = obj->bound_data_col_offset;
        preserve_visible_state = 1;
        saved_row = volvox_grid_get_row(gid);
        saved_col = vfg_get_col_cached(gid);
        saved_row_sel = vfg_get_row_sel_cached(gid);
        saved_col_sel = vfg_get_col_sel_cached(gid);
        saved_top_row = volvox_grid_get_top_row(gid);
        saved_left_col = vfg_get_left_col_cached(gid);
        if (priorCols > 0 && obj->data_mode != 0) {
            preservedWidths = vfg_capture_col_widths(gid, priorCols);
        }
    }

    volvox_grid_set_redraw(gid, 0);
    volvox_grid_set_cols(gid, totalCols);
    volvox_grid_set_rows(gid, VFG_BOUND_HEADER_ROWS);
    vfg_apply_bound_col_widths(
        gid,
        dataColOffset,
        fieldCount > 0 ? (int32_t)fieldCount : 0,
        preservedWidths,
        priorCols,
        priorDataColOffset);
    for (int32_t col = 0; col < dataColOffset; ++col) {
        volvox_grid_set_text_matrix(gid, 0, col, (const uint8_t *)"", 0);
        volvox_grid_set_col_data_type(gid, col, 0);
        vfg_set_cached_col_data_type(obj, col, 0);
    }

    for (long col = 0; col < fieldCount; col++) {
        int32_t gridCol = dataColOffset + (int32_t)col;
        int32_t engineDataType = 0;
        VariantInit(&vField);
        hr = vfg_dispatch_get_indexed(V_DISPATCH(&vFields), L"Item", col, &vField);
        if (SUCCEEDED(hr) && V_VT(&vField) == VT_DISPATCH && V_DISPATCH(&vField)) {
            VariantInit(&vType);
            hr = vfg_dispatch_get(V_DISPATCH(&vField), L"Type", &vType);
            if (SUCCEEDED(hr)) {
                int32_t fieldType = 0;
                if (SUCCEEDED(variant_to_i4(&vType, &fieldType))) {
                    engineDataType = activex_col_data_type_to_engine(fieldType);
                }
            }
            VariantClear(&vType);
            volvox_grid_set_col_data_type(gid, gridCol, engineDataType);
            vfg_set_cached_col_data_type(obj, gridCol, engineDataType);
            VariantInit(&vName);
            hr = vfg_dispatch_get(V_DISPATCH(&vField), L"Name", &vName);
            if (SUCCEEDED(hr) && V_VT(&vName) == VT_BSTR && V_BSTR(&vName)) {
                vfg_set_text_matrix_bstr(gid, 0, gridCol, V_BSTR(&vName));
            }
            VariantClear(&vName);
        } else {
            volvox_grid_set_col_data_type(gid, gridCol, 0);
            vfg_set_cached_col_data_type(obj, gridCol, 0);
        }
        VariantClear(&vField);
    }

    hr = vfg_dispatch_call(pRS, L"MoveFirst");
    VariantInit(&vCount);
    hr = vfg_dispatch_get(pRS, L"RecordCount", &vCount);
    if (SUCCEEDED(hr)) {
        if (V_VT(&vCount) == VT_I4) recordCount = V_I4(&vCount);
        else if (V_VT(&vCount) == VT_I2) recordCount = V_I2(&vCount);
        else variant_to_i4(&vCount, (int32_t *)&recordCount);
    }
    VariantClear(&vCount);
    if (recordCount > 0) {
        volvox_grid_set_rows(gid, (int32_t)recordCount + VFG_BOUND_HEADER_ROWS);
    }

    while (1) {
        VariantInit(&vEOF);
        hr = vfg_dispatch_get(pRS, L"EOF", &vEOF);
        if (FAILED(hr) || vfg_variant_is_true(&vEOF)) {
            VariantClear(&vEOF);
            break;
        }
        VariantClear(&vEOF);

        if (recordCount <= 0) {
            volvox_grid_set_rows(gid, (int32_t)row + 1);
        }
        for (int32_t clearCol = 0; clearCol < dataColOffset; ++clearCol) {
            volvox_grid_set_text_matrix(gid, row, clearCol, (const uint8_t *)"", 0);
        }

        for (long col = 0; col < fieldCount; col++) {
            int32_t gridCol = dataColOffset + (int32_t)col;
            int32_t dataType = vfg_get_cached_col_data_type(obj, gridCol);
            VariantInit(&vField);
            hr = vfg_dispatch_get_indexed(V_DISPATCH(&vFields), L"Item", col, &vField);
            if (SUCCEEDED(hr) && V_VT(&vField) == VT_DISPATCH && V_DISPATCH(&vField)) {
                BSTR cell = NULL;
                VariantInit(&vValue);
                hr = vfg_dispatch_get(V_DISPATCH(&vField), L"Value", &vValue);
                if (dataType == 3) {
                    int32_t checkedState = 0;
                    if (SUCCEEDED(hr) &&
                        V_VT(&vValue) != VT_EMPTY &&
                        V_VT(&vValue) != VT_NULL) {
                        checkedState = vfg_variant_is_true(&vValue) ? 1 : 3;
                    }
                    volvox_grid_set_cell_checked(gid, row, gridCol, checkedState);
                    volvox_grid_set_text_matrix(gid, row, gridCol, (const uint8_t *)"", 0);
                } else {
                    volvox_grid_set_cell_checked(gid, row, gridCol, 0);
                    if (SUCCEEDED(hr) &&
                        SUCCEEDED(vfg_variant_to_display_bstr(&vValue, &cell))) {
                        vfg_set_text_matrix_bstr(gid, row, gridCol, cell);
                    }
                }
                if (cell) SysFreeString(cell);
                VariantClear(&vValue);
            }
            VariantClear(&vField);
        }

        row++;
        if (FAILED(vfg_dispatch_call(pRS, L"MoveNext"))) break;
    }

    if (recordCount > 0 && row != recordCount + VFG_BOUND_HEADER_ROWS) {
        volvox_grid_set_rows(gid, (int32_t)row);
    }

    if (saved_record_pos >= 1 && obj->data_mode != 0) {
        long restore_pos = saved_record_pos;
        if (recordCount > 0 && restore_pos > recordCount) restore_pos = recordCount;
        if (restore_pos < 1) restore_pos = 1;
        (void)vfg_dispatch_put_i4(pRS, L"AbsolutePosition", (int32_t)restore_pos);
    }

    {
        int32_t currentRows = volvox_grid_get_rows(gid);
        if (currentRows > 0 && fixedRows > currentRows) fixedRows = currentRows;
    }
    volvox_grid_set_fixed_rows(gid, fixedRows);
    volvox_grid_set_fixed_cols(gid, fixedCols);
    if (((!preservedWidths) || vfg_engine_auto_resize_enabled(gid, obj->auto_resize)) &&
        totalCols > dataColOffset) {
        volvox_grid_auto_size(gid, dataColOffset, totalCols - 1, 0, 0);
        vfg_apply_bound_autosize_compat_widths(gid, dataColOffset, 0, totalCols - 1);
    }

    if (preservedWidths) {
        HeapFree(GetProcessHeap(), 0, preservedWidths);
        preservedWidths = NULL;
    }
    obj->has_bound_layout = 1;
    obj->bound_fixed_cols = fixedCols;
    obj->bound_data_col_offset = dataColOffset;
    obj->suppress_bound_cursor_sync = 0;
    if (dataColOffset <= 0 || !obj->has_bound_layout) {
        obj->bound_col_width_uses_data_offset = 0;
    }
    vfg_bound_apply_visible_state(
        obj,
        preserve_visible_state,
        saved_row,
        saved_col,
        saved_row_sel,
        saved_col_sel,
        saved_top_row,
        saved_left_col);
    if (obj->data_mode != 0) {
        hr = vfg_bound_sync_cursor(obj);
        if (FAILED(hr)) {
            if (preservedWidths) {
                HeapFree(GetProcessHeap(), 0, preservedWidths);
            }
            volvox_grid_set_redraw(gid, 1);
            VariantClear(&vFields);
            return hr;
        }
    }
    volvox_grid_set_redraw(gid, 1);
    volvox_grid_refresh(gid);
    VariantClear(&vFields);
    return S_OK;
}

static HRESULT vfg_rebind_ado_source(VolvoxGridObject *obj) {
    IDispatch *resolved = NULL;
    HRESULT hr;
    if (!obj) return E_POINTER;
    vfg_release_dispatch(&obj->recordset);
    if (!obj->data_source) {
        obj->has_bound_layout = 0;
        obj->bound_fixed_cols = 0;
        obj->bound_data_col_offset = 0;
        obj->bound_col_width_uses_data_offset = 0;
        obj->suppress_bound_cursor_sync = 0;
        obj->suppress_bound_text_writes = 0;
        vfg_sync_selection_cache_from_cursor(obj);
        return S_OK;
    }
    obj->suppress_bound_text_writes = 0;
    hr = vfg_try_resolve_recordset(obj->data_source, obj->data_member, &resolved);
    if (FAILED(hr)) return hr;
    obj->recordset = resolved;
    hr = vfg_populate_from_recordset(obj, obj->recordset);
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
    (void)riid; (void)lcid; (void)puArgErr;
    VolvoxGridObject *obj = (VolvoxGridObject *)This;
    int64_t gid = obj->grid_id;

    {
        HRESULT hr = vfg_sync_bound_state(obj, dispIdMember, wFlags);
        if (FAILED(hr)) return hr;
    }

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

    case DISPID_VG_COLINDEX_COMPAT:
        if (wFlags & (DISPATCH_METHOD | DISPATCH_PROPERTYGET)) {
            VARIANT vkey;
            BSTR key = NULL;
            int32_t index = -1;
            HRESULT hr;
            VariantInit(&vkey);
            if (pDispParams->cArgs >= 1) {
                key = variant_to_bstr(ARG(0), &vkey);
            }
            hr = vfg_get_col_index_compat_value(obj, key, &index);
            VariantClear(&vkey);
            if (FAILED(hr)) return hr;
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = index;
            return S_OK;
        }
        break;

    case DISPID_VG_DATASOURCE_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            VariantInit(pVarResult);
            V_VT(pVarResult) = VT_DISPATCH;
            V_DISPATCH(pVarResult) = obj->data_source;
            if (obj->data_source) {
                IDispatch_AddRef(obj->data_source);
            }
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            IDispatch *newSource = NULL;
            VARIANT *src = NULL;
            HRESULT hr = S_OK;
            if (pDispParams->cArgs >= 1) {
                src = NAMED_ARG(0);
                if (V_VT(src) == VT_DISPATCH) {
                    newSource = V_DISPATCH(src);
                    if (newSource) IDispatch_AddRef(newSource);
                } else if (V_VT(src) == VT_UNKNOWN && V_UNKNOWN(src)) {
                    hr = IUnknown_QueryInterface(V_UNKNOWN(src), &IID_IDispatch, (void **)&newSource);
                    if (FAILED(hr)) return hr;
                } else if (V_VT(src) != VT_EMPTY && V_VT(src) != VT_NULL) {
                    return DISP_E_TYPEMISMATCH;
                }
            }
            if (newSource) {
                hr = vfg_require_datasource_iface(newSource);
                if (FAILED(hr)) {
                    IDispatch_Release(newSource);
                    return hr;
                }
            }
            vfg_release_dispatch(&obj->data_source);
            obj->data_source = newSource;
            hr = vfg_rebind_ado_source(obj);
            return FAILED(hr) ? hr : S_OK;
        }
        break;

    case DISPID_VG_DATAMODE_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = obj->data_mode;
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t mode = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(NAMED_ARG(0), &mode);
            if (mode < 0) mode = 0;
            obj->data_mode = mode;
            return S_OK;
        }
        break;

    case DISPID_VG_DATAMEMBER_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_BSTR;
            V_BSTR(pVarResult) = obj->data_member
                ? SysAllocStringLen(obj->data_member, SysStringLen(obj->data_member))
                : SysAllocString(L"");
            return V_BSTR(pVarResult) || !obj->data_member ? S_OK : E_OUTOFMEMORY;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            VARIANT vtmp;
            BSTR value = NULL;
            VariantInit(&vtmp);
            if (pDispParams->cArgs >= 1) {
                value = variant_to_bstr(NAMED_ARG(0), &vtmp);
            }
            vfg_set_bstr_copy(&obj->data_member, value);
            VariantClear(&vtmp);
            if (obj->data_source) {
                HRESULT hr = vfg_rebind_ado_source(obj);
                if (FAILED(hr)) return hr;
            }
            return S_OK;
        }
        break;

    case DISPID_VG_VIRTUALDATA_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_BOOL;
            V_BOOL(pVarResult) = obj->virtual_data ? VARIANT_TRUE : VARIANT_FALSE;
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            VARIANT tmp;
            int32_t value = 0;
            if (pDispParams->cArgs >= 1) {
                VariantInit(&tmp);
                if (SUCCEEDED(VariantChangeType(&tmp, NAMED_ARG(0), 0, VT_BOOL))) {
                    value = V_BOOL(&tmp) != VARIANT_FALSE;
                } else if (SUCCEEDED(variant_to_i4(NAMED_ARG(0), &value))) {
                    value = value != 0;
                }
                VariantClear(&tmp);
            }
            obj->virtual_data = value ? 1 : 0;
            return S_OK;
        }
        break;

    case DISPID_VG_AUTORESIZE_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t enabled = vfg_engine_auto_resize_enabled(obj->grid_id, obj->auto_resize);
            obj->auto_resize = enabled ? 1 : 0;
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_BOOL;
            V_BOOL(pVarResult) = enabled ? VARIANT_TRUE : VARIANT_FALSE;
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            VARIANT tmp;
            int32_t value = 0;
            if (pDispParams->cArgs >= 1) {
                VariantInit(&tmp);
                if (SUCCEEDED(VariantChangeType(&tmp, NAMED_ARG(0), 0, VT_BOOL))) {
                    value = V_BOOL(&tmp) != VARIANT_FALSE;
                } else if (SUCCEEDED(variant_to_i4(NAMED_ARG(0), &value))) {
                    value = value != 0;
                }
                VariantClear(&tmp);
            }
            obj->auto_resize = value ? 1 : 0;
            if (volvox_grid_set_auto_resize_compat(obj->grid_id, obj->auto_resize) != 0) {
                return E_FAIL;
            }
            if (obj->data_source) {
                HRESULT hr = vfg_rebind_ado_source(obj);
                if (FAILED(hr)) return hr;
            }
            return S_OK;
        }
        break;

    case DISPID_VG_DATAREFRESH_COMPAT:
        if (wFlags & DISPATCH_METHOD) {
            HRESULT hr = obj->data_source ? vfg_rebind_ado_source(obj) : S_OK;
            return FAILED(hr) ? hr : S_OK;
        }
        break;

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
            if (obj->has_bound_layout) {
                v = vfg_bound_effective_fixed_cols(obj, cols, v);
            } else if (cols > 0) {
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
            {
                int32_t cols = volvox_grid_get_cols(gid);
                int32_t v = val;
                if (obj->has_bound_layout) {
                    v = vfg_bound_effective_fixed_cols(obj, cols, v);
                } else if (cols > 0) {
                    if (v < 0) v = 0;
                    if (v > cols) v = cols;
                } else {
                    v = 0;
                }
                volvox_grid_set_fixed_cols(gid, v);
                obj->fixed_cols_cached = v;
                if (obj->has_bound_layout) {
                    obj->bound_fixed_cols = v;
                    if (obj->bound_data_col_offset > 0) {
                        obj->bound_col_width_uses_data_offset =
                            (val <= 0 && vfg_bound_allows_zero_fixed_cols(obj)) ? 1 : 0;
                    } else {
                        obj->bound_col_width_uses_data_offset = 0;
                    }
                }
                vfg_sync_selection_cache_from_cursor(obj);
            }
            return S_OK;
        }
        break;

    case DISPID_VG_COL:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = volvox_grid_get_col_cached(gid);
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t val = 0;
            variant_to_i4(NAMED_ARG(0), &val);
            volvox_grid_set_col(gid, val);
            return S_OK;
        }
        break;

    case DISPID_VG_FROZENROWS:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = volvox_grid_get_frozen_rows_cached(gid);
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t val = 0;
            variant_to_i4(NAMED_ARG(0), &val);
            volvox_grid_set_frozen_rows(gid, val);
            return S_OK;
        }
        break;

    case DISPID_VG_FROZENCOLS:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = volvox_grid_get_frozen_cols_cached(gid);
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t val = 0;
            variant_to_i4(NAMED_ARG(0), &val);
            volvox_grid_set_frozen_cols(gid, val);
            return S_OK;
        }
        break;

    case DISPID_VG_EDITABLE:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = volvox_grid_get_editable_cached(gid);
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t val = 0;
            variant_to_i4(NAMED_ARG(0), &val);
            if (obj->data_source && obj->recordset && obj->data_mode != 0) {
                obj->suppress_bound_text_writes = 1;
                return vfg_raise_vb_error(
                    pExcepInfo,
                    1004,
                    L"Unable to set the Editable property on a bound grid.");
            }
            obj->suppress_bound_text_writes = 0;
            volvox_grid_set_editable(gid, val);
            return S_OK;
        }
        break;

    case DISPID_VG_ROWSEL:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = volvox_grid_get_row_sel_cached(gid);
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t val = 0;
            variant_to_i4(NAMED_ARG(0), &val);
            volvox_grid_set_row_sel(gid, val);
            return S_OK;
        }
        break;

    case DISPID_VG_COLSEL:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = volvox_grid_get_col_sel_cached(gid);
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t val = 0;
            variant_to_i4(NAMED_ARG(0), &val);
            volvox_grid_set_col_sel(gid, val);
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
                if (vfg_should_preserve_blank_bound_header(obj, row, col, text)) {
                    VariantClear(&vtmp);
                    return S_OK;
                }
                if (obj->data_source &&
                    (obj->editable_cached != 0 || obj->suppress_bound_text_writes) &&
                    row >= obj->fixed_rows_cached &&
                    col >= obj->bound_data_col_offset) {
                    VariantClear(&vtmp);
                    return S_OK;
                }
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
                int32_t checked = volvox_grid_get_cell_checked(gid, row, col);
                int32_t data_type = vfg_get_cached_col_data_type(obj, col);
                V_VT(pVarResult) = VT_BSTR;
                if (data_type == 3 && checked == 1) V_BSTR(pVarResult) = SysAllocString(L"-1");
                else if (data_type == 3 && checked == 3) V_BSTR(pVarResult) = SysAllocString(L"0");
                else V_BSTR(pVarResult) = SysAllocString(L"");
            }
            return S_OK;
        }
        break;

    /* ── RowHeight(row) / ColWidth(col) — indexed, twips ←→ pixels ── */
    /* The flex grid API uses twips (1 inch = 1440 twips).              */
    /* Convert using the active screen DPI so ActiveX metrics track the same device scale as the legacy OCX. */
    /* Special value -1 means "reset to default" — pass through as-is. */

    case DISPID_VG_ROWHEIGHT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            int32_t idx = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(&pDispParams->rgvarg[0], &idx);
            int32_t px = volvox_grid_get_row_height(gid, idx);
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = vfg_px_to_twips_y(px);
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t idx = 0, val = 0;
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(&pDispParams->rgvarg[1], &idx);
                variant_to_i4(&pDispParams->rgvarg[0], &val);
            }
            int32_t px = vfg_twips_to_px_y(val);
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
            V_I4(pVarResult) = vfg_px_to_twips_x(px);
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t idx = 0, val = 0;
            if (obj->has_bound_layout && obj->data_mode != 0) {
                return vfg_raise_vb_error(
                    pExcepInfo,
                    1004,
                    L"Unable to set the ColWidth property on a bound grid.");
            }
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(&pDispParams->rgvarg[1], &idx);
                variant_to_i4(&pDispParams->rgvarg[0], &val);
            }
            int32_t px = vfg_twips_to_px_x(val);
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
    /* Convert points using the active screen DPI to match legacy text metrics.  */
    case DISPID_VG_FONTSIZE:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return DISP_E_PARAMNOTOPTIONAL;
            pVarResult->vt = VT_R4;
            float px = volvox_grid_get_font_size(gid);
            pVarResult->fltVal = px * 72.0f / (float)vfg_get_screen_dpi_y();
            return S_OK;
        }
        if (wFlags & DISPATCH_PROPERTYPUT) {
            VARIANT v; VariantInit(&v);
            VariantChangeType(&v, &pDispParams->rgvarg[0], 0, VT_R4);
            float pt = v.fltVal;
            volvox_grid_set_font_size(gid, pt * (float)vfg_get_screen_dpi_y() / 72.0f);
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
            int32_t engine_dt = activex_col_data_type_to_engine(dt);
            volvox_grid_set_col_data_type(gid, col, engine_dt);
            vfg_set_cached_col_data_type(obj, col, engine_dt);
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
            int32_t sort_col = volvox_grid_get_col_cached(gid);
            variant_to_i4(NAMED_ARG(0), &order);
            if (obj->data_source && obj->recordset && sort_col >= 0 &&
                sort_col < vfg_bound_physical_col_offset(obj)) {
                return S_OK;
            }
            volvox_grid_sort(gid, order, sort_col);
            return S_OK;
        }
        if (wFlags & DISPATCH_METHOD) {
            int32_t order = 0, col = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &order);
            if (pDispParams->cArgs >= 2) variant_to_i4(ARG(1), &col);
            if (obj->data_source && obj->recordset && col >= 0 &&
                col < vfg_bound_physical_col_offset(obj)) {
                return S_OK;
            }
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
            int32_t compat_fixed_group_subtotal = 0;
            int32_t original_fixed_cols = 0;
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

            compat_fixed_group_subtotal =
                obj && obj->data_source && obj->recordset &&
                group_col >= 0 && group_col < obj->fixed_cols_cached;
            if (compat_fixed_group_subtotal) {
                original_fixed_cols = obj->fixed_cols_cached;
                if (original_fixed_cols != group_col) {
                    volvox_grid_set_fixed_cols(gid, group_col);
                }
            }

            int utf8len = 0;
            char *utf8 = bstr_to_utf8(caption, &utf8len);
            volvox_grid_subtotal(gid, aggregate, group_col, agg_col,
                (const uint8_t *)(utf8 ? utf8 : ""), utf8 ? utf8len : 0,
                olecolor_to_argb(bcolor), olecolor_to_argb(fcolor), 1);
            if (compat_fixed_group_subtotal && original_fixed_cols != group_col) {
                volvox_grid_set_fixed_cols(gid, original_fixed_cols);
            }
            if (compat_fixed_group_subtotal) {
                int32_t rows = volvox_grid_get_rows(gid);
                for (int32_t row = obj->fixed_rows_cached; row < rows; ++row) {
                    if (!volvox_grid_get_is_subtotal(gid, row)) continue;
                    volvox_grid_set_text_matrix(gid, row, group_col, (const uint8_t *)"", 0);
                    if (agg_col >= 0) {
                        int32_t cell_len = 0;
                        uint8_t *cell = volvox_grid_get_text_matrix(gid, row, agg_col, &cell_len);
                        if (cell && cell_len == 1 && cell[0] == 48) {
                            volvox_grid_set_text_matrix(gid, row, agg_col, (const uint8_t *)".00", 3);
                        }
                        if (cell) volvox_grid_free(cell, cell_len);
                    }
                    break;
                }
            }
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
            if (obj && obj->data_source && obj->has_bound_layout && equal == 0 && max_w <= 0) {
                int32_t total_cols = volvox_grid_get_cols(gid);
                if (total_cols > 0) {
                    int32_t c_from = from;
                    int32_t c_to = to;
                    if (c_from < 0) c_from = 0;
                    if (c_to >= total_cols) c_to = total_cols - 1;
                    if (c_from <= c_to) {
                        vfg_apply_bound_autosize_compat_widths(
                            gid,
                            obj->bound_data_col_offset,
                            c_from,
                            c_to);
                    }
                }
                return S_OK;
            }
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
            if (obj->data_source && obj->recordset &&
                vfg_recordset_has_active_connection(obj->recordset)) {
                VariantClear(&vitm);
                return vfg_raise_vb_error(
                    pExcepInfo,
                    1004,
                    L"Unable to use AddItem on a bound SQL grid.");
            }
            if (obj->data_source && obj->recordset) {
                HRESULT hr = vfg_bound_add_item(obj, item, index);
                if (hr != S_FALSE) {
                    VariantClear(&vitm);
                    return FAILED(hr) ? hr : S_OK;
                }
            }
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
            if (obj->data_source && obj->recordset) {
                HRESULT hr = vfg_bound_remove_item(obj, index);
                if (hr != S_FALSE) return FAILED(hr) ? hr : S_OK;
            }
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
            HRESULT hr = obj->data_source ? vfg_rebind_ado_source(obj) : S_OK;
            if (FAILED(hr)) return hr;
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

    case DISPID_VG_LOADDEMO:
        if (wFlags & DISPATCH_METHOD) {
            BSTR demo = NULL;
            VARIANT vdemo;
            int utf8len = 0;
            int32_t status = -1;
            char *utf8 = NULL;

            VariantInit(&vdemo);
            if (pDispParams->cArgs >= 1) {
                demo = variant_to_bstr(ARG(0), &vdemo);
            }

            utf8 = bstr_to_utf8(demo, &utf8len);
            status = volvox_grid_load_demo_compat(
                gid,
                (const uint8_t *)(utf8 ? utf8 : ""),
                utf8 ? utf8len : 0);

            if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
            VariantClear(&vdemo);

            if (status != 0) {
                return E_FAIL;
            }
            return S_OK;
        }
        break;

    case DISPID_VG_RESIZEVIEWPORT:
        if (wFlags & DISPATCH_METHOD) {
            int32_t width = 0, height = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &width);
            if (pDispParams->cArgs >= 2) variant_to_i4(ARG(1), &height);
            return volvox_grid_resize_viewport_native(gid, width, height) == 0 ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_POINTERDOWN:
        if (wFlags & DISPATCH_METHOD) {
            float x = 0.0f, y = 0.0f;
            int32_t button = 0, modifier = 0, dbl_click = 0;
            if (pDispParams->cArgs >= 1) variant_to_float(ARG(0), &x);
            if (pDispParams->cArgs >= 2) variant_to_float(ARG(1), &y);
            if (pDispParams->cArgs >= 3) variant_to_i4(ARG(2), &button);
            if (pDispParams->cArgs >= 4) variant_to_i4(ARG(3), &modifier);
            if (pDispParams->cArgs >= 5) variant_to_i4(ARG(4), &dbl_click);
            return volvox_grid_pointer_down_native(gid, x, y, button, modifier, dbl_click) == 0
                ? S_OK
                : E_FAIL;
        }
        break;

    case DISPID_VG_POINTERMOVE:
        if (wFlags & DISPATCH_METHOD) {
            float x = 0.0f, y = 0.0f;
            int32_t button = 0, modifier = 0;
            if (pDispParams->cArgs >= 1) variant_to_float(ARG(0), &x);
            if (pDispParams->cArgs >= 2) variant_to_float(ARG(1), &y);
            if (pDispParams->cArgs >= 3) variant_to_i4(ARG(2), &button);
            if (pDispParams->cArgs >= 4) variant_to_i4(ARG(3), &modifier);
            return volvox_grid_pointer_move_native(gid, x, y, button, modifier) == 0 ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_POINTERUP:
        if (wFlags & DISPATCH_METHOD) {
            float x = 0.0f, y = 0.0f;
            int32_t button = 0, modifier = 0;
            if (pDispParams->cArgs >= 1) variant_to_float(ARG(0), &x);
            if (pDispParams->cArgs >= 2) variant_to_float(ARG(1), &y);
            if (pDispParams->cArgs >= 3) variant_to_i4(ARG(2), &button);
            if (pDispParams->cArgs >= 4) variant_to_i4(ARG(3), &modifier);
            return volvox_grid_pointer_up_native(gid, x, y, button, modifier) == 0 ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_SCROLL:
        if (wFlags & DISPATCH_METHOD) {
            float delta_x = 0.0f, delta_y = 0.0f;
            if (pDispParams->cArgs >= 1) variant_to_float(ARG(0), &delta_x);
            if (pDispParams->cArgs >= 2) variant_to_float(ARG(1), &delta_y);
            return volvox_grid_scroll_native(gid, delta_x, delta_y) == 0 ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_KEYDOWN:
        if (wFlags & DISPATCH_METHOD) {
            int32_t key_code = 0, modifier = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &key_code);
            if (pDispParams->cArgs >= 2) variant_to_i4(ARG(1), &modifier);
            return volvox_grid_key_down_native(gid, key_code, modifier) == 0 ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_KEYPRESS:
        if (wFlags & DISPATCH_METHOD) {
            int32_t char_code = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &char_code);
            return volvox_grid_key_press_native(gid, (uint32_t)char_code) == 0 ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_SETHOVERMODE:
        if (wFlags & DISPATCH_METHOD) {
            int32_t mode = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &mode);
            return volvox_grid_set_hover_mode_native(gid, (uint32_t)mode) == 0 ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_SETDEBUGOVERLAY:
        if (wFlags & DISPATCH_METHOD) {
            int32_t enabled = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &enabled);
            return volvox_grid_set_debug_overlay_native(gid, enabled) == 0 ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_SETSCROLLBLIT:
        if (wFlags & DISPATCH_METHOD) {
            int32_t enabled = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &enabled);
            return volvox_grid_set_scroll_blit_native(gid, enabled) == 0 ? S_OK : E_FAIL;
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
    int32_t x, int32_t y,
    int32_t clip_x, int32_t clip_y, int32_t clip_w, int32_t clip_h,
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

    int clip_left = clip_x;
    int clip_top = clip_y;
    int clip_right = clip_x + clip_w;
    int clip_bottom = y + clip_h;
    int wrap_w = (max_width >= 0.0f) ? (int)(max_width + 0.5f) : 0;
    if (wrap_w < 0) wrap_w = 0;

    int surf_left = (x < clip_left) ? x : clip_left;
    int surf_top = (y < clip_top) ? y : clip_top;
    int surf_right = clip_right;
    int surf_bottom = clip_bottom;
    if (x + 1 > surf_right) surf_right = x + 1;
    if (y + 1 > surf_bottom) surf_bottom = y + 1;
    if (wrap_w > 0 && x + wrap_w > surf_right) surf_right = x + wrap_w;

    int rw = surf_right - surf_left;
    int rh = surf_bottom - surf_top;
    if (rw < 1) rw = 1;
    if (rh < 1) rh = 1;
    int draw_x = x - surf_left;
    int draw_y = y - surf_top;

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

    RECT rc = { draw_x, draw_y, rw, rh };
    if (wrap_w > 0) {
        rc.right = draw_x + wrap_w;
        if (rc.right > rw) rc.right = rw;
        if (rc.right <= rc.left) rc.right = rc.left + 1;
    }
    DrawTextW(hdc, wtext, wlen, &rc, fmt);
    if (bold && gdi_is_wine()) {
        RECT rc_bold = rc;
        rc_bold.left += 1;
        rc_bold.right += 1;
        DrawTextW(hdc, wtext, wlen, &rc_bold, fmt);
    }

    /* Measure the rendered width */
    RECT mrc = rc;
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
    int dst_left = gdi_clamp_int(clip_left, 0, buf_width);
    int dst_top = gdi_clamp_int(clip_top, 0, buf_height);
    int dst_right = gdi_clamp_int(clip_right, 0, buf_width);
    int dst_bottom = gdi_clamp_int(clip_bottom, 0, buf_height);

    for (int by = dst_top; by < dst_bottom; by++) {
        int sy = by - surf_top;
        if (sy < 0 || sy >= rh) continue;
        for (int bx = dst_left; bx < dst_right; bx++) {
            int sx = bx - surf_left;
            if (sx < 0 || sx >= rw) continue;

            uint32_t alpha = gdi_dib_green_at(dib, dib_stride, rw, rh, sx, sy);
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
    obj->bound_fixed_cols = 0;
    obj->bound_data_col_offset = 0;
    obj->bound_col_width_uses_data_offset = 0;
    obj->has_bound_layout = 0;
    obj->editable_cached = 0;
    obj->frozen_rows_cached = 0;
    obj->frozen_cols_cached = 0;
    obj->row_sel_cached = 1;
    obj->col_sel_cached = 1;
    obj->data_mode = 0;
    obj->virtual_data = 0;
    obj->auto_resize = 1;
    obj->suppress_bound_text_writes = 0;
    obj->data_source = NULL;
    obj->recordset = NULL;
    obj->data_member = NULL;
    obj->registry_next = NULL;
    /* Match the legacy control's fresh-instance default geometry. */
    obj->grid_id = volvox_grid_create_grid(640, 480, 50, 10, 1, 1, 1.0f);
    vfg_register_object(obj);
    vfg_sync_selection_cache_from_cursor(obj);

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
