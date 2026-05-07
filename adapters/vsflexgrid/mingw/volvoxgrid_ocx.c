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
#include <objsafe.h>
#include <commdlg.h>
#include <gdiplus.h>
#include <stdio.h>
#include <string.h>
#include <urlmon.h>
#include <wctype.h>
#include "VolvoxGrid_guids.h"
#include "../include/volvoxgrid_activex_ffi_native.h"
#include "../include/volvoxgrid_ffi_extra.h"
#include "../include/volvoxgrid_activex.h"

extern int32_t volvox_grid_get_merge_cells_fixed_native(int64_t id);

/* MSDATASRC.DataSource IID {7C0FFAB3-CD84-11D0-949A-00A0C91110ED}. */
static const GUID IID_VFG_DataSource = {
    0x7c0ffab3, 0xcd84, 0x11d0,
    {0x94, 0x9a, 0x00, 0xa0, 0xc9, 0x11, 0x10, 0xed}
};

#define VFG_DEFAULT_DPI 96
#define VFG_BOUND_HEADER_ROWS 1
#define VFG_BOUND_VIRTUAL_RECORD_THRESHOLD 10000
#define VFG_BOUND_SELECTOR_COL_WIDTH_PX 13
#define VFG_BOUND_AUTOSIZE_TEXT_PAD_PX 13
#define VFG_BOUND_AUTOSIZE_MIN_COL_WIDTH_PX 20
#define VFG_UNBOUND_CELLFONT_AUTOSIZE_EXTRA_BOLD_BASE_PX 13
#define VFG_UNBOUND_CELLFONT_AUTOSIZE_EXTRA_NORMAL_BASE_PX 12
#define VFG_EVENT_TIMER_ID 0xF9E7
#define VFG_EVENT_TIMER_MS 16

#ifndef GET_X_LPARAM
#define GET_X_LPARAM(lp) ((int)(short)LOWORD(lp))
#endif

#ifndef GET_Y_LPARAM
#define GET_Y_LPARAM(lp) ((int)(short)HIWORD(lp))
#endif

#ifndef IDC_HAND
#define IDC_HAND MAKEINTRESOURCEW(32649)
#endif

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
static int vfg_read_fixed64(const uint8_t *buf, int32_t len, int32_t *pos, uint64_t *out);
static double vfg_u64_to_double(uint64_t u);

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

static int32_t vfg_decode_i32_field(
    const uint8_t *data, int32_t len, uint32_t target_field, int32_t fallback)
{
    int32_t pos = 0;
    if (!data || len < 0) return fallback;

    while (pos < len) {
        uint64_t key = 0;
        uint64_t value = 0;
        uint32_t field_no;
        uint32_t wire_type;
        if (!vfg_read_varint(data, len, &pos, &key)) return fallback;
        field_no = (uint32_t)(key >> 3);
        wire_type = (uint32_t)(key & 0x7);
        if (field_no == target_field && wire_type == 0) {
            if (!vfg_read_varint(data, len, &pos, &value)) return fallback;
            return (int32_t)value;
        }
        if (!vfg_skip_wire(data, len, &pos, wire_type)) return fallback;
    }
    return fallback;
}

static double vfg_decode_double_field(
    const uint8_t *data, int32_t len, uint32_t target_field, double fallback)
{
    int32_t pos = 0;
    if (!data || len < 0) return fallback;

    while (pos < len) {
        uint64_t key = 0;
        uint64_t value = 0;
        uint32_t field_no;
        uint32_t wire_type;
        if (!vfg_read_varint(data, len, &pos, &key)) return fallback;
        field_no = (uint32_t)(key >> 3);
        wire_type = (uint32_t)(key & 0x7);
        if (field_no == target_field && wire_type == 1) {
            if (!vfg_read_fixed64(data, len, &pos, &value)) return fallback;
            return vfg_u64_to_double(value);
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

static double vfg_take_double_response(uint8_t *data, int32_t len, double fallback) {
    double out = fallback;
    if (!data) return fallback;
    out = vfg_decode_double_field(data, len, 2, fallback);
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

#define VG_WRAP_STATUS_6(name, t1, a1, t2, a2, t3, a3, t4, a4, t5, a5, t6, a6) \
static int32_t name##_compat(t1 a1, t2 a2, t3 a3, t4 a4, t5 a5, t6 a6) { \
    int32_t out_len = 0; \
    uint8_t *out = name(a1, a2, a3, a4, a5, a6, &out_len); \
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
VG_WRAP_I32_1(volvox_grid_get_combo_count, int64_t, id)
VG_WRAP_I32_1(volvox_grid_get_combo_index, int64_t, id)
VG_WRAP_I32_1(volvox_grid_get_cols, int64_t, id)
VG_WRAP_I32_1(volvox_grid_get_edit_max_length, int64_t, id)
VG_WRAP_I32_2(volvox_grid_get_is_collapsed, int64_t, grid_id, int32_t, index)
VG_WRAP_I32_2(volvox_grid_get_is_subtotal, int64_t, grid_id, int32_t, index)
VG_WRAP_I32_1(volvox_grid_get_mouse_col, int64_t, id)
VG_WRAP_I32_1(volvox_grid_get_mouse_row, int64_t, id)
VG_WRAP_I32_1(volvox_grid_get_row, int64_t, id)
VG_WRAP_I32_2(volvox_grid_get_row_height, int64_t, grid_id, int32_t, index)
VG_WRAP_I32_2(volvox_grid_get_row_is_visible, int64_t, grid_id, int32_t, index)
VG_WRAP_I32_2(volvox_grid_get_row_outline_level, int64_t, grid_id, int32_t, index)
VG_WRAP_I32_1(volvox_grid_get_rows, int64_t, id)
VG_WRAP_I32_1(volvox_grid_get_picture_type, int64_t, id)
VG_WRAP_I32_1(volvox_grid_get_scroll_tips, int64_t, id)
VG_WRAP_I32_1(volvox_grid_get_combo_search, int64_t, id)
VG_WRAP_I32_1(volvox_grid_get_owner_draw, int64_t, id)
VG_WRAP_I32_1(volvox_grid_get_group_compare, int64_t, id)
VG_WRAP_STATUS_2(volvox_grid_remove_item, int64_t, grid_id, int32_t, index)
VG_WRAP_STATUS_4(volvox_grid_set_cell_checked, int64_t, grid_id, int32_t, row, int32_t, col, int32_t, state)
VG_WRAP_STATUS_5(volvox_grid_set_cell_flood, int64_t, grid_id, int32_t, row, int32_t, col, uint32_t, color, float, percent)
VG_WRAP_STATUS_6(volvox_grid_set_cell_back_color_range, int64_t, grid_id, int32_t, row1, int32_t, col1, int32_t, row2, int32_t, col2, uint32_t, color)
VG_WRAP_STATUS_6(volvox_grid_set_cell_font_bold_range, int64_t, grid_id, int32_t, row1, int32_t, col1, int32_t, row2, int32_t, col2, int32_t, bold)
VG_WRAP_STATUS_4(volvox_grid_set_col_combo_list, int64_t, grid_id, int32_t, col, const uint8_t*, list, int32_t, list_len)
VG_WRAP_STATUS_3(volvox_grid_set_combo_list, int64_t, grid_id, const uint8_t*, list, int32_t, list_len)
VG_WRAP_STATUS_3(volvox_grid_set_col_data_type, int64_t, grid_id, int32_t, col, int32_t, data_type)
static int32_t volvox_grid_set_col_position_compat(int64_t grid_id, int32_t col, int32_t position);
static int32_t volvox_grid_set_col_width_compat(int64_t grid_id, int32_t col, int32_t width);
VG_WRAP_STATUS_2(volvox_grid_set_auto_resize, int64_t, grid_id, int32_t, value)
VG_WRAP_STATUS_2(volvox_grid_set_combo_index, int64_t, grid_id, int32_t, value)
VG_WRAP_STATUS_2(volvox_grid_set_edit_max_length, int64_t, grid_id, int32_t, value)
VG_WRAP_STATUS_2(volvox_grid_set_fixed_cols, int64_t, grid_id, int32_t, fixed_cols)
VG_WRAP_STATUS_2(volvox_grid_set_fixed_rows, int64_t, grid_id, int32_t, fixed_rows)
static int32_t volvox_grid_set_is_collapsed_compat(int64_t grid_id, int32_t row, int32_t collapsed);
VG_WRAP_STATUS_3(volvox_grid_set_is_subtotal, int64_t, grid_id, int32_t, row, int32_t, is_subtotal)
VG_WRAP_STATUS_2(volvox_grid_set_picture_type, int64_t, grid_id, int32_t, value)
VG_WRAP_STATUS_2(volvox_grid_set_scroll_tips, int64_t, grid_id, int32_t, value)
VG_WRAP_STATUS_2(volvox_grid_set_combo_search, int64_t, grid_id, int32_t, value)
VG_WRAP_STATUS_2(volvox_grid_set_owner_draw, int64_t, grid_id, int32_t, value)
VG_WRAP_STATUS_2(volvox_grid_set_group_compare, int64_t, grid_id, int32_t, value)
VG_WRAP_STATUS_2(volvox_grid_set_merge_cells_fixed, int64_t, grid_id, int32_t, value)
VG_WRAP_STATUS_4(volvox_grid_set_row_data, int64_t, grid_id, int32_t, col, const uint8_t*, data, int32_t, data_len)
static int32_t volvox_grid_set_row_height_compat(int64_t grid_id, int32_t row, int32_t height);
static int32_t volvox_grid_set_row_position_compat(int64_t grid_id, int32_t row, int32_t position);
VG_WRAP_STATUS_2(volvox_grid_set_show_combo_button, int64_t, grid_id, int32_t, mode)
VG_WRAP_STATUS_2(volvox_grid_set_subtotal_position, int64_t, grid_id, int32_t, position)
VG_WRAP_STATUS_5(volvox_grid_set_text_matrix, int64_t, grid_id, int32_t, row, int32_t, col, const uint8_t*, text, int32_t, text_len)
VG_WRAP_STATUS_3(volvox_grid_show_cell, int64_t, grid_id, int32_t, row, int32_t, col)
VG_WRAP_STATUS_3(volvox_grid_load_demo, int64_t, grid_id, const uint8_t*, demo, int32_t, demo_len)

static int32_t volvox_grid_auto_size_compat(
    int64_t grid_id, int32_t col_from, int32_t col_to, int32_t equal, int32_t max_width)
{
    int32_t out_len = 0;
    uint8_t *out = volvox_grid_auto_size(grid_id, col_from, col_to, equal, max_width, &out_len);
    return vfg_take_status_response(out);
}

static int32_t vfg_legacy_clear_scope_to_proto(int32_t scope) {
    switch (scope) {
    case 0: return 1; /* flexClearEverything -> CLEAR_EVERYTHING */
    case 1: return 2; /* flexClearFormatting -> CLEAR_FORMATTING */
    case 2: return 3; /* flexClearData -> CLEAR_DATA */
    case 3: return 4; /* flexClearSelection -> CLEAR_SELECTION */
    default: return scope;
    }
}

static int32_t volvox_grid_clear_compat(int64_t grid_id, int32_t scope, int32_t region) {
    int32_t out_len = 0;
    uint8_t *out = volvox_grid_clear(
        grid_id,
        vfg_legacy_clear_scope_to_proto(scope),
        region,
        &out_len);
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

/* Forward-declare protobuf-based helpers (generated header may be stale). */
uint8_t* volvox_grid_clipboard_pb(const uint8_t* data, int32_t data_len, int32_t* out_len);
uint8_t* volvox_grid_edit_pb(const uint8_t* data, int32_t data_len, int32_t* out_len);
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

static int vfg_varint_len(uint64_t v) {
    int n = 1;
    while (v > 0x7F) {
        v >>= 7;
        n++;
    }
    return n;
}

static void vfg_map_sort_spec(int32_t spec, int32_t *order, int32_t *type, int *has_type) {
    if (order) *order = spec;
    if (type) *type = 0;
    if (has_type) *has_type = 0;

    switch (spec) {
    case 0:
        if (order) *order = 0;
        break;
    case 1:
        if (order) *order = 1;
        break;
    case 2:
        if (order) *order = 2;
        break;
    case 3:
        if (order) *order = 1;
        if (type) *type = 1;
        if (has_type) *has_type = 1;
        break;
    case 4:
        if (order) *order = 2;
        if (type) *type = 1;
        if (has_type) *has_type = 1;
        break;
    case 5:
        if (order) *order = 1;
        if (type) *type = 3;
        if (has_type) *has_type = 1;
        break;
    case 6:
        if (order) *order = 2;
        if (type) *type = 3;
        if (has_type) *has_type = 1;
        break;
    case 7:
        if (order) *order = 1;
        if (type) *type = 2;
        if (has_type) *has_type = 1;
        break;
    case 8:
        if (order) *order = 2;
        if (type) *type = 2;
        if (has_type) *has_type = 1;
        break;
    case 9:
        if (order) *order = 1;
        if (type) *type = 4;
        if (has_type) *has_type = 1;
        break;
    case 11:
        if (order) *order = 2;
        if (type) *type = 4;
        if (has_type) *has_type = 1;
        break;
    default:
        break;
    }
}

/* Sort now uses protobuf-encoded SortRequest (repeated SortColumn). */
static int32_t volvox_grid_sort_compat(int64_t grid_id, int32_t order, int32_t col) {
    /*  SortRequest {
     *    int64 grid_id      = 1;  // varint
     *    repeated SortColumn sort_columns = 2;  // length-delimited
     *      SortColumn { int32 col = 1; optional SortOrder order = 2; optional SortType type = 3; }
     *  }
     */
    uint8_t buf[64];
    int pos = 0;
    int32_t proto_order = order;
    int32_t proto_type = 0;
    int has_type = 0;

    vfg_map_sort_spec(order, &proto_order, &proto_type, &has_type);

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
    if (proto_order != 0) {
        inner[ilen++] = 0x10;
        ilen += vfg_write_varint(inner + ilen, (uint64_t)(uint32_t)proto_order);
    }
    /* SortColumn.type (field 3, varint, tag = 0x18) */
    if (has_type) {
        inner[ilen++] = 0x18;
        ilen += vfg_write_varint(inner + ilen, (uint64_t)(uint32_t)proto_type);
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
static int32_t vfg_compat_default_col_width_px(float font_px);
static HRESULT vfg_fire_event(VolvoxGridObject *obj, DISPID dispid, VARIANT *args, UINT cArgs);
static int32_t vfg_custom_compare_callback(
    void *user_data, int32_t row1, int32_t row2, int32_t col);


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

static uint8_t *vfg_native_set_top_row(int64_t grid_id, int32_t row, int32_t *out_len) {
    return volvox_grid_set_top_row(grid_id, row, out_len);
}

static uint8_t *vfg_native_set_left_col(int64_t grid_id, int32_t col, int32_t *out_len) {
    return volvox_grid_set_left_col(grid_id, col, out_len);
}

static uint8_t *vfg_native_set_row_position(
    int64_t grid_id, int32_t row, int32_t position, int32_t *out_len)
{
    return volvox_grid_set_row_position(grid_id, row, position, out_len);
}

static uint8_t *vfg_native_set_col_position(
    int64_t grid_id, int32_t col, int32_t position, int32_t *out_len)
{
    return volvox_grid_set_col_position(grid_id, col, position, out_len);
}

static uint8_t *vfg_native_set_row_height(
    int64_t grid_id, int32_t row, int32_t height, int32_t *out_len)
{
    return volvox_grid_set_row_height(grid_id, row, height, out_len);
}

static uint8_t *vfg_native_set_col_width(
    int64_t grid_id, int32_t col, int32_t width, int32_t *out_len)
{
    return volvox_grid_set_col_width(grid_id, col, width, out_len);
}

static uint8_t *vfg_native_set_is_collapsed(
    int64_t grid_id, int32_t row, int32_t collapsed, int32_t *out_len)
{
    return volvox_grid_set_is_collapsed(grid_id, row, collapsed, out_len);
}

static uint8_t *vfg_native_select(
    int64_t grid_id, int32_t row1, int32_t col1, int32_t row2, int32_t col2, int32_t *out_len)
{
    return volvox_grid_select(grid_id, row1, col1, row2, col2, out_len);
}

/* Compat wrappers for generated dispatch (simple int set/get properties) */
VG_WRAP_STATUS_2(volvox_grid_set_scroll_bars, int64_t, grid_id, int32_t, mode)
static int32_t volvox_grid_set_top_row_compat(int64_t grid_id, int32_t row);
static int32_t volvox_grid_set_left_col_compat(int64_t grid_id, int32_t col);
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
VG_WRAP_STATUS_2(volvox_grid_outline, int64_t, grid_id, int32_t, level)
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
#define volvox_grid_get_edit_max_length volvox_grid_get_edit_max_length_compat
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
#define volvox_grid_set_cell_back_color_range volvox_grid_set_cell_back_color_range_compat
#define volvox_grid_set_cell_checked volvox_grid_set_cell_checked_compat
#define volvox_grid_set_cell_font_bold_range volvox_grid_set_cell_font_bold_range_compat
#define volvox_grid_set_cell_flood volvox_grid_set_cell_flood_compat
#define volvox_grid_set_col volvox_grid_set_col_compat
#define volvox_grid_set_col_alignment volvox_grid_set_col_alignment_compat
#define volvox_grid_set_col_combo_list volvox_grid_set_col_combo_list_compat
#define volvox_grid_set_combo_list volvox_grid_set_combo_list_compat
#define volvox_grid_set_col_data_type volvox_grid_set_col_data_type_compat
#define volvox_grid_set_col_hidden volvox_grid_set_col_hidden_compat
#define volvox_grid_set_col_position volvox_grid_set_col_position_compat
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
#define volvox_grid_set_edit_max_length volvox_grid_set_edit_max_length_compat
#define volvox_grid_set_is_collapsed volvox_grid_set_is_collapsed_compat
#define volvox_grid_set_is_subtotal volvox_grid_set_is_subtotal_compat
#define volvox_grid_set_left_col volvox_grid_set_left_col_compat
#define volvox_grid_set_merge_cells volvox_grid_set_merge_cells_compat
#define volvox_grid_set_merge_col volvox_grid_set_merge_col_compat
#define volvox_grid_set_merge_row volvox_grid_set_merge_row_compat
#define volvox_grid_outline volvox_grid_outline_compat
#define volvox_grid_set_outline_bar volvox_grid_set_outline_bar_compat
#define volvox_grid_set_outline_col volvox_grid_set_outline_col_compat
#define volvox_grid_set_redraw volvox_grid_set_redraw_compat
#define volvox_grid_set_row volvox_grid_set_row_compat
#define volvox_grid_set_row_data volvox_grid_set_row_data_compat
#define volvox_grid_set_row_height volvox_grid_set_row_height_compat
#define volvox_grid_set_row_hidden volvox_grid_set_row_hidden_compat
#define volvox_grid_set_row_outline_level volvox_grid_set_row_outline_level_compat
#define volvox_grid_set_row_position volvox_grid_set_row_position_compat
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
#define DISPID_VG_FINDROW_COMPAT      160
#define DISPID_VG_FINDROWREGEX_COMPAT 222
#define DISPID_VG_DATASOURCE_COMPAT   69
#define DISPID_VG_DATAMODE_COMPAT     98
#define DISPID_VG_DATAMEMBER_COMPAT   68
#define DISPID_VG_VIRTUALDATA_COMPAT  70
#define DISPID_VG_DATAREFRESH_COMPAT  148
#define DISPID_VG_AUTORESIZE_COMPAT   85
#define DISPID_VG_COLINDEX_COMPAT     186
#define DISPID_VG_COLDATA_COMPAT      127
#define DISPID_VG_COLKEY_COMPAT       185
#define DISPID_VG_COLFORMAT_COMPAT    156
#define DISPID_VG_COLEDITMASK_COMPAT  164
#define DISPID_VG_FORMATSTRING_COMPAT 10
#define DISPID_VG_EDITTEXT_COMPAT     91
#define DISPID_VG_EDITMAXLENGTH_COMPAT 116
#define DISPID_VG_COMBOLIST_COMPAT    72
#define DISPID_VG_COMBOCOUNT_COMPAT   118
#define DISPID_VG_COMBOINDEX_COMPAT   117
#define DISPID_VG_COMBOITEM_COMPAT    161
#define DISPID_VG_COMBODATA_COMPAT    162
#define DISPID_VG_MOUSEROW_COMPAT     33
#define DISPID_VG_MOUSECOL_COMPAT     34
#define DISPID_VG_SHOWCELL_COMPAT     198
#define DISPID_VG_VALUEMATRIX_COMPAT  133
#define DISPID_VG_BUILDCOMBOLIST_COMPAT 195
#define DISPID_VG_CELLBUTTONPICTURE_COMPAT 177
#define DISPID_VG_FOCUS_COMPAT        30026
#define DISPID_VG_MOUSEPOINTER_COMPAT -521
#define DISPID_VG_APPEARANCE_COMPAT   -520
#define DISPID_VG_BACKCOLORBKG_COMPAT 24
#define DISPID_VG_BACKCOLORFROZEN_COMPAT 191
#define DISPID_VG_FLOODCOLOR_COMPAT   74
#define DISPID_VG_FORECOLORFROZEN_COMPAT 192
#define DISPID_VG_GRIDCOLORFIXED_COMPAT 44
#define DISPID_VG_CELLPICTURE_COMPAT 49
#define DISPID_VG_CELLPICTUREALIGNMENT_COMPAT 50
#define DISPID_VG_CLIP_COMPAT         59
#define DISPID_VG_BOTTOMROW_COMPAT    86
#define DISPID_VG_RIGHTCOL_COMPAT     87
#define DISPID_VG_ROWISVISIBLE_COMPAT 139
#define DISPID_VG_COLISVISIBLE_COMPAT 140
#define DISPID_VG_ROWPOS_COMPAT       141
#define DISPID_VG_COLPOS_COMPAT       142
#define DISPID_VG_ISSELECTED_COMPAT   143
#define DISPID_VG_SAVEGRID_COMPAT     151
#define DISPID_VG_LOADGRID_COMPAT     152
#define DISPID_VG_SELECTEDROWS_COMPAT 167
#define DISPID_VG_SELECTEDROW_COMPAT  168
#define DISPID_VG_SCROLLTIPTEXT_COMPAT 170
#define DISPID_VG_CLIPSEPARATORS_COMPAT 182
#define DISPID_VG_LOADGRIDURL_COMPAT  210
#define DISPID_VG_FINISHEDITING_COMPAT 211
#define DISPID_VG_FLAGS_COMPAT        217
#define DISPID_VG_CUT_COMPAT          224
#define DISPID_VG_COPY_COMPAT         225
#define DISPID_VG_PASTE_COMPAT        226
#define DISPID_VG_DELETE_COMPAT       227
#define DISPID_VG_VERSION_COMPAT      9
#define DISPID_VG_CLIENTWIDTH_COMPAT  89
#define DISPID_VG_CLIENTHEIGHT_COMPAT 90
#define DISPID_VG_ISSEARCHING_COMPAT  216
#define DISPID_VG_SHEETBORDER_COMPAT  102
#define DISPID_VG_FONTBOLD_COMPAT     3
#define DISPID_VG_FONTITALIC_COMPAT   4
#define DISPID_VG_FONTSTRIKETHRU_COMPAT 5
#define DISPID_VG_FONTUNDERLINE_COMPAT 6
#define DISPID_VG_FONTWIDTH_COMPAT    58
#define DISPID_VG_ALLOWUSERFREEZING_COMPAT 190
#define DISPID_VG_EXPLORERBAR_COMPAT  111
#define DISPID_VG_TABBEHAVIOR_COMPAT  101
#define DISPID_VG_COLWIDTHMIN_COMPAT  173
#define DISPID_VG_ROWHEIGHTMIN_COMPAT 39
#define DISPID_VG_GRIDLINEWIDTH_COMPAT 84
#define DISPID_VG_SCROLLTIPS_COMPAT   169
#define DISPID_VG_COMBOSEARCH_COMPAT  178
#define DISPID_VG_PICTURETYPE_COMPAT  64
#define DISPID_VG_PICTURESOVER_COMPAT 104
#define DISPID_VG_OWNERDRAW_COMPAT    97
#define DISPID_VG_OLEDRAGMODE_COMPAT  99
#define DISPID_VG_OLEDROPMODE_COMPAT  100
#define DISPID_VG_ROWPOSITION_COMPAT  124
#define DISPID_VG_COLPOSITION_COMPAT  125
#define DISPID_VG_VALUE_COMPAT        73
#define DISPID_VG_COLIMAGELIST_COMPAT 184
#define DISPID_VG_NODEOPENPICTURE_COMPAT 196
#define DISPID_VG_NODECLOSEDPICTURE_COMPAT 197
#define DISPID_VG_SORTASCENDINGPICTURE_COMPAT 220
#define DISPID_VG_SORTDESCENDINGPICTURE_COMPAT 221
#define DISPID_VG_WALLPAPER_COMPAT    201
#define DISPID_VG_WALLPAPERALIGNMENT_COMPAT 202
#define DISPID_VG_COLINDENT_COMPAT    207
#define DISPID_VG_MERGECELLSFIXED_COMPAT 218
#define DISPID_VG_GROUPCOMPARE_COMPAT 219
#define DISPID_VG_GETSELECTION_COMPAT 181
#define DISPID_VG_GETMERGEDRANGE_COMPAT 175
#define DISPID_VG_OUTLINE_COMPAT      137
#define DISPID_VG_AGGREGATE_COMPAT    203
#define DISPID_VG_CELLBORDER_COMPAT   149
#define DISPID_VG_OLEDRAG_COMPAT      150
#define DISPID_VG_CELLBORDERRANGE_COMPAT 223
#define DISPID_VG_PRINTGRID_COMPAT    183
#define DISPID_VG_ARCHIVE_COMPAT      153
#define DISPID_VG_ARCHIVEINFO_COMPAT  154
#define DISPID_VG_DRAGROW_COMPAT      204
#define DISPID_VG_BINDTOARRAY_COMPAT  163
#define DISPID_VG_LOADARRAY_COMPAT    179
#define DISPID_VG_HEIGHT_COMPAT       30095
#define DISPID_VG_WIDTH_COMPAT        30096

/* Internal helper methods are not part of the public ActiveX contract.
 * Keep them late-bound for local tooling, but move them out of the compatibility range. */
#define DISPID_VG_LOADDEMO_INTERNAL        30083
#define DISPID_VG_RESIZEVIEWPORT_INTERNAL  30084
#define DISPID_VG_POINTERDOWN_INTERNAL     30085
#define DISPID_VG_POINTERMOVE_INTERNAL     30086
#define DISPID_VG_POINTERUP_INTERNAL       30087
#define DISPID_VG_SCROLL_INTERNAL          30088
#define DISPID_VG_KEYDOWN_INTERNAL         30089
#define DISPID_VG_KEYPRESS_INTERNAL        30090
#define DISPID_VG_SETHOVERMODE_INTERNAL    30091
#define DISPID_VG_SETDEBUGOVERLAY_INTERNAL 30092
#define DISPID_VG_SETSCROLLBLIT_INTERNAL   30093
#define DISPID_VG_IMECOMPOSITION_INTERNAL  30094
#define DISPID_VG_GRIDSTYLE_INTERNAL       30026
#define DISPID_VG_CELLFLOOD_INTERNAL       30065

/* Remap the generated surface onto the compatibility DISPIDs. */
#undef DISPID_VG_ROWS
#define DISPID_VG_ROWS 7
#undef DISPID_VG_COLS
#define DISPID_VG_COLS 8
#undef DISPID_VG_FIXEDROWS
#define DISPID_VG_FIXEDROWS 11
#undef DISPID_VG_FIXEDCOLS
#define DISPID_VG_FIXEDCOLS 12
#undef DISPID_VG_TEXTMATRIX
#define DISPID_VG_TEXTMATRIX 130
#undef DISPID_VG_TEXT
#define DISPID_VG_TEXT 0
#undef DISPID_VG_ROW
#define DISPID_VG_ROW 17
#undef DISPID_VG_COL
#define DISPID_VG_COL 18
#undef DISPID_VG_ROWHEIGHT
#define DISPID_VG_ROWHEIGHT 121
#undef DISPID_VG_COLWIDTH
#define DISPID_VG_COLWIDTH 120
#undef DISPID_VG_FROZENROWS
#define DISPID_VG_FROZENROWS 188
#undef DISPID_VG_FROZENCOLS
#define DISPID_VG_FROZENCOLS 189
#undef DISPID_VG_SCROLLBARS
#define DISPID_VG_SCROLLBARS 32
#undef DISPID_VG_TOPROW
#define DISPID_VG_TOPROW 13
#undef DISPID_VG_LEFTCOL
#define DISPID_VG_LEFTCOL 14
#undef DISPID_VG_FOCUSRECT
#define DISPID_VG_FOCUSRECT 29
#undef DISPID_VG_HIGHLIGHT
#define DISPID_VG_HIGHLIGHT 30
#undef DISPID_VG_REDRAW
#define DISPID_VG_REDRAW 31
#undef DISPID_VG_PICTURE
#define DISPID_VG_PICTURE -523
#undef DISPID_VG_TEXTARRAY
#define DISPID_VG_TEXTARRAY 144
#undef DISPID_VG_EDITABLE
#define DISPID_VG_EDITABLE 71
#undef DISPID_VG_ROWSEL
#define DISPID_VG_ROWSEL 15
#undef DISPID_VG_COLSEL
#define DISPID_VG_COLSEL 16
#undef DISPID_VG_FILLSTYLE
#define DISPID_VG_FILLSTYLE 40
#undef DISPID_VG_WORDWRAP
#define DISPID_VG_WORDWRAP 25
#undef DISPID_VG_GRIDSTYLE
#define DISPID_VG_GRIDSTYLE DISPID_VG_GRIDSTYLE_INTERNAL
#undef DISPID_VG_SELECTIONMODE
#define DISPID_VG_SELECTIONMODE 61
#undef DISPID_VG_ALLOWSELECTION
#define DISPID_VG_ALLOWSELECTION 103
#undef DISPID_VG_ALLOWBIGSELECTION
#define DISPID_VG_ALLOWBIGSELECTION 65
#undef DISPID_VG_ALLOWUSERRESIZING
#define DISPID_VG_ALLOWUSERRESIZING 66
#undef DISPID_VG_ELLIPSIS
#define DISPID_VG_ELLIPSIS 107
#undef DISPID_VG_EXTENDLASTCOL
#define DISPID_VG_EXTENDLASTCOL 88
#undef DISPID_VG_SUBTOTALPOSITION
#define DISPID_VG_SUBTOTALPOSITION 77
#undef DISPID_VG_BACKCOLOR
#define DISPID_VG_BACKCOLOR -501
#undef DISPID_VG_FORECOLOR
#define DISPID_VG_FORECOLOR -513
#undef DISPID_VG_GRIDCOLOR
#define DISPID_VG_GRIDCOLOR 43
#undef DISPID_VG_BACKCOLORFIXED
#define DISPID_VG_BACKCOLORFIXED 20
#undef DISPID_VG_FORECOLORFIXED
#define DISPID_VG_FORECOLORFIXED 21
#undef DISPID_VG_BACKCOLORSEL
#define DISPID_VG_BACKCOLORSEL 22
#undef DISPID_VG_FORECOLORSEL
#define DISPID_VG_FORECOLORSEL 23
#undef DISPID_VG_BACKCOLORALTERNATE
#define DISPID_VG_BACKCOLORALTERNATE 96
#undef DISPID_VG_GRIDLINES
#define DISPID_VG_GRIDLINES 41
#undef DISPID_VG_GRIDLINESFIXED
#define DISPID_VG_GRIDLINESFIXED 42
#undef DISPID_VG_TREECOLOR
#define DISPID_VG_TREECOLOR 83
#undef DISPID_VG_MERGECELLS
#define DISPID_VG_MERGECELLS 62
#undef DISPID_VG_MERGEROW
#define DISPID_VG_MERGEROW 122
#undef DISPID_VG_MERGECOL
#define DISPID_VG_MERGECOL 123
#undef DISPID_VG_OUTLINEBAR
#define DISPID_VG_OUTLINEBAR 82
#undef DISPID_VG_OUTLINECOL
#define DISPID_VG_OUTLINECOL 108
#undef DISPID_VG_ISSUBTOTAL
#define DISPID_VG_ISSUBTOTAL 134
#undef DISPID_VG_ISCOLLAPSED
#define DISPID_VG_ISCOLLAPSED 145
#undef DISPID_VG_ROWOUTLINELEVEL
#define DISPID_VG_ROWOUTLINELEVEL 166
#undef DISPID_VG_CELL
#define DISPID_VG_CELL 158
#undef DISPID_VG_COLALIGNMENT
#define DISPID_VG_COLALIGNMENT 119
#undef DISPID_VG_FIXEDALIGNMENT
#define DISPID_VG_FIXEDALIGNMENT 138
#undef DISPID_VG_ROWHIDDEN
#define DISPID_VG_ROWHIDDEN 171
#undef DISPID_VG_COLHIDDEN
#define DISPID_VG_COLHIDDEN 172
#undef DISPID_VG_CELLCHECKED
#define DISPID_VG_CELLCHECKED 105
#undef DISPID_VG_CELLFLOOD
#define DISPID_VG_CELLFLOOD DISPID_VG_CELLFLOOD_INTERNAL
#undef DISPID_VG_COLDATATYPE
#define DISPID_VG_COLDATATYPE 157
#undef DISPID_VG_CELLFLOODPERCENT
#define DISPID_VG_CELLFLOODPERCENT 75
#undef DISPID_VG_CELLFLOODCOLOR
#define DISPID_VG_CELLFLOODCOLOR 76
#undef DISPID_VG_ROWDATA
#define DISPID_VG_ROWDATA 126
#undef DISPID_VG_SORT
#define DISPID_VG_SORT 60
#undef DISPID_VG_SUBTOTAL
#define DISPID_VG_SUBTOTAL 135
#undef DISPID_VG_AUTOSIZE
#define DISPID_VG_AUTOSIZE 147
#undef DISPID_VG_ADDITEM
#define DISPID_VG_ADDITEM 128
#undef DISPID_VG_REMOVEITEM
#define DISPID_VG_REMOVEITEM 129
#undef DISPID_VG_CLEAR
#define DISPID_VG_CLEAR 131
#undef DISPID_VG_SELECT
#define DISPID_VG_SELECT 146
#undef DISPID_VG_REFRESH
#define DISPID_VG_REFRESH -550
#undef DISPID_VG_FONTSIZE
#define DISPID_VG_FONTSIZE 2
#undef DISPID_VG_FONTNAME
#define DISPID_VG_FONTNAME 1
#undef DISPID_VG_COLCOMBOLIST
#define DISPID_VG_COLCOMBOLIST 165
#undef DISPID_VG_SHOWCOMBOBUTTON
#define DISPID_VG_SHOWCOMBOBUTTON 176
#undef DISPID_VG_EDITCELL
#define DISPID_VG_EDITCELL 132
#undef DISPID_VG_LOADDEMO
#define DISPID_VG_LOADDEMO DISPID_VG_LOADDEMO_INTERNAL
#undef DISPID_VG_RESIZEVIEWPORT
#define DISPID_VG_RESIZEVIEWPORT DISPID_VG_RESIZEVIEWPORT_INTERNAL
#undef DISPID_VG_POINTERDOWN
#define DISPID_VG_POINTERDOWN DISPID_VG_POINTERDOWN_INTERNAL
#undef DISPID_VG_POINTERMOVE
#define DISPID_VG_POINTERMOVE DISPID_VG_POINTERMOVE_INTERNAL
#undef DISPID_VG_POINTERUP
#define DISPID_VG_POINTERUP DISPID_VG_POINTERUP_INTERNAL
#undef DISPID_VG_SCROLL
#define DISPID_VG_SCROLL DISPID_VG_SCROLL_INTERNAL
#undef DISPID_VG_KEYDOWN
#define DISPID_VG_KEYDOWN DISPID_VG_KEYDOWN_INTERNAL
#undef DISPID_VG_KEYPRESS
#define DISPID_VG_KEYPRESS DISPID_VG_KEYPRESS_INTERNAL
#undef DISPID_VG_SETHOVERMODE
#define DISPID_VG_SETHOVERMODE DISPID_VG_SETHOVERMODE_INTERNAL
#undef DISPID_VG_SETDEBUGOVERLAY
#define DISPID_VG_SETDEBUGOVERLAY DISPID_VG_SETDEBUGOVERLAY_INTERNAL
#undef DISPID_VG_SETSCROLLBLIT
#define DISPID_VG_SETSCROLLBLIT DISPID_VG_SETSCROLLBLIT_INTERNAL
#undef DISPID_VG_IMECOMPOSITION
#define DISPID_VG_IMECOMPOSITION DISPID_VG_IMECOMPOSITION_INTERNAL

static const VG_NameEntry vfg_legacy_names[] = {
    { L"About", -552 },
    { L"FontName", 1 },
    { L"FontSize", 2 },
    { L"FontBold", 3 },
    { L"FontItalic", 4 },
    { L"FontStrikethru", 5 },
    { L"FontUnderline", 6 },
    { L"Rows", 7 },
    { L"Cols", 8 },
    { L"Version", 9 },
    { L"Height", DISPID_VG_HEIGHT_COMPAT },
    { L"Width", DISPID_VG_WIDTH_COMPAT },
    { L"FormatString", 10 },
    { L"FixedRows", 11 },
    { L"FixedCols", 12 },
    { L"TopRow", 13 },
    { L"LeftCol", 14 },
    { L"RowSel", 15 },
    { L"ColSel", 16 },
    { L"Row", 17 },
    { L"Col", 18 },
    { L"Text", 0 },
    { L"BackColor", -501 },
    { L"ForeColor", -513 },
    { L"BackColorFixed", 20 },
    { L"ForeColorFixed", 21 },
    { L"BackColorSel", 22 },
    { L"ForeColorSel", 23 },
    { L"BackColorBkg", 24 },
    { L"WordWrap", 25 },
    { L"TextStyle", 26 },
    { L"TextStyleFixed", 27 },
    { L"ScrollTrack", 28 },
    { L"FocusRect", 29 },
    { L"HighLight", 30 },
    { L"Redraw", 31 },
    { L"ScrollBars", 32 },
    { L"MouseRow", 33 },
    { L"MouseCol", 34 },
    { L"CellLeft", 35 },
    { L"CellTop", 36 },
    { L"CellWidth", 37 },
    { L"CellHeight", 38 },
    { L"RowHeightMin", 39 },
    { L"FillStyle", 40 },
    { L"GridLines", 41 },
    { L"GridLinesFixed", 42 },
    { L"GridColor", 43 },
    { L"GridColorFixed", 44 },
    { L"CellBackColor", 45 },
    { L"CellForeColor", 46 },
    { L"CellAlignment", 47 },
    { L"CellTextStyle", 48 },
    { L"CellPicture", 49 },
    { L"CellPictureAlignment", 50 },
    { L"CellFontName", 51 },
    { L"CellFontSize", 52 },
    { L"CellFontBold", 53 },
    { L"CellFontItalic", 54 },
    { L"CellFontWidth", 55 },
    { L"CellFontUnderline", 56 },
    { L"CellFontStrikethru", 57 },
    { L"FontWidth", 58 },
    { L"Clip", 59 },
    { L"Sort", 60 },
    { L"SelectionMode", 61 },
    { L"MergeCells", 62 },
    { L"Picture", -523 },
    { L"PictureType", 64 },
    { L"AllowBigSelection", 65 },
    { L"AllowUserResizing", 66 },
    { L"MousePointer", -521 },
    { L"MouseIcon", -522 },
    { L"DataMember", 68 },
    { L"DataSource", 69 },
    { L"VirtualData", 70 },
    { L"Editable", 71 },
    { L"ComboList", 72 },
    { L"Value", 73 },
    { L"FloodColor", 74 },
    { L"CellFloodPercent", 75 },
    { L"CellFloodColor", 76 },
    { L"SubtotalPosition", 77 },
    { L"BorderStyle", -504 },
    { L"Font", -512 },
    { L"Enabled", -514 },
    { L"Appearance", -520 },
    { L"OutlineBar", 82 },
    { L"TreeColor", 83 },
    { L"GridLineWidth", 84 },
    { L"AutoResize", 85 },
    { L"BottomRow", 86 },
    { L"RightCol", 87 },
    { L"ExtendLastCol", 88 },
    { L"ClientWidth", 89 },
    { L"ClientHeight", 90 },
    { L"EditText", 91 },
    { L"hWnd", -515 },
    { L"AutoSizeMode", 93 },
    { L"RightToLeft", 94 },
    { L"MultiTotals", 95 },
    { L"BackColorAlternate", 96 },
    { L"OwnerDraw", 97 },
    { L"DataMode", 98 },
    { L"OLEDragMode", 99 },
    { L"OLEDropMode", 100 },
    { L"TabBehavior", 101 },
    { L"SheetBorder", 102 },
    { L"AllowSelection", 103 },
    { L"PicturesOver", 104 },
    { L"CellChecked", 105 },
    { L"MergeCompare", 106 },
    { L"Ellipsis", 107 },
    { L"OutlineCol", 108 },
    { L"RowHeightMax", 109 },
    { L"AutoSearch", 110 },
    { L"ExplorerBar", 111 },
    { L"EditMask", 112 },
    { L"EditSelStart", 113 },
    { L"EditSelLength", 114 },
    { L"EditSelText", 115 },
    { L"EditMaxLength", 116 },
    { L"ComboIndex", 117 },
    { L"ComboCount", 118 },
    { L"ColAlignment", 119 },
    { L"ColWidth", 120 },
    { L"RowHeight", 121 },
    { L"MergeRow", 122 },
    { L"MergeCol", 123 },
    { L"RowPosition", 124 },
    { L"ColPosition", 125 },
    { L"RowData", 126 },
    { L"ColData", 127 },
    { L"AddItem", 128 },
    { L"RemoveItem", 129 },
    { L"TextMatrix", 130 },
    { L"Clear", 131 },
    { L"EditCell", 132 },
    { L"ValueMatrix", 133 },
    { L"IsSubtotal", 134 },
    { L"Subtotal", 135 },
    { L"Refresh", -550 },
    { L"Outline", 137 },
    { L"FixedAlignment", 138 },
    { L"RowIsVisible", 139 },
    { L"ColIsVisible", 140 },
    { L"RowPos", 141 },
    { L"ColPos", 142 },
    { L"IsSelected", 143 },
    { L"TextArray", 144 },
    { L"IsCollapsed", 145 },
    { L"Select", 146 },
    { L"AutoSize", 147 },
    { L"DataRefresh", 148 },
    { L"CellBorder", 149 },
    { L"OLEDrag", 150 },
    { L"SaveGrid", 151 },
    { L"LoadGrid", 152 },
    { L"Archive", 153 },
    { L"ArchiveInfo", 154 },
    { L"ColSort", 155 },
    { L"ColFormat", 156 },
    { L"ColDataType", 157 },
    { L"Cell", 158 },
    { L"RowStatus", 159 },
    { L"FindRow", 160 },
    { L"ComboItem", 161 },
    { L"ComboData", 162 },
    { L"BindToArray", 163 },
    { L"ColEditMask", 164 },
    { L"ColComboList", 165 },
    { L"RowOutlineLevel", 166 },
    { L"SelectedRows", 167 },
    { L"SelectedRow", 168 },
    { L"ScrollTips", 169 },
    { L"ScrollTipText", 170 },
    { L"RowHidden", 171 },
    { L"ColHidden", 172 },
    { L"ColWidthMin", 173 },
    { L"ColWidthMax", 174 },
    { L"GetMergedRange", 175 },
    { L"ShowComboButton", 176 },
    { L"CellButtonPicture", 177 },
    { L"ComboSearch", 178 },
    { L"LoadArray", 179 },
    { L"AutoSizeMouse", 180 },
    { L"GetSelection", 181 },
    { L"ClipSeparators", 182 },
    { L"PrintGrid", 183 },
    { L"ColImageList", 184 },
    { L"ColKey", 185 },
    { L"ColIndex", 186 },
    { L"FrozenRows", 188 },
    { L"FrozenCols", 189 },
    { L"AllowUserFreezing", 190 },
    { L"BackColorFrozen", 191 },
    { L"ForeColorFrozen", 192 },
    { L"FlexDataSource", 193 },
    { L"GetNodeRow", 194 },
    { L"BuildComboList", 195 },
    { L"NodeOpenPicture", 196 },
    { L"NodeClosedPicture", 197 },
    { L"ShowCell", 198 },
    { L"AutoSearchDelay", 199 },
    { L"EditWindow", 200 },
    { L"WallPaper", 201 },
    { L"WallPaperAlignment", 202 },
    { L"Aggregate", 203 },
    { L"DragRow", 204 },
    { L"GetNode", 205 },
    { L"Bookmark", 206 },
    { L"ColIndent", 207 },
    { L"LoadGridURL", 210 },
    { L"FinishEditing", 211 },
    { L"IsSearching", 216 },
    { L"Flags", 217 },
    { L"MergeCellsFixed", 218 },
    { L"GroupCompare", 219 },
    { L"SortAscendingPicture", 220 },
    { L"SortDescendingPicture", 221 },
    { L"FindRowRegex", 222 },
    { L"CellBorderRange", 223 },
    { L"Cut", 224 },
    { L"Copy", 225 },
    { L"Paste", 226 },
    { L"Delete", 227 },
    { NULL, 0 }
};

static const VG_NameEntry vfg_internal_names[] = {
    { L"LoadDemo", DISPID_VG_LOADDEMO_INTERNAL },
    { L"ResizeViewport", DISPID_VG_RESIZEVIEWPORT_INTERNAL },
    { L"PointerDown", DISPID_VG_POINTERDOWN_INTERNAL },
    { L"PointerMove", DISPID_VG_POINTERMOVE_INTERNAL },
    { L"PointerUp", DISPID_VG_POINTERUP_INTERNAL },
    { L"Scroll", DISPID_VG_SCROLL_INTERNAL },
    { L"KeyDown", DISPID_VG_KEYDOWN_INTERNAL },
    { L"KeyPress", DISPID_VG_KEYPRESS_INTERNAL },
    { L"SetHoverMode", DISPID_VG_SETHOVERMODE_INTERNAL },
    { L"SetDebugOverlay", DISPID_VG_SETDEBUGOVERLAY_INTERNAL },
    { L"SetScrollBlit", DISPID_VG_SETSCROLLBLIT_INTERNAL },
    { L"ImeComposition", DISPID_VG_IMECOMPOSITION_INTERNAL },
    { L"GridStyle", DISPID_VG_GRIDSTYLE_INTERNAL },
    { L"CellFlood", DISPID_VG_CELLFLOOD_INTERNAL },
    { L"Focus", DISPID_VG_FOCUS_COMPAT },
    { NULL, 0 }
};

#define DISPID_VFG_EVT_SELCHANGE 1
#define DISPID_VFG_EVT_ROWCOLCHANGE 2
#define DISPID_VFG_EVT_ENTERCELL 3
#define DISPID_VFG_EVT_LEAVECELL 4
#define DISPID_VFG_EVT_BEFOREMOUSEDOWN 5
#define DISPID_VFG_EVT_BEFOREROWCOLCHANGE 6
#define DISPID_VFG_EVT_AFTERROWCOLCHANGE 7
#define DISPID_VFG_EVT_BEFORESELCHANGE 8
#define DISPID_VFG_EVT_AFTERSELCHANGE 9
#define DISPID_VFG_EVT_BEFORESCROLL 10
#define DISPID_VFG_EVT_AFTERSCROLL 11
#define DISPID_VFG_EVT_COMPARE 12
#define DISPID_VFG_EVT_BEFORESORT 13
#define DISPID_VFG_EVT_AFTERSORT 14
#define DISPID_VFG_EVT_BEFOREMOVECOLUMN 15
#define DISPID_VFG_EVT_AFTERMOVECOLUMN 16
#define DISPID_VFG_EVT_BEFOREUSERRESIZE 17
#define DISPID_VFG_EVT_AFTERUSERRESIZE 18
#define DISPID_VFG_EVT_BEFORECOLLAPSE 19
#define DISPID_VFG_EVT_AFTERCOLLAPSE 20
#define DISPID_VFG_EVT_BEFOREEDIT 21
#define DISPID_VFG_EVT_STARTEDIT 22
#define DISPID_VFG_EVT_VALIDATEEDIT 23
#define DISPID_VFG_EVT_AFTEREDIT 24
#define DISPID_VFG_EVT_KEYPRESSEDIT 25
#define DISPID_VFG_EVT_KEYDOWNEDIT 26
#define DISPID_VFG_EVT_KEYUPEDIT 27
#define DISPID_VFG_EVT_CHANGEEDIT 28
#define DISPID_VFG_EVT_BEFOREPAGEBREAK 29
#define DISPID_VFG_EVT_GETHEADERROW 30
#define DISPID_VFG_EVT_STARTPAGE 31
#define DISPID_VFG_EVT_DRAWCELL 32
#define DISPID_VFG_EVT_ERROR 33
#define DISPID_VFG_EVT_CELLBUTTONCLICK 34
#define DISPID_VFG_EVT_BEFORESCROLLTIP 35
#define DISPID_VFG_EVT_AFTERUSERFREEZE 36
#define DISPID_VFG_EVT_OLESTARTDRAG 37
#define DISPID_VFG_EVT_OLEGIVEFEEDBACK 38
#define DISPID_VFG_EVT_OLESETDATA 39
#define DISPID_VFG_EVT_OLECOMPLETEDRAG 40
#define DISPID_VFG_EVT_OLEDRAGOVER 41
#define DISPID_VFG_EVT_OLEDRAGDROP 42
#define DISPID_VFG_EVT_CELLCHANGED 43
#define DISPID_VFG_EVT_BEFOREMOVEROW 44
#define DISPID_VFG_EVT_AFTERMOVEROW 45
#define DISPID_VFG_EVT_SETUPEDITWINDOW 46
#define DISPID_VFG_EVT_OLESETCUSTOMDATAOBJECT 47
#define DISPID_VFG_EVT_SETUPEDITSTYLE 48
#define DISPID_VFG_EVT_COMBODROPDOWN 49
#define DISPID_VFG_EVT_COMBOCLOSEUP 50
#define DISPID_VFG_EVT_STARTAUTOSEARCH 51
#define DISPID_VFG_EVT_ENDAUTOSEARCH 52
#define DISPID_VFG_EVT_CLICK -600
#define DISPID_VFG_EVT_DBLCLICK -601
#define DISPID_VFG_EVT_KEYDOWN -602
#define DISPID_VFG_EVT_KEYPRESS -603
#define DISPID_VFG_EVT_KEYUP -604
#define DISPID_VFG_EVT_MOUSEDOWN -605
#define DISPID_VFG_EVT_MOUSEMOVE -606
#define DISPID_VFG_EVT_MOUSEUP -607
#define DISPID_VFG_EVT_FILTERDATA 80
#define DISPID_VFG_EVT_BEFOREDATAREFRESH 81
#define DISPID_VFG_EVT_AFTERDATAREFRESH 82

#define VFG_PROTO_HIT_BUTTON 3
#define VFG_PROTO_HIT_DROPDOWN 5
#define VFG_PROTO_INTERACTION_BUTTON 3

static const WCHAR VFG_WINDOW_CLASS_NAME[] = L"VolvoxGridActiveXWindow";

/* ════════════════════════════════════════════════════════════════ */
/* VolvoxGrid COM Object                                           */
/* ════════════════════════════════════════════════════════════════ */

/* Forward vtable declarations */
static IDispatchVtbl                 g_VFGDispatchVtbl;
static IViewObjectVtbl               g_VFGViewObjectVtbl;
static IViewObject2Vtbl              g_VFGViewObject2Vtbl;
static IOleObjectVtbl                g_VFGOleObjectVtbl;
static IOleInPlaceObjectVtbl         g_VFGInPlaceObjectVtbl;
static IOleInPlaceActiveObjectVtbl   g_VFGInPlaceActiveObjectVtbl;
static IOleControlVtbl               g_VFGOleControlVtbl;
static IPersistStreamInitVtbl        g_VFGPersistStreamInitVtbl;
static IConnectionPointContainerVtbl g_VFGConnectionPointContainerVtbl;
static IConnectionPointVtbl          g_VFGConnectionPointVtbl;
static IEnumConnectionPointsVtbl     g_VFGConnectionPointsEnumVtbl;
static IEnumConnectionsVtbl          g_VFGConnectionsEnumVtbl;
static IDataObjectVtbl               g_VFGDataObjectVtbl;
static IEnumFORMATETCVtbl            g_VFGFormatEtcEnumVtbl;
static IDropSourceVtbl               g_VFGDropSourceVtbl;
static IDropTargetVtbl               g_VFGDropTargetVtbl;
static IObjectSafetyVtbl             g_VFGObjectSafetyVtbl;

typedef struct VFGSinkEntry {
    DWORD cookie;
    IDispatch *dispatch;
} VFGSinkEntry;

typedef struct VFGVariantSlot {
    DISPID dispid;
    int has_index;
    int32_t index;
    VARIANT value;
    struct VFGVariantSlot *next;
} VFGVariantSlot;

typedef struct VFGStoredDataFormat {
    CLIPFORMAT format;
    BYTE *bytes;
    SIZE_T len;
    struct VFGStoredDataFormat *next;
} VFGStoredDataFormat;

typedef struct VFGFormatEtcEnum {
    IEnumFORMATETCVtbl *lpVtbl;
    LONG ref;
    ULONG index;
    ULONG count;
    FORMATETC formats[3];
} VFGFormatEtcEnum;

typedef struct VFGConnectionPointsEnum {
    IEnumConnectionPointsVtbl *lpVtbl;
    LONG ref;
    VolvoxGridObject *obj;
    ULONG index;
} VFGConnectionPointsEnum;

typedef struct VFGConnectionsEnum {
    IEnumConnectionsVtbl *lpVtbl;
    LONG ref;
    ULONG index;
    ULONG count;
    CONNECTDATA *items;
} VFGConnectionsEnum;

struct VolvoxGridObject {
    IDispatchVtbl                 *lpVtblDispatch;
    IViewObjectVtbl               *lpVtblViewObject;
    IViewObject2Vtbl              *lpVtblViewObject2;
    IOleObjectVtbl                *lpVtblOleObject;
    IOleInPlaceObjectVtbl         *lpVtblInPlaceObject;
    IOleInPlaceActiveObjectVtbl   *lpVtblInPlaceActiveObject;
    IOleControlVtbl               *lpVtblOleControl;
    IPersistStreamInitVtbl        *lpVtblPersistStreamInit;
    IConnectionPointContainerVtbl *lpVtblConnectionPointContainer;
    IConnectionPointVtbl          *lpVtblConnectionPoint;
    IDataObjectVtbl               *lpVtblDataObject;
    IDropSourceVtbl               *lpVtblDropSource;
    IDropTargetVtbl               *lpVtblDropTarget;
    IObjectSafetyVtbl             *lpVtblObjectSafety;
    LONG cRef;
    int64_t grid_id;   /* Active grid handle (-1 = none) */
    IOleClientSite *client_site;
    IOleInPlaceSite *inplace_site;
    IOleInPlaceFrame *inplace_frame;
    IOleInPlaceUIWindow *inplace_uiwindow;
    HWND hwnd_parent;
    HWND hwnd_ctrl;
    RECT pos_rect;
    RECT clip_rect;
    SIZEL extent_himetric;
    int in_place_active;
    int ui_active;
    int frozen_events;
    int has_focus;
    int dirty;
    int event_timer_active;
    DWORD object_safety_options;
    BSTR host_app_name;
    BSTR host_obj_name;
    VFGSinkEntry *sinks;
    UINT sink_count;
    UINT sink_capacity;
    DWORD next_sink_cookie;
    int32_t fixed_rows_cached;
    int32_t fixed_cols_cached;
    int32_t bound_fixed_cols;
    int32_t bound_data_col_offset;
    int32_t bound_col_width_uses_data_offset;
    int32_t has_bound_layout;
    int32_t show_combo_button_explicit;
    int32_t frozen_rows_cached;
    int32_t frozen_cols_cached;
    int32_t row_sel_cached;
    int32_t col_sel_cached;
    int32_t data_mode;
    int32_t virtual_data;
    int32_t auto_resize;
    int32_t bound_virtual_active;
    int32_t bound_record_count;
    int32_t bound_window_start;
    int32_t bound_window_end;
    int32_t suppress_bound_cursor_sync;
    int32_t suppress_bound_text_writes;
    int32_t edit_max_length_empty;
    int32_t mouse_pointer_cached;
    int32_t col_width_min_twips;
    int32_t row_height_min_twips;
    int32_t *col_data_type_cache;
    int32_t col_data_type_cache_len;
    BSTR *col_data_cache;
    int32_t col_data_cache_len;
    BSTR *col_key_cache;
    int32_t col_key_cache_len;
    BSTR *col_format_cache;
    int32_t col_format_cache_len;
    BSTR *col_edit_mask_cache;
    int32_t col_edit_mask_cache_len;
    BSTR *col_combo_list_cache;
    int32_t col_combo_list_cache_len;
    int32_t *col_indent_cache;
    int32_t col_indent_cache_len;
    int32_t *is_collapsed_cache;
    int32_t is_collapsed_cache_len;
    IDispatch *data_source;
    IDispatch *recordset;
    BSTR data_member;
    int32_t sort_order_cached;
    int32_t ole_drag_mode_cached;
    int32_t ole_drop_mode_cached;
    int ole_initialized;
    int drop_registered;
    volvox_grid_owner_draw_callback_fn owner_draw_callback;
    void *owner_draw_callback_ctx;
    volvox_grid_owner_draw_measure_fn owner_draw_measure_callback;
    void *owner_draw_measure_ctx;
    int32_t owner_draw_reply_done;
    VARIANT height_cached;
    VARIANT width_cached;
    int32_t last_pointer_button;
    int32_t last_pointer_modifier;
    float last_pointer_x;
    float last_pointer_y;
    struct FloodColorEntry *flood_colors;
    VFGVariantSlot *compat_values;
    VFGStoredDataFormat *stored_data;
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
static void vfg_clear_is_collapsed_cache(VolvoxGridObject *obj);
static void vfg_release_dispatch(IDispatch **ppDisp);
static void vfg_clear_ado_binding(VolvoxGridObject *obj);
static HRESULT vfg_raise_vb_error(EXCEPINFO *pExcepInfo, WORD wCode, LPCOLESTR description);
static HRESULT vfg_dispatch_get(IDispatch *pDisp, LPCOLESTR name, VARIANT *pResult);
static HRESULT vfg_dispatch_get_indexed(IDispatch *pDisp, LPCOLESTR name, long index, VARIANT *pResult);
static HRESULT vfg_map_excepinfo(HRESULT hr, EXCEPINFO *ei);
static HRESULT vfg_rebind_ado_source(VolvoxGridObject *obj);
static HRESULT vfg_sync_bound_state(VolvoxGridObject *obj, DISPID dispid, WORD wFlags);
static HRESULT vfg_bound_fetch_window(VolvoxGridObject *obj, int32_t start_row, int32_t row_count);
static HRESULT vfg_bound_fetch_visible_window(VolvoxGridObject *obj);
static HRESULT vfg_bound_move_recordset_to_row(VolvoxGridObject *obj, int32_t row);
static HRESULT vfg_bound_add_item(VolvoxGridObject *obj, BSTR item, int32_t index);
static HRESULT vfg_bound_remove_item(VolvoxGridObject *obj, int32_t index);
static HRESULT vfg_variant_to_display_bstr(VARIANT *pv, BSTR *pValue);
static int vfg_variant_is_true(const VARIANT *pv);
static HRESULT vfg_set_text_matrix_bstr(int64_t gid, int32_t row, int32_t col, BSTR text);
static int32_t activex_col_data_type_to_engine(int32_t dt);
static int32_t vfg_bound_physical_col_offset(VolvoxGridObject *obj);
static void vfg_sync_selection_cache_from_cursor(VolvoxGridObject *obj);
static void vfg_free_bstr_cache(BSTR *cache, int32_t len);
static void vfg_set_cached_indexed_bstr(BSTR **cache, int32_t *pLen, int32_t index, BSTR value);
static BSTR vfg_copy_cached_indexed_bstr(BSTR *cache, int32_t len, int32_t index);
static void vfg_set_cached_indexed_i32(int32_t **cache, int32_t *pLen, int32_t index, int32_t value);
static void vfg_free_variant_slots(VFGVariantSlot *slot);
static void vfg_clear_stored_data_formats(VolvoxGridObject *obj);
static HRESULT vfg_set_variant_slot(
    VFGVariantSlot **pHead, DISPID dispid, int has_index, int32_t index, VARIANT *value);
static HRESULT vfg_copy_variant_slot(
    VFGVariantSlot *head, DISPID dispid, int has_index, int32_t index, VARIANT *out);
static HRESULT vfg_build_combo_list_from_recordset(
    IDispatch *pRS,
    BSTR fieldList,
    BSTR keyField,
    BSTR *pResult);
static void vfg_set_bstr_copy(BSTR *target, BSTR value);
static void vfg_free_sink_entries(VolvoxGridObject *obj);
static HRESULT vfg_fire_event(VolvoxGridObject *obj, DISPID dispid, VARIANT *args, UINT cArgs);
static HRESULT vfg_fire_before_edit_event(
    VolvoxGridObject *obj, int32_t row, int32_t col, VARIANT_BOOL *cancel);
static HRESULT vfg_fire_before_sort_event(
    VolvoxGridObject *obj, int32_t col, short *order_io);
static HRESULT vfg_fire_before_data_refresh_event(
    VolvoxGridObject *obj, VARIANT_BOOL *cancel);
static void vfg_fire_ado_data_error_event(VolvoxGridObject *obj, HRESULT hr);
static void vfg_fire_after_row_col_change_event(
    VolvoxGridObject *obj, int32_t old_row, int32_t old_col, int32_t new_row, int32_t new_col);
static void vfg_fire_start_edit_event(
    VolvoxGridObject *obj, int32_t row, int32_t col, VARIANT_BOOL *cancel);
static void vfg_fire_after_edit_event(VolvoxGridObject *obj, int32_t row, int32_t col);
static void vfg_fire_validate_edit_event(
    VolvoxGridObject *obj, int32_t row, int32_t col, VARIANT_BOOL *cancel);
static void vfg_fire_before_sel_change_event(
    VolvoxGridObject *obj, int32_t old_row, int32_t old_col, int32_t new_row, int32_t new_col,
    VARIANT_BOOL *cancel);
static void vfg_fire_after_sel_change_event(
    VolvoxGridObject *obj, int32_t old_row, int32_t old_col, int32_t new_row, int32_t new_col);
static void vfg_fire_before_scroll_event(
    VolvoxGridObject *obj, int32_t old_top, int32_t old_left, int32_t new_top, int32_t new_left,
    VARIANT_BOOL *cancel);
static void vfg_fire_after_scroll_event(
    VolvoxGridObject *obj, int32_t old_top, int32_t old_left, int32_t new_top, int32_t new_left);
static void vfg_fire_after_sort_event(VolvoxGridObject *obj, int32_t col, int32_t order);
static void vfg_fire_simple_event(VolvoxGridObject *obj, DISPID dispid);
static void vfg_fire_cell_button_click_event(
    VolvoxGridObject *obj, int32_t row, int32_t col);
static HRESULT vfg_fire_before_mouse_down_event(
    VolvoxGridObject *obj, int32_t button, int32_t shift, float x, float y, VARIANT_BOOL *cancel);
static void vfg_fire_key_event(VolvoxGridObject *obj, DISPID dispid, int32_t key_code, int32_t shift);
static void vfg_fire_key_press_event(VolvoxGridObject *obj, int32_t key_ascii);
static void vfg_fire_key_edit_event(
    VolvoxGridObject *obj, DISPID dispid, int32_t row, int32_t col, int32_t key_code, int32_t shift);
static void vfg_fire_key_press_edit_event(
    VolvoxGridObject *obj, int32_t row, int32_t col, int32_t key_ascii);
static void vfg_fire_mouse_event(
    VolvoxGridObject *obj, DISPID dispid, int32_t button, int32_t shift, float x, float y);
static void vfg_fire_ole_start_drag_event(
    VolvoxGridObject *obj, IDataObject *data_object, LONG *allowed_effects);
static void vfg_fire_ole_complete_drag_event(VolvoxGridObject *obj, LONG effect);
static HRESULT vfg_paste_unicode_data_object(VolvoxGridObject *obj, IDataObject *data_object);
static HRESULT vfg_try_public_dispatch_fallback(
    VolvoxGridObject *obj,
    DISPID dispid,
    WORD wFlags,
    DISPPARAMS *pDispParams,
    VARIANT *pVarResult);
static HRESULT vfg_notify_view_change(VolvoxGridObject *obj);
static HRESULT vfg_invalidate_control(VolvoxGridObject *obj);
static HRESULT vfg_resize_control_window(VolvoxGridObject *obj);
static HRESULT vfg_activate_in_place(
    VolvoxGridObject *obj, HWND hwndParent, const RECT *lprcPosRect, BOOL ui_activate);
static HRESULT vfg_deactivate_in_place(VolvoxGridObject *obj);
static int vfg_current_modifier_flags(void);
static HRESULT vfg_handle_pointer_down(
    VolvoxGridObject *obj, float x, float y, int32_t button, int32_t modifier, int32_t dbl_click);
static HRESULT vfg_handle_pointer_move(
    VolvoxGridObject *obj, float x, float y, int32_t button, int32_t modifier);
static HRESULT vfg_handle_pointer_up(
    VolvoxGridObject *obj, float x, float y, int32_t button, int32_t modifier);
static HRESULT vfg_handle_key_down(
    VolvoxGridObject *obj, int32_t key_code, int32_t modifier);
static HRESULT vfg_handle_key_press(
    VolvoxGridObject *obj, uint32_t char_code);
static HRESULT vfg_pump_engine_events(VolvoxGridObject *obj);

#define VIEWOBJECT_OFFSET offsetof(VolvoxGridObject, lpVtblViewObject)
#define VIEWOBJECT2_OFFSET offsetof(VolvoxGridObject, lpVtblViewObject2)
#define OLEOBJECT_OFFSET offsetof(VolvoxGridObject, lpVtblOleObject)
#define INPLACEOBJECT_OFFSET offsetof(VolvoxGridObject, lpVtblInPlaceObject)
#define INPLACEACTIVEOBJECT_OFFSET offsetof(VolvoxGridObject, lpVtblInPlaceActiveObject)
#define OLECONTROL_OFFSET offsetof(VolvoxGridObject, lpVtblOleControl)
#define PERSISTSTREAMINIT_OFFSET offsetof(VolvoxGridObject, lpVtblPersistStreamInit)
#define CPCONTAINER_OFFSET offsetof(VolvoxGridObject, lpVtblConnectionPointContainer)
#define CONNECTIONPOINT_OFFSET offsetof(VolvoxGridObject, lpVtblConnectionPoint)
#define DATAOBJECT_OFFSET offsetof(VolvoxGridObject, lpVtblDataObject)
#define DROPSOURCE_OFFSET offsetof(VolvoxGridObject, lpVtblDropSource)
#define DROPTARGET_OFFSET offsetof(VolvoxGridObject, lpVtblDropTarget)
#define OBJECTSAFETY_OFFSET offsetof(VolvoxGridObject, lpVtblObjectSafety)

#define OBJ_FROM_VIEWOBJECT(pv) \
    ((VolvoxGridObject *)((char *)(pv) - VIEWOBJECT_OFFSET))
#define OBJ_FROM_VIEWOBJECT2(pv) \
    ((VolvoxGridObject *)((char *)(pv) - VIEWOBJECT2_OFFSET))
#define OBJ_FROM_OLEOBJECT(pv) \
    ((VolvoxGridObject *)((char *)(pv) - OLEOBJECT_OFFSET))
#define OBJ_FROM_INPLACEOBJECT(pv) \
    ((VolvoxGridObject *)((char *)(pv) - INPLACEOBJECT_OFFSET))
#define OBJ_FROM_INPLACEACTIVEOBJECT(pv) \
    ((VolvoxGridObject *)((char *)(pv) - INPLACEACTIVEOBJECT_OFFSET))
#define OBJ_FROM_OLECONTROL(pv) \
    ((VolvoxGridObject *)((char *)(pv) - OLECONTROL_OFFSET))
#define OBJ_FROM_PERSISTSTREAMINIT(pv) \
    ((VolvoxGridObject *)((char *)(pv) - PERSISTSTREAMINIT_OFFSET))
#define OBJ_FROM_CPCONTAINER(pv) \
    ((VolvoxGridObject *)((char *)(pv) - CPCONTAINER_OFFSET))
#define OBJ_FROM_CONNECTIONPOINT(pv) \
    ((VolvoxGridObject *)((char *)(pv) - CONNECTIONPOINT_OFFSET))
#define OBJ_FROM_DATAOBJECT(pv) \
    ((VolvoxGridObject *)((char *)(pv) - DATAOBJECT_OFFSET))
#define OBJ_FROM_DROPSOURCE(pv) \
    ((VolvoxGridObject *)((char *)(pv) - DROPSOURCE_OFFSET))
#define OBJ_FROM_DROPTARGET(pv) \
    ((VolvoxGridObject *)((char *)(pv) - DROPTARGET_OFFSET))
#define OBJ_FROM_OBJECTSAFETY(pv) \
    ((VolvoxGridObject *)((char *)(pv) - OBJECTSAFETY_OFFSET))

static VolvoxGridObject *g_vfg_objects = NULL;
static CRITICAL_SECTION g_vfg_objects_cs;

void vfg_init_object_registry(void) {
    InitializeCriticalSection(&g_vfg_objects_cs);
}

void vfg_shutdown_object_registry(void) {
    DeleteCriticalSection(&g_vfg_objects_cs);
}

int vfg_object_registry_count(void) {
    int count = 0;
    VolvoxGridObject *obj;
    EnterCriticalSection(&g_vfg_objects_cs);
    obj = g_vfg_objects;
    while (obj) {
        count++;
        obj = obj->registry_next;
    }
    LeaveCriticalSection(&g_vfg_objects_cs);
    return count;
}

static VolvoxGridObject *vfg_find_object_by_grid_id(int64_t grid_id) {
    VolvoxGridObject *obj;
    EnterCriticalSection(&g_vfg_objects_cs);
    obj = g_vfg_objects;
    while (obj) {
        if (obj->grid_id == grid_id) {
            LeaveCriticalSection(&g_vfg_objects_cs);
            return obj;
        }
        obj = obj->registry_next;
    }
    LeaveCriticalSection(&g_vfg_objects_cs);
    return NULL;
}

static void vfg_register_object(VolvoxGridObject *obj) {
    if (!obj) return;
    EnterCriticalSection(&g_vfg_objects_cs);
    obj->registry_next = g_vfg_objects;
    g_vfg_objects = obj;
    LeaveCriticalSection(&g_vfg_objects_cs);
}

static void vfg_unregister_object(VolvoxGridObject *obj) {
    EnterCriticalSection(&g_vfg_objects_cs);
    VolvoxGridObject **link = &g_vfg_objects;
    while (*link) {
        if (*link == obj) {
            *link = obj->registry_next;
            obj->registry_next = NULL;
            LeaveCriticalSection(&g_vfg_objects_cs);
            return;
        }
        link = &(*link)->registry_next;
    }
    LeaveCriticalSection(&g_vfg_objects_cs);
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

static int32_t vfg_row_engine_from_display_property(int64_t grid_id, int32_t row) {
    int32_t rows;
    int32_t logical;
    if (row < 0) return row;
    rows = volvox_grid_get_rows(grid_id);
    if (row < rows && volvox_grid_get_row_display_position(grid_id, row) == row) {
        return row;
    }
    for (logical = 0; logical < rows; ++logical) {
        if (volvox_grid_get_row_display_position(grid_id, logical) == row) {
            return logical;
        }
    }
    return row;
}

static int32_t vfg_col_engine_from_display_property(VolvoxGridObject *obj, int32_t col) {
    int64_t grid_id;
    int32_t display_col;
    int32_t cols;
    int32_t logical;
    if (!obj || col < 0) return col;
    grid_id = obj->grid_id;
    display_col = col;
    cols = volvox_grid_get_cols(grid_id);
    if (display_col >= 0 && display_col < cols &&
        volvox_grid_get_col_display_position(grid_id, display_col) == display_col) {
        return display_col;
    }
    for (logical = 0; logical < cols; ++logical) {
        if (volvox_grid_get_col_display_position(grid_id, logical) == display_col) {
            return logical;
        }
    }
    return display_col;
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

static int32_t volvox_grid_set_rows_compat(int64_t grid_id, int32_t rows) {
    int32_t out_len = 0;
    uint8_t *out = vfg_native_set_rows(grid_id, rows, &out_len);
    int32_t status = vfg_take_status_response(out);
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    if (obj) {
        int32_t count = volvox_grid_get_rows(grid_id);
        obj->frozen_rows_cached = vfg_clamp_cached_extent(obj->frozen_rows_cached, count);
        obj->row_sel_cached = vfg_clamp_cached_index(obj->row_sel_cached, count, volvox_grid_get_row(grid_id));
        vfg_clear_is_collapsed_cache(obj);
    }
    return status;
}

static int32_t volvox_grid_set_cols_compat(int64_t grid_id, int32_t cols) {
    int32_t old_count = volvox_grid_get_cols(grid_id);
    int32_t out_len = 0;
    uint8_t *out = vfg_native_set_cols(grid_id, cols, &out_len);
    int32_t status = vfg_take_status_response(out);
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    int32_t count = volvox_grid_get_cols(grid_id);
    if (status == 0 && cols > old_count && count > old_count) {
        int32_t default_width = vfg_compat_default_col_width_px(
            volvox_grid_get_font_size(grid_id));
        if (default_width > 0) {
            for (int32_t col = old_count; col < count; ++col) {
                int32_t ignore_len = 0;
                uint8_t *ignore = vfg_native_set_col_width(
                    grid_id,
                    col,
                    default_width,
                    &ignore_len);
                if (ignore) volvox_grid_free(ignore, ignore_len);
            }
        }
    }
    if (obj) {
        obj->frozen_cols_cached = vfg_clamp_cached_extent(obj->frozen_cols_cached, count);
        obj->col_sel_cached = vfg_clamp_cached_index(obj->col_sel_cached, count, volvox_grid_get_col(grid_id));
    }
    return status;
}

static int32_t volvox_grid_set_row_compat(int64_t grid_id, int32_t row) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    int32_t old_row = volvox_grid_get_row(grid_id);
    int32_t old_col = vfg_get_col_cached(grid_id);
    int32_t new_row = old_row;
    int32_t rows = volvox_grid_get_rows(grid_id);
    int32_t out_len = 0;
    uint8_t *out;
    int32_t status = 0;

    if (rows > 0) {
        new_row = vfg_clamp_cached_index(row, rows, old_row);
    }
    if (obj && new_row != old_row) {
        VARIANT_BOOL cancel = VARIANT_FALSE;
        VARIANT args[5];
        VariantInit(&args[4]); args[4].vt = VT_I4; args[4].lVal = old_row;
        VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = old_col;
        VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = new_row;
        VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = old_col;
        VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = &cancel;
        vfg_fire_event(obj, DISPID_VFG_EVT_BEFOREROWCOLCHANGE, args, 5);
        if (cancel != VARIANT_FALSE) return 0;
    }

    out = vfg_native_set_row(grid_id, row, &out_len);
    status = vfg_take_status_response(out);
    if (obj) {
        obj->row_sel_cached = vfg_clamp_cached_index(volvox_grid_get_row(grid_id), rows, row);
        if (status == 0 && obj->recordset && obj->data_mode != 0 &&
            new_row >= VFG_BOUND_HEADER_ROWS) {
            HRESULT hr_move = vfg_bound_move_recordset_to_row(obj, new_row);
            if (FAILED(hr_move)) {
                vfg_fire_ado_data_error_event(obj, hr_move);
                return -1;
            }
            if (obj->bound_virtual_active) {
                hr_move = vfg_bound_fetch_window(obj, new_row, 1);
                if (FAILED(hr_move)) {
                    vfg_fire_ado_data_error_event(obj, hr_move);
                    return -1;
                }
            }
        }
        if (status == 0 && new_row != old_row) {
            VARIANT args[4];
            VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = old_row;
            VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = old_col;
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = new_row;
            VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = old_col;
            vfg_fire_event(obj, DISPID_VFG_EVT_AFTERROWCOLCHANGE, args, 4);
            vfg_fire_event(obj, DISPID_VFG_EVT_ROWCOLCHANGE, NULL, 0);
        }
    }
    return status;
}

static int32_t volvox_grid_set_col_compat(int64_t grid_id, int32_t col) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    int32_t old_row = volvox_grid_get_row(grid_id);
    int32_t old_col = vfg_get_col_cached(grid_id);
    int32_t engine_col = vfg_col_engine_from_property(obj, col);
    int32_t cols = volvox_grid_get_cols(grid_id);
    int32_t new_col = old_col;
    int32_t out_len = 0;
    uint8_t *out;
    int32_t status = 0;

    if (cols > 0) {
        int32_t clamped_engine_col = vfg_clamp_cached_index(engine_col, cols, volvox_grid_get_col(grid_id));
        new_col = vfg_col_property_from_engine(obj, clamped_engine_col);
    }
    if (obj && new_col != old_col) {
        VARIANT_BOOL cancel = VARIANT_FALSE;
        VARIANT args[5];
        VariantInit(&args[4]); args[4].vt = VT_I4; args[4].lVal = old_row;
        VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = old_col;
        VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = old_row;
        VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = new_col;
        VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = &cancel;
        vfg_fire_event(obj, DISPID_VFG_EVT_BEFOREROWCOLCHANGE, args, 5);
        if (cancel != VARIANT_FALSE) return 0;
    }

    out = vfg_native_set_col(grid_id, engine_col, &out_len);
    status = vfg_take_status_response(out);
    if (obj) {
        if (col >= 0 && col < vfg_bound_physical_col_offset(obj)) {
            obj->col_sel_cached = col;
        } else {
            obj->col_sel_cached = vfg_clamp_cached_index(volvox_grid_get_col(grid_id), cols, engine_col);
        }
        if (status == 0 && new_col != old_col) {
            VARIANT args[4];
            VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = old_row;
            VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = old_col;
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = old_row;
            VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = new_col;
            vfg_fire_event(obj, DISPID_VFG_EVT_AFTERROWCOLCHANGE, args, 4);
            vfg_fire_event(obj, DISPID_VFG_EVT_ROWCOLCHANGE, NULL, 0);
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
    return vfg_take_status_response(out);
}

static int32_t volvox_grid_set_row_sel_compat(int64_t grid_id, int32_t row_sel) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    int32_t old_row_sel = vfg_get_row_sel_cached(grid_id);
    int32_t old_col_sel = vfg_get_col_sel_cached(grid_id);
    int32_t rows = volvox_grid_get_rows(grid_id);
    int32_t new_row_sel = rows > 0 ? vfg_clamp_cached_index(row_sel, rows, old_row_sel) : old_row_sel;
    int32_t out_len = 0;
    uint8_t *out;
    int32_t status = 0;

    if (obj && new_row_sel != old_row_sel) {
        VARIANT_BOOL cancel = VARIANT_FALSE;
        VARIANT args[5];
        VariantInit(&args[4]); args[4].vt = VT_I4; args[4].lVal = old_row_sel;
        VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = old_col_sel;
        VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = new_row_sel;
        VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = old_col_sel;
        VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = &cancel;
        vfg_fire_event(obj, DISPID_VFG_EVT_BEFORESELCHANGE, args, 5);
        if (cancel != VARIANT_FALSE) return 0;
    }

    out = vfg_native_set_row_sel(grid_id, row_sel, &out_len);
    status = vfg_take_status_response(out);
    if (obj) {
        obj->row_sel_cached = new_row_sel;
        if (status == 0 && new_row_sel != old_row_sel) {
            VARIANT args[4];
            VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = old_row_sel;
            VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = old_col_sel;
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = new_row_sel;
            VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = old_col_sel;
            vfg_fire_event(obj, DISPID_VFG_EVT_AFTERSELCHANGE, args, 4);
            vfg_fire_event(obj, DISPID_VFG_EVT_SELCHANGE, NULL, 0);
        }
    }
    return status;
}

static int32_t volvox_grid_set_col_sel_compat(int64_t grid_id, int32_t col_sel) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    int32_t old_row_sel = vfg_get_row_sel_cached(grid_id);
    int32_t old_col_sel = vfg_get_col_sel_cached(grid_id);
    int32_t engine_col_sel = vfg_col_engine_from_property(obj, col_sel);
    int32_t cols = volvox_grid_get_cols(grid_id);
    int32_t new_col_sel = old_col_sel;
    int32_t out_len = 0;
    uint8_t *out;
    int32_t status = 0;

    if (cols > 0) {
        int32_t clamped_engine_col = vfg_clamp_cached_index(
            engine_col_sel,
            cols,
            vfg_col_engine_from_property(obj, old_col_sel));
        new_col_sel = vfg_col_property_from_engine(obj, clamped_engine_col);
    }
    if (obj && new_col_sel != old_col_sel) {
        VARIANT_BOOL cancel = VARIANT_FALSE;
        VARIANT args[5];
        VariantInit(&args[4]); args[4].vt = VT_I4; args[4].lVal = old_row_sel;
        VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = old_col_sel;
        VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = old_row_sel;
        VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = new_col_sel;
        VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = &cancel;
        vfg_fire_event(obj, DISPID_VFG_EVT_BEFORESELCHANGE, args, 5);
        if (cancel != VARIANT_FALSE) return 0;
    }

    out = vfg_native_set_col_sel(grid_id, engine_col_sel, &out_len);
    status = vfg_take_status_response(out);
    if (obj) {
        obj->col_sel_cached = engine_col_sel;
        if (status == 0 && new_col_sel != old_col_sel) {
            VARIANT args[4];
            VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = old_row_sel;
            VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = old_col_sel;
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = old_row_sel;
            VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = new_col_sel;
            vfg_fire_event(obj, DISPID_VFG_EVT_AFTERSELCHANGE, args, 4);
            vfg_fire_event(obj, DISPID_VFG_EVT_SELCHANGE, NULL, 0);
        }
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

/* ── IUnknown ─────────────────────────────────────────────────── */

static HRESULT STDMETHODCALLTYPE VFG_QueryInterface(
    IDispatch *This, REFIID riid, void **ppv)
{
    VolvoxGridObject *obj = (VolvoxGridObject *)This;
    if (!ppv) return E_POINTER;
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
    if (IsEqualIID(riid, &IID_IViewObject2)) {
        *ppv = &obj->lpVtblViewObject2;
        InterlockedIncrement(&obj->cRef);
        return S_OK;
    }
    if (IsEqualIID(riid, &IID_IOleObject)) {
        *ppv = &obj->lpVtblOleObject;
        InterlockedIncrement(&obj->cRef);
        return S_OK;
    }
    if (IsEqualIID(riid, &IID_IOleInPlaceObject) ||
        IsEqualIID(riid, &IID_IOleWindow))
    {
        *ppv = &obj->lpVtblInPlaceObject;
        InterlockedIncrement(&obj->cRef);
        return S_OK;
    }
    if (IsEqualIID(riid, &IID_IOleInPlaceActiveObject)) {
        *ppv = &obj->lpVtblInPlaceActiveObject;
        InterlockedIncrement(&obj->cRef);
        return S_OK;
    }
    if (IsEqualIID(riid, &IID_IOleControl)) {
        *ppv = &obj->lpVtblOleControl;
        InterlockedIncrement(&obj->cRef);
        return S_OK;
    }
    if (IsEqualIID(riid, &IID_IPersistStreamInit) || IsEqualIID(riid, &IID_IPersist)) {
        *ppv = &obj->lpVtblPersistStreamInit;
        InterlockedIncrement(&obj->cRef);
        return S_OK;
    }
    if (IsEqualIID(riid, &IID_IConnectionPointContainer)) {
        *ppv = &obj->lpVtblConnectionPointContainer;
        InterlockedIncrement(&obj->cRef);
        return S_OK;
    }
    if (IsEqualIID(riid, &IID_IDataObject)) {
        *ppv = &obj->lpVtblDataObject;
        InterlockedIncrement(&obj->cRef);
        return S_OK;
    }
    if (IsEqualIID(riid, &IID_IDropSource)) {
        *ppv = &obj->lpVtblDropSource;
        InterlockedIncrement(&obj->cRef);
        return S_OK;
    }
    if (IsEqualIID(riid, &IID_IDropTarget)) {
        *ppv = &obj->lpVtblDropTarget;
        InterlockedIncrement(&obj->cRef);
        return S_OK;
    }
    if (IsEqualIID(riid, &IID_IObjectSafety)) {
        *ppv = &obj->lpVtblObjectSafety;
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
        vfg_deactivate_in_place(obj);
        vfg_free_sink_entries(obj);
        vfg_clear_flood_color_cache(obj);
        vfg_clear_ado_binding(obj);
        if (obj->client_site) IOleClientSite_Release(obj->client_site);
        if (obj->inplace_site) IOleInPlaceSite_Release(obj->inplace_site);
        if (obj->col_data_type_cache) {
            HeapFree(GetProcessHeap(), 0, obj->col_data_type_cache);
        }
        vfg_free_bstr_cache(obj->col_data_cache, obj->col_data_cache_len);
        vfg_free_bstr_cache(obj->col_key_cache, obj->col_key_cache_len);
        vfg_free_bstr_cache(obj->col_format_cache, obj->col_format_cache_len);
        vfg_free_bstr_cache(obj->col_edit_mask_cache, obj->col_edit_mask_cache_len);
        vfg_free_bstr_cache(obj->col_combo_list_cache, obj->col_combo_list_cache_len);
        if (obj->col_indent_cache) HeapFree(GetProcessHeap(), 0, obj->col_indent_cache);
        if (obj->is_collapsed_cache) HeapFree(GetProcessHeap(), 0, obj->is_collapsed_cache);
        VariantClear(&obj->height_cached);
        VariantClear(&obj->width_cached);
        vfg_free_variant_slots(obj->compat_values);
        vfg_clear_stored_data_formats(obj);
        if (obj->host_app_name) SysFreeString(obj->host_app_name);
        if (obj->host_obj_name) SysFreeString(obj->host_obj_name);
        if (obj->grid_id >= 0) {
            volvox_grid_set_custom_compare_native(obj->grid_id, NULL, NULL);
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
    if (!pctinfo) return E_POINTER;
    *pctinfo = 0;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_GetTypeInfo(
    IDispatch *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo)
{
    (void)This; (void)lcid;
    if (!ppTInfo) return E_POINTER;
    *ppTInfo = NULL;
    (void)iTInfo;
    return DISP_E_BADINDEX;
}

static int vfg_lookup_dispid_by_name(
    const VG_NameEntry *entries, const WCHAR *name, DISPID *out)
{
    const VG_NameEntry *entry;
    if (!entries || !name || !out) return 0;
    for (entry = entries; entry->name; ++entry) {
        if (_wcsicmp(name, entry->name) == 0) {
            *out = entry->id;
            return 1;
        }
    }
    return 0;
}

static HRESULT STDMETHODCALLTYPE VFG_GetIDsOfNames(
    IDispatch *This, REFIID riid, LPOLESTR *rgszNames,
    UINT cNames, LCID lcid, DISPID *rgDispId)
{
    (void)This; (void)riid; (void)lcid;

    HRESULT hrFinal = S_OK;
    for (UINT i = 0; i < cNames; i++) {
        BOOL found = FALSE;
        found = vfg_lookup_dispid_by_name(vfg_legacy_names, rgszNames[i], &rgDispId[i]);
        if (!found) found = vfg_lookup_dispid_by_name(vfg_internal_names, rgszNames[i], &rgDispId[i]);
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

static int vfg_decode_bool_field(
    const uint8_t *data, int32_t len, uint32_t target_field, int fallback)
{
    int32_t pos = 0;

    if (!data || len <= 0) return fallback;
    while (pos < len) {
        uint64_t key = 0;
        uint64_t value = 0;
        uint32_t field_no;
        uint32_t wire_type;

        if (!vfg_read_varint(data, len, &pos, &key)) return fallback;
        field_no = (uint32_t)(key >> 3);
        wire_type = (uint32_t)(key & 0x7);
        if (field_no == target_field && wire_type == 0) {
            if (!vfg_read_varint(data, len, &pos, &value)) return fallback;
            return value != 0 ? 1 : 0;
        }
        if (!vfg_skip_wire(data, len, &pos, wire_type)) return fallback;
    }
    return fallback;
}

static int vfg_decode_bytes_field(
    const uint8_t *data,
    int32_t len,
    uint32_t target_field,
    const uint8_t **out_ptr,
    int32_t *out_len)
{
    int32_t pos = 0;

    if (out_ptr) *out_ptr = NULL;
    if (out_len) *out_len = 0;
    if (!data || len <= 0) return 0;

    while (pos < len) {
        uint64_t key = 0;
        uint64_t field_len = 0;
        uint32_t field_no;
        uint32_t wire_type;

        if (!vfg_read_varint(data, len, &pos, &key)) return 0;
        field_no = (uint32_t)(key >> 3);
        wire_type = (uint32_t)(key & 0x7);
        if (field_no == target_field && wire_type == 2) {
            if (!vfg_read_varint(data, len, &pos, &field_len)) return 0;
            if (field_len > (uint64_t)(len - pos)) return 0;
            if (out_ptr) *out_ptr = data + pos;
            if (out_len) *out_len = (int32_t)field_len;
            return 1;
        }
        if (!vfg_skip_wire(data, len, &pos, wire_type)) return 0;
    }
    return 0;
}

static char *vfg_take_string_field_response(uint8_t *data, int32_t len, uint32_t field_no, int *out_len) {
    char *copy;
    const uint8_t *field_ptr = NULL;
    int32_t field_len = 0;

    if (out_len) *out_len = 0;
    if (!data) return NULL;

    if (!vfg_decode_bytes_field(data, len, field_no, &field_ptr, &field_len)) {
        field_ptr = (const uint8_t *)"";
        field_len = 0;
    }

    copy = (char *)HeapAlloc(GetProcessHeap(), 0, (SIZE_T)field_len + 1);
    if (!copy) {
        volvox_grid_free(data, 0);
        return NULL;
    }

    if (field_len > 0) {
        memcpy(copy, field_ptr, (size_t)field_len);
    }
    copy[field_len] = '\0';
    if (out_len) *out_len = field_len;
    volvox_grid_free(data, 0);
    return copy;
}

static int vfg_take_bool_field_response(uint8_t *data, int32_t len, uint32_t field_no, int fallback) {
    int value = fallback;
    if (data) {
        value = vfg_decode_bool_field(data, len, field_no, fallback);
        volvox_grid_free(data, 0);
    }
    return value;
}

static int vfg_utf8_char_size(unsigned char lead) {
    if ((lead & 0x80) == 0x00) return 1;
    if ((lead & 0xE0) == 0xC0) return 2;
    if ((lead & 0xF0) == 0xE0) return 3;
    if ((lead & 0xF8) == 0xF0) return 4;
    return 1;
}

static int32_t vfg_utf8_char_count(const char *utf8, int32_t len) {
    int32_t pos = 0;
    int32_t count = 0;

    if (!utf8 || len <= 0) return 0;
    while (pos < len) {
        int step = vfg_utf8_char_size((unsigned char)utf8[pos]);
        if (step <= 0 || pos + step > len) step = 1;
        pos += step;
        count++;
    }
    return count;
}

static int32_t vfg_utf8_byte_offset_for_char_index(const char *utf8, int32_t len, int32_t char_index) {
    int32_t pos = 0;
    int32_t count = 0;

    if (!utf8 || len <= 0 || char_index <= 0) return 0;
    while (pos < len && count < char_index) {
        int step = vfg_utf8_char_size((unsigned char)utf8[pos]);
        if (step <= 0 || pos + step > len) step = 1;
        pos += step;
        count++;
    }
    return pos;
}

static char *vfg_utf8_replace_range(
    const char *base,
    int32_t base_len,
    int32_t start_chars,
    int32_t remove_chars,
    const char *insert,
    int32_t insert_len,
    int32_t *out_len)
{
    int32_t total_chars;
    int32_t start_char;
    int32_t end_char;
    int32_t start_byte;
    int32_t end_byte;
    int32_t next_len;
    char *next;

    if (out_len) *out_len = 0;
    if (!base) {
        base = "";
        base_len = 0;
    }
    if (!insert) {
        insert = "";
        insert_len = 0;
    }

    total_chars = vfg_utf8_char_count(base, base_len);
    start_char = start_chars < 0 ? 0 : start_chars;
    if (start_char > total_chars) start_char = total_chars;
    end_char = start_char + (remove_chars < 0 ? 0 : remove_chars);
    if (end_char > total_chars) end_char = total_chars;

    start_byte = vfg_utf8_byte_offset_for_char_index(base, base_len, start_char);
    end_byte = vfg_utf8_byte_offset_for_char_index(base, base_len, end_char);
    next_len = start_byte + insert_len + (base_len - end_byte);
    next = (char *)HeapAlloc(GetProcessHeap(), 0, (SIZE_T)next_len + 1);
    if (!next) return NULL;

    if (start_byte > 0) {
        memcpy(next, base, (size_t)start_byte);
    }
    if (insert_len > 0) {
        memcpy(next + start_byte, insert, (size_t)insert_len);
    }
    if (base_len - end_byte > 0) {
        memcpy(next + start_byte + insert_len, base + end_byte, (size_t)(base_len - end_byte));
    }
    next[next_len] = '\0';
    if (out_len) *out_len = next_len;
    return next;
}

static BOOL vfg_set_system_clipboard_utf8(const char *utf8, int utf8len) {
    BOOL ok = FALSE;
    BSTR wide = utf8_to_bstr(utf8, utf8len);
    HGLOBAL mem = NULL;
    WCHAR *dst = NULL;
    SIZE_T bytes;

    if (!wide) return FALSE;
    bytes = ((SIZE_T)SysStringLen(wide) + 1) * sizeof(WCHAR);
    mem = GlobalAlloc(GMEM_MOVEABLE, bytes);
    if (!mem) goto done;

    dst = (WCHAR *)GlobalLock(mem);
    if (!dst) goto done;
    memcpy(dst, wide, bytes);
    GlobalUnlock(mem);
    dst = NULL;

    if (!OpenClipboard(NULL)) goto done;
    if (!EmptyClipboard()) {
        CloseClipboard();
        goto done;
    }
    if (!SetClipboardData(CF_UNICODETEXT, mem)) {
        CloseClipboard();
        goto done;
    }
    CloseClipboard();
    mem = NULL;
    ok = TRUE;

done:
    if (dst) GlobalUnlock(mem);
    if (mem) GlobalFree(mem);
    SysFreeString(wide);
    return ok;
}

static char *vfg_get_system_clipboard_utf8(int *out_len) {
    char *utf8 = NULL;
    HANDLE handle = NULL;
    const WCHAR *src = NULL;
    int wide_len;
    int needed;

    if (out_len) *out_len = 0;
    if (!IsClipboardFormatAvailable(CF_UNICODETEXT)) return NULL;
    if (!OpenClipboard(NULL)) return NULL;

    handle = GetClipboardData(CF_UNICODETEXT);
    if (!handle) {
        CloseClipboard();
        return NULL;
    }

    src = (const WCHAR *)GlobalLock(handle);
    if (!src) {
        CloseClipboard();
        return NULL;
    }

    wide_len = lstrlenW(src);
    needed = WideCharToMultiByte(CP_UTF8, 0, src, wide_len, NULL, 0, NULL, NULL);
    utf8 = (char *)HeapAlloc(GetProcessHeap(), 0, (SIZE_T)needed + 1);
    if (utf8 && needed > 0) {
        WideCharToMultiByte(CP_UTF8, 0, src, wide_len, utf8, needed, NULL, NULL);
    }
    if (utf8) utf8[needed] = '\0';
    GlobalUnlock(handle);
    CloseClipboard();

    if (out_len) *out_len = needed;
    return utf8;
}

static uint8_t *vfg_query_edit_state_payload(int64_t grid_id, int32_t *out_len) {
    uint8_t buf[16];
    int pos = 0;

    buf[pos++] = 0x08;
    pos += vfg_write_varint(buf + pos, (uint64_t)grid_id);
    return volvox_grid_edit_pb(buf, pos, out_len);
}

static int32_t vfg_query_edit_state_i32_field(int64_t grid_id, uint32_t field_no, int32_t fallback) {
    int32_t out_len = 0;
    int32_t value = fallback;
    uint8_t *out = vfg_query_edit_state_payload(grid_id, &out_len);
    if (out) {
        value = vfg_decode_i32_field(out, out_len, field_no, fallback);
        volvox_grid_free(out, 0);
    }
    return value;
}

static char *vfg_query_edit_state_string_field(int64_t grid_id, uint32_t field_no, int *out_len) {
    int32_t resp_len = 0;
    uint8_t *out = vfg_query_edit_state_payload(grid_id, &resp_len);
    return vfg_take_string_field_response(out, resp_len, field_no, out_len);
}

static int32_t vfg_get_edit_sel_start_compat(int64_t grid_id) {
    return vfg_query_edit_state_i32_field(grid_id, 5, 0);
}

static int32_t vfg_get_edit_sel_length_compat(int64_t grid_id) {
    return vfg_query_edit_state_i32_field(grid_id, 6, 0);
}

static int32_t vfg_set_edit_selection_compat(int64_t grid_id, int32_t start, int32_t length) {
    uint8_t buf[32];
    uint8_t inner[16];
    int pos = 0;
    int ilen = 0;
    int32_t out_len = 0;
    uint8_t *out;

    buf[pos++] = 0x08;
    pos += vfg_write_varint(buf + pos, (uint64_t)grid_id);
    inner[ilen++] = 0x08;
    ilen += vfg_write_varint(inner + ilen, (uint64_t)(uint32_t)start);
    inner[ilen++] = 0x10;
    ilen += vfg_write_varint(inner + ilen, (uint64_t)(uint32_t)length);
    buf[pos++] = 0x32;
    pos += vfg_write_varint(buf + pos, (uint64_t)ilen);
    memcpy(buf + pos, inner, (size_t)ilen);
    pos += ilen;

    out = volvox_grid_edit_pb(buf, pos, &out_len);
    return vfg_take_status_response(out);
}

static int32_t vfg_set_edit_text_compat(int64_t grid_id, const char *utf8, int32_t utf8len) {
    uint8_t *buf;
    int pos = 0;
    int32_t out_len = 0;
    uint8_t *out;
    int capacity;
    int inner_len;

    if (!utf8) {
        utf8 = "";
        utf8len = 0;
    }

    inner_len = 1 + vfg_varint_len((uint64_t)utf8len) + utf8len;
    capacity = utf8len + 32;
    buf = (uint8_t *)HeapAlloc(GetProcessHeap(), 0, (SIZE_T)capacity);
    if (!buf) return -1;

    buf[pos++] = 0x08;
    pos += vfg_write_varint(buf + pos, (uint64_t)grid_id);
    buf[pos++] = 0x2A;
    pos += vfg_write_varint(buf + pos, (uint64_t)inner_len);
    buf[pos++] = 0x0A;
    pos += vfg_write_varint(buf + pos, (uint64_t)utf8len);
    if (utf8len > 0) {
        memcpy(buf + pos, utf8, (size_t)utf8len);
        pos += utf8len;
    }

    out = volvox_grid_edit_pb(buf, pos, &out_len);
    HeapFree(GetProcessHeap(), 0, buf);
    return vfg_take_status_response(out);
}

static int32_t vfg_set_preedit_compat(
    int64_t grid_id,
    const char *utf8,
    int32_t utf8len,
    int32_t cursor,
    int32_t commit)
{
    uint8_t *buf;
    int pos = 0;
    int32_t out_len = 0;
    uint8_t *out;
    int capacity;
    int inner_len;

    if (!utf8) {
        utf8 = "";
        utf8len = 0;
    }
    if (utf8len < 0) return -1;
    if (cursor < 0) cursor = 0;
    commit = commit ? 1 : 0;

    inner_len =
        1 + vfg_varint_len((uint64_t)utf8len) + utf8len +
        1 + vfg_varint_len((uint64_t)(uint32_t)cursor) +
        1 + vfg_varint_len((uint64_t)(uint32_t)commit);
    capacity = inner_len + 32;
    buf = (uint8_t *)HeapAlloc(GetProcessHeap(), 0, (SIZE_T)capacity);
    if (!buf) return -1;

    buf[pos++] = 0x08;
    pos += vfg_write_varint(buf + pos, (uint64_t)grid_id);
    buf[pos++] = 0x4A;
    pos += vfg_write_varint(buf + pos, (uint64_t)inner_len);
    buf[pos++] = 0x0A;
    pos += vfg_write_varint(buf + pos, (uint64_t)utf8len);
    if (utf8len > 0) {
        memcpy(buf + pos, utf8, (size_t)utf8len);
        pos += utf8len;
    }
    buf[pos++] = 0x10;
    pos += vfg_write_varint(buf + pos, (uint64_t)(uint32_t)cursor);
    buf[pos++] = 0x18;
    pos += vfg_write_varint(buf + pos, (uint64_t)(uint32_t)commit);

    out = volvox_grid_edit_pb(buf, pos, &out_len);
    HeapFree(GetProcessHeap(), 0, buf);
    return vfg_take_status_response(out);
}

static char *vfg_get_edit_text_utf8(int64_t grid_id, int *out_len) {
    return vfg_query_edit_state_string_field(grid_id, 4, out_len);
}

static char *vfg_get_edit_sel_text_utf8(int64_t grid_id, int *out_len) {
    int edit_len = 0;
    int sel_start;
    int sel_length;
    int start_byte;
    int end_byte;
    int selected_len;
    char *edit_text = vfg_get_edit_text_utf8(grid_id, &edit_len);
    char *selected;

    if (out_len) *out_len = 0;
    if (!edit_text) return NULL;

    sel_start = vfg_get_edit_sel_start_compat(grid_id);
    sel_length = vfg_get_edit_sel_length_compat(grid_id);
    start_byte = vfg_utf8_byte_offset_for_char_index(edit_text, edit_len, sel_start);
    end_byte = vfg_utf8_byte_offset_for_char_index(edit_text, edit_len, sel_start + sel_length);
    if (end_byte < start_byte) end_byte = start_byte;
    selected_len = end_byte - start_byte;
    selected = (char *)HeapAlloc(GetProcessHeap(), 0, (SIZE_T)selected_len + 1);
    if (!selected) {
        HeapFree(GetProcessHeap(), 0, edit_text);
        return NULL;
    }
    if (selected_len > 0) {
        memcpy(selected, edit_text + start_byte, (size_t)selected_len);
    }
    selected[selected_len] = '\0';
    if (out_len) *out_len = selected_len;
    HeapFree(GetProcessHeap(), 0, edit_text);
    return selected;
}

static int vfg_query_edit_active(int64_t grid_id) {
    int32_t out_len = 0;
    uint8_t *out = vfg_query_edit_state_payload(grid_id, &out_len);
    return vfg_take_bool_field_response(out, out_len, 1, 0);
}

static int32_t vfg_copy_or_cut_grid_selection(int64_t grid_id, BOOL cut) {
    uint8_t buf[16];
    int pos = 0;
    int32_t out_len = 0;
    int text_len = 0;
    uint8_t *out;
    char *text;
    int32_t status = 0;

    buf[pos++] = 0x08;
    pos += vfg_write_varint(buf + pos, (uint64_t)grid_id);
    buf[pos++] = cut ? 0x1A : 0x12;
    buf[pos++] = 0x00;
    out = volvox_grid_clipboard_pb(buf, pos, &out_len);
    text = vfg_take_string_field_response(out, out_len, 1, &text_len);

    if (!text) return -1;
    if (!vfg_set_system_clipboard_utf8(text, text_len)) {
        status = -1;
    }
    HeapFree(GetProcessHeap(), 0, text);
    return status;
}

static int32_t vfg_paste_grid_selection_from_clipboard(int64_t grid_id) {
    uint8_t *buf;
    int clip_len = 0;
    int pos = 0;
    int32_t out_len = 0;
    uint8_t *out;
    char *clip = vfg_get_system_clipboard_utf8(&clip_len);
    int32_t status;
    int capacity;
    int inner_len;

    if (!clip) return -1;
    inner_len = 1 + vfg_varint_len((uint64_t)clip_len) + clip_len;
    capacity = clip_len + 32;
    buf = (uint8_t *)HeapAlloc(GetProcessHeap(), 0, (SIZE_T)capacity);
    if (!buf) {
        HeapFree(GetProcessHeap(), 0, clip);
        return -1;
    }

    buf[pos++] = 0x08;
    pos += vfg_write_varint(buf + pos, (uint64_t)grid_id);
    buf[pos++] = 0x22;
    pos += vfg_write_varint(buf + pos, (uint64_t)inner_len);
    buf[pos++] = 0x0A;
    pos += vfg_write_varint(buf + pos, (uint64_t)clip_len);
    if (clip_len > 0) {
        memcpy(buf + pos, clip, (size_t)clip_len);
        pos += clip_len;
    }

    out = volvox_grid_clipboard_pb(buf, pos, &out_len);
    status = vfg_take_status_response(out);
    HeapFree(GetProcessHeap(), 0, buf);
    HeapFree(GetProcessHeap(), 0, clip);
    return status;
}

static int32_t vfg_copy_or_cut_active_edit(int64_t grid_id, BOOL cut) {
    int sel_start;
    int sel_length;
    int selected_len = 0;
    int edit_len = 0;
    int next_len = 0;
    char *selected = NULL;
    char *edit_text = NULL;
    char *next_text = NULL;
    int32_t status = 0;

    sel_start = vfg_get_edit_sel_start_compat(grid_id);
    sel_length = vfg_get_edit_sel_length_compat(grid_id);
    selected = vfg_get_edit_sel_text_utf8(grid_id, &selected_len);
    if (!selected) return -1;

    if (sel_length <= 0 || selected_len <= 0) {
        HeapFree(GetProcessHeap(), 0, selected);
        return 0;
    }

    if (!vfg_set_system_clipboard_utf8(selected, selected_len)) {
        HeapFree(GetProcessHeap(), 0, selected);
        return -1;
    }

    if (!cut) {
        HeapFree(GetProcessHeap(), 0, selected);
        return 0;
    }

    edit_text = vfg_get_edit_text_utf8(grid_id, &edit_len);
    if (!edit_text) {
        HeapFree(GetProcessHeap(), 0, selected);
        return -1;
    }

    next_text = vfg_utf8_replace_range(edit_text, edit_len, sel_start, sel_length, "", 0, &next_len);
    if (!next_text) {
        HeapFree(GetProcessHeap(), 0, edit_text);
        HeapFree(GetProcessHeap(), 0, selected);
        return -1;
    }

    status = vfg_set_edit_text_compat(grid_id, next_text, next_len);
    if (status == 0) status = vfg_set_edit_selection_compat(grid_id, sel_start, 0);

    HeapFree(GetProcessHeap(), 0, next_text);
    HeapFree(GetProcessHeap(), 0, edit_text);
    HeapFree(GetProcessHeap(), 0, selected);
    return status;
}

static int32_t vfg_paste_active_edit_from_clipboard(int64_t grid_id) {
    int clip_len = 0;
    int edit_len = 0;
    int next_len = 0;
    int sel_start;
    int sel_length;
    int caret_chars;
    int32_t status = 0;
    char *clip = vfg_get_system_clipboard_utf8(&clip_len);
    char *edit_text = NULL;
    char *next_text = NULL;

    if (!clip) return -1;

    sel_start = vfg_get_edit_sel_start_compat(grid_id);
    sel_length = vfg_get_edit_sel_length_compat(grid_id);
    edit_text = vfg_get_edit_text_utf8(grid_id, &edit_len);
    if (!edit_text) {
        edit_text = (char *)HeapAlloc(GetProcessHeap(), 0, 1);
        if (!edit_text) {
            HeapFree(GetProcessHeap(), 0, clip);
            return -1;
        }
        edit_text[0] = '\0';
        edit_len = 0;
    }

    next_text =
        vfg_utf8_replace_range(edit_text, edit_len, sel_start, sel_length, clip, clip_len, &next_len);
    if (!next_text) {
        HeapFree(GetProcessHeap(), 0, edit_text);
        HeapFree(GetProcessHeap(), 0, clip);
        return -1;
    }

    caret_chars = sel_start + vfg_utf8_char_count(clip, clip_len);
    status = vfg_set_edit_text_compat(grid_id, next_text, next_len);
    if (status == 0) status = vfg_set_edit_selection_compat(grid_id, caret_chars, 0);

    HeapFree(GetProcessHeap(), 0, next_text);
    HeapFree(GetProcessHeap(), 0, edit_text);
    HeapFree(GetProcessHeap(), 0, clip);
    return status;
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

static int32_t vfg_compat_default_row_height_px(float font_px) {
    if (font_px <= 0.0f) return 0;
    return (int32_t)(font_px + (font_px <= 12.0f ? 5.5f : 6.5f));
}

static int32_t vfg_compat_default_col_width_px(float font_px) {
    int32_t font_pt;
    if (font_px <= 0.0f) return 0;
    font_pt = (int32_t)(font_px * 72.0f / (float)vfg_get_screen_dpi_y() + 0.5f);
    if (font_pt < 1) font_pt = 1;
    return font_pt * 8 - 4;
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

static int32_t *vfg_capture_row_heights(int64_t gid, int32_t rows) {
    int32_t *heights;
    if (rows <= 0) return NULL;
    heights = (int32_t *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(int32_t) * rows);
    if (!heights) return NULL;
    for (int32_t row = 0; row < rows; ++row) {
        heights[row] = volvox_grid_get_row_height(gid, row);
    }
    return heights;
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
        {
            int32_t ignore_len = 0;
            uint8_t *ignore = vfg_native_set_col_width(gid, col, width, &ignore_len);
            if (ignore) volvox_grid_free(ignore, ignore_len);
        }
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
            {
                int32_t ignore_len = 0;
                uint8_t *ignore = vfg_native_set_col_width(gid, newCol, width, &ignore_len);
                if (ignore) volvox_grid_free(ignore, ignore_len);
            }
        }
    }
}

static int32_t vfg_measure_grid_cell_text_width_px(
    int64_t gid,
    int32_t row,
    int32_t col,
    const uint8_t *font_name_ptr,
    int32_t font_name_len,
    float font_size,
    int32_t font_bold,
    int32_t font_italic)
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
                    font_bold,
                    font_italic,
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

static int32_t vfg_grid_cell_text_max_line_chars(int64_t gid, int32_t row, int32_t col) {
    int32_t best_chars = 0;
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
                int32_t chars = vfg_utf8_char_count((const char *)text + start, i - start);
                if (chars > best_chars) best_chars = chars;
            }
            if (!at_end && text[i] == 13 && i + 1 < text_len && text[i + 1] == 10) {
                ++i;
            }
            start = i + 1;
        }
    }
    volvox_grid_free(text, text_len);
    return best_chars;
}

static int32_t vfg_unbound_autosize_text_pad_px(float font_size, int32_t font_bold) {
    int32_t pad;
    if (font_size >= 12.75f) return 15;
    if (font_size >= 12.0f) pad = font_bold ? 16 : 15;
    else if (font_size >= 9.75f) pad = 14;
    else pad = 13;
    if (font_bold && pad > 0) --pad;
    return pad;
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
    int32_t font_bold = volvox_grid_get_font_bold_native(gid);
    int32_t font_italic = volvox_grid_get_font_italic_native(gid);
    if (rows <= 0 || totalCols <= 0 || colTo < colFrom) return;
    if (colFrom < 0) colFrom = 0;
    if (colTo >= totalCols) colTo = totalCols - 1;
    if (colFrom > colTo) return;
    if (dataColOffset > 0 && colFrom < dataColOffset) {
        int32_t selectorTo = colTo < dataColOffset ? colTo : (dataColOffset - 1);
        for (int32_t col = colFrom; col <= selectorTo; ++col) {
            {
                int32_t ignore_len = 0;
                uint8_t *ignore = vfg_native_set_col_width(
                    gid, col, VFG_BOUND_SELECTOR_COL_WIDTH_PX, &ignore_len);
                if (ignore) volvox_grid_free(ignore, ignore_len);
            }
        }
    }
    if (colTo < dataColOffset) return;
    if (font_size <= 0.0f) font_size = 13.0f;
    font_name = volvox_grid_get_font_name(gid, &font_name_len);
    for (int32_t col = colFrom < dataColOffset ? dataColOffset : colFrom; col <= colTo; ++col) {
        int32_t basis_px = 0;
        for (int32_t row = 0; row < rows; ++row) {
            int32_t text_px = vfg_measure_grid_cell_text_width_px(
                gid, row, col, font_name, font_name_len, font_size, font_bold, font_italic);
            if (text_px > basis_px) basis_px = text_px;
        }
        {
            int32_t width_px = basis_px + VFG_BOUND_AUTOSIZE_TEXT_PAD_PX;
            VolvoxGridObject *width_obj = vfg_find_object_by_grid_id(gid);
            int active_connection = width_obj && width_obj->recordset &&
                vfg_recordset_has_active_connection(width_obj->recordset);
            if (col == dataColOffset && font_size >= 15.0f) {
                width_px += 1;
            } else if (col > dataColOffset) {
                if (width_obj && width_obj->data_mode != 0 && active_connection) {
                    if (font_size >= 14.0f) width_px += 1;
                } else if (font_size >= 15.0f) {
                    width_px += 1;
                }
            }
            if (width_px < VFG_BOUND_AUTOSIZE_MIN_COL_WIDTH_PX) {
                width_px = VFG_BOUND_AUTOSIZE_MIN_COL_WIDTH_PX;
            }
            {
                int32_t ignore_len = 0;
                uint8_t *ignore = vfg_native_set_col_width(gid, col, width_px, &ignore_len);
                if (ignore) volvox_grid_free(ignore, ignore_len);
            }
        }
    }
    if (font_name) volvox_grid_free(font_name, font_name_len);
}

static void vfg_apply_unbound_autosize_compat_widths(
    int64_t gid,
    int32_t colFrom,
    int32_t colTo,
    int32_t equal,
    int32_t maxWidthPx)
{
    int32_t rows = volvox_grid_get_rows(gid);
    int32_t totalCols = volvox_grid_get_cols(gid);
    int32_t font_name_len = 0;
    uint8_t *font_name = NULL;
    float font_size = volvox_grid_get_font_size(gid);
    int32_t font_bold = volvox_grid_get_font_bold_native(gid);
    int32_t font_italic = volvox_grid_get_font_italic_native(gid);
    int32_t font_underline = volvox_grid_get_font_underline_native(gid);
    int32_t pad;
    int32_t *widths = NULL;
    if (rows <= 0 || totalCols <= 0 || colTo < colFrom) return;
    if (colFrom < 0) colFrom = 0;
    if (colTo >= totalCols) colTo = totalCols - 1;
    if (colFrom > colTo) return;

    if (font_size <= 0.0f) font_size = 9.0f;
    pad = vfg_unbound_autosize_text_pad_px(
        font_size * 72.0f / (float)vfg_get_screen_dpi_y(),
        font_bold);
    font_name = volvox_grid_get_font_name(gid, &font_name_len);
    widths = (int32_t *)HeapAlloc(
        GetProcessHeap(),
        HEAP_ZERO_MEMORY,
        sizeof(int32_t) * (colTo - colFrom + 1));
    if (!widths) {
        if (font_name) volvox_grid_free(font_name, font_name_len);
        return;
    }

    for (int32_t col = colFrom; col <= colTo; ++col) {
        int32_t width_px = pad;
        for (int32_t row = 0; row < rows; ++row) {
            int32_t cell_font_bold = volvox_grid_get_cell_font_bold(gid, row, col);
            int32_t text_px = vfg_measure_grid_cell_text_width_px(
                gid,
                row,
                col,
                font_name,
                font_name_len,
                font_size,
                font_bold || cell_font_bold,
                font_italic);
            if (text_px > 0) {
                int32_t needed = text_px + pad;
                int32_t line_chars = cell_font_bold
                    ? vfg_grid_cell_text_max_line_chars(gid, row, col)
                    : 0;
                if (cell_font_bold && !font_underline && font_size <= 13.0f &&
                    text_px <= 50 && line_chars <= 6) {
                    if (!font_bold) needed -= 1;
                } else if (cell_font_bold) {
                    needed += font_bold
                        ? VFG_UNBOUND_CELLFONT_AUTOSIZE_EXTRA_BOLD_BASE_PX
                        : VFG_UNBOUND_CELLFONT_AUTOSIZE_EXTRA_NORMAL_BASE_PX;
                }
                if (needed > width_px) width_px = needed;
            }
        }
        widths[col - colFrom] = width_px;
    }

    if (equal) {
        int32_t width = 0;
        for (int32_t col = colFrom; col <= colTo; ++col) {
            int32_t w = widths[col - colFrom];
            if (w > width) width = w;
        }
        if (maxWidthPx > 0 && width > maxWidthPx) width = maxWidthPx;
        for (int32_t col = colFrom; col <= colTo; ++col) {
            int32_t ignore_len = 0;
            uint8_t *ignore = vfg_native_set_col_width(gid, col, width, &ignore_len);
            if (ignore) volvox_grid_free(ignore, ignore_len);
        }
        goto done;
    }

    for (int32_t col = colFrom; col <= colTo; ++col) {
        int32_t width = widths[col - colFrom];
        int32_t ignore_len = 0;
        uint8_t *ignore;
        if (maxWidthPx > 0 && width > maxWidthPx) width = maxWidthPx;
        ignore = vfg_native_set_col_width(gid, col, width, &ignore_len);
        if (ignore) volvox_grid_free(ignore, ignore_len);
    }

done:
    HeapFree(GetProcessHeap(), 0, widths);
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

static void vfg_clear_is_collapsed_cache(VolvoxGridObject *obj) {
    if (!obj) return;
    if (obj->is_collapsed_cache) {
        HeapFree(GetProcessHeap(), 0, obj->is_collapsed_cache);
        obj->is_collapsed_cache = NULL;
    }
    obj->is_collapsed_cache_len = 0;
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

static int vfg_read_fixed32(const uint8_t *buf, int32_t len, int32_t *pos, uint32_t *out) {
    if (!buf || !pos || !out || *pos < 0 || len - *pos < 4) return 0;
    *out = (uint32_t)buf[*pos]
        | ((uint32_t)buf[*pos + 1] << 8)
        | ((uint32_t)buf[*pos + 2] << 16)
        | ((uint32_t)buf[*pos + 3] << 24);
    *pos += 4;
    return 1;
}

static int vfg_read_fixed64(const uint8_t *buf, int32_t len, int32_t *pos, uint64_t *out) {
    if (!buf || !pos || !out || *pos < 0 || len - *pos < 8) return 0;
    *out = (uint64_t)buf[*pos]
        | ((uint64_t)buf[*pos + 1] << 8)
        | ((uint64_t)buf[*pos + 2] << 16)
        | ((uint64_t)buf[*pos + 3] << 24)
        | ((uint64_t)buf[*pos + 4] << 32)
        | ((uint64_t)buf[*pos + 5] << 40)
        | ((uint64_t)buf[*pos + 6] << 48)
        | ((uint64_t)buf[*pos + 7] << 56);
    *pos += 8;
    return 1;
}

static float vfg_u32_to_float(uint32_t u) {
    union {
        uint32_t u32;
        float f32;
    } v;
    v.u32 = u;
    return v.f32;
}

static double vfg_u64_to_double(uint64_t u) {
    union {
        uint64_t u64;
        double f64;
    } v;
    v.u64 = u;
    return v.f64;
}

static void vfg_decode_cell_range_anchor(
    const uint8_t *buf,
    int32_t len,
    int32_t *row,
    int32_t *col)
{
    int32_t pos = 0;
    while (pos < len) {
        uint64_t key = 0;
        uint64_t value = 0;
        uint32_t field_no;
        uint32_t wire_type;
        if (!vfg_read_varint(buf, len, &pos, &key)) return;
        field_no = (uint32_t)(key >> 3);
        wire_type = (uint32_t)(key & 0x7);
        if (wire_type == 0 && vfg_read_varint(buf, len, &pos, &value)) {
            if (field_no == 1 && row) *row = (int32_t)value;
            else if (field_no == 2 && col) *col = (int32_t)value;
            continue;
        }
        if (!vfg_skip_wire(buf, len, &pos, wire_type)) return;
    }
}

typedef struct VFGProtoEvent {
    int32_t kind;
    int64_t event_id;
    int32_t row;
    int32_t col;
    int32_t old_row;
    int32_t old_col;
    int32_t new_row;
    int32_t new_col;
    int32_t button;
    int32_t modifier;
    int32_t key_code;
    int32_t key_ascii;
    int32_t hit_area;
    int32_t interaction;
    int32_t extra1;
    int32_t extra2;
    float width;
    float height;
    float x;
    float y;
} VFGProtoEvent;

static void vfg_proto_event_init(VFGProtoEvent *evt) {
    if (!evt) return;
    memset(evt, 0, sizeof(*evt));
    evt->row = evt->col = -1;
    evt->old_row = evt->old_col = -1;
    evt->new_row = evt->new_col = -1;
}

static void vfg_decode_nested_event(
    uint32_t kind,
    const uint8_t *buf,
    int32_t len,
    VFGProtoEvent *evt)
{
    int32_t pos = 0;
    if (!evt) return;
    evt->kind = (int32_t)kind;
    while (pos < len) {
        uint64_t key = 0;
        uint64_t value = 0;
        uint32_t field_no;
        uint32_t wire_type;
        uint32_t u32 = 0;
        if (!vfg_read_varint(buf, len, &pos, &key)) return;
        field_no = (uint32_t)(key >> 3);
        wire_type = (uint32_t)(key & 0x7);
        switch (kind) {
        case 2:
        case 3:
        case 4:
        case 5:
        case 28:
        case 29:
            if ((kind == 4 || kind == 5)
                && (field_no == 1 || field_no == 2)
                && wire_type == 2) {
                uint64_t msg_len = 0;
                if (!vfg_read_varint(buf, len, &pos, &msg_len)) return;
                if (msg_len > (uint64_t)(len - pos)) return;
                if (field_no == 1) {
                    vfg_decode_cell_range_anchor(
                        buf + pos, (int32_t)msg_len, &evt->old_row, &evt->old_col);
                } else {
                    vfg_decode_cell_range_anchor(
                        buf + pos, (int32_t)msg_len, &evt->new_row, &evt->new_col);
                }
                pos += (int32_t)msg_len;
                continue;
            }
            if (wire_type == 0 && vfg_read_varint(buf, len, &pos, &value)) {
                if (field_no == 1) evt->old_row = (int32_t)value;
                else if (field_no == 2) evt->old_col = (int32_t)value;
                else if (field_no == 3) evt->new_row = (int32_t)value;
                else if (field_no == 4) evt->new_col = (int32_t)value;
                continue;
            }
            break;
        case 6:
        case 7:
        case 17:
        case 18:
        case 19:
        case 20:
        case 22:
        case 26:
        case 27:
        case 31:
        case 32:
        case 33:
        case 38:
        case 48:
        case 50:
        case 52:
        case 53:
        case 57:
        case 58:
        case 59:
        case 60:
            if (wire_type == 0 && vfg_read_varint(buf, len, &pos, &value)) {
                if (field_no == 1) evt->row = (int32_t)value;
                else if (field_no == 2) evt->col = (int32_t)value;
                continue;
            }
            break;
        case 8:
        case 9:
        case 10:
        case 11:
        case 12:
        case 21:
        case 23:
        case 24:
        case 56:
        case 42:
        case 43:
            if (wire_type == 0 && vfg_read_varint(buf, len, &pos, &value)) {
                if (field_no == 1) evt->row = (int32_t)value;
                else if (field_no == 2) evt->col = (int32_t)value;
                else if (kind == 42 && field_no == 3) evt->hit_area = (int32_t)value;
                else if (kind == 42 && field_no == 4) evt->interaction = (int32_t)value;
                continue;
            }
            break;
        case 25:
            if (wire_type == 0 && vfg_read_varint(buf, len, &pos, &value)) {
                if (field_no == 2) evt->row = (int32_t)value;
                else if (field_no == 3) evt->col = (int32_t)value;
                else if (field_no == 4) evt->extra1 = (int32_t)value;
                continue;
            }
            break;
        case 34:
        case 35:
        case 36:
        case 37:
            if (wire_type == 0 && vfg_read_varint(buf, len, &pos, &value)) {
                if (field_no == 1) evt->row = (int32_t)value;
                else if (field_no == 2) evt->col = (int32_t)value;
                else if (field_no == 3) evt->extra1 = (int32_t)value;
                else if (field_no == 4) evt->extra2 = (int32_t)value;
                continue;
            }
            break;
        case 49:
            if (field_no == 1 && wire_type == 0 && vfg_read_varint(buf, len, &pos, &value)) {
                evt->row = (int32_t)value;
                continue;
            }
            if (field_no == 2 && wire_type == 0 && vfg_read_varint(buf, len, &pos, &value)) {
                evt->col = (int32_t)value;
                continue;
            }
            if (field_no == 3 && wire_type == 5 && vfg_read_fixed32(buf, len, &pos, &u32)) {
                evt->x = vfg_u32_to_float(u32);
                continue;
            }
            if (field_no == 4 && wire_type == 5 && vfg_read_fixed32(buf, len, &pos, &u32)) {
                evt->y = vfg_u32_to_float(u32);
                continue;
            }
            break;
        case 39:
        case 40:
        case 41:
            if (field_no == 1 && wire_type == 0 && vfg_read_varint(buf, len, &pos, &value)) {
                evt->button = (int32_t)value;
                continue;
            }
            if (field_no == 2 && wire_type == 0 && vfg_read_varint(buf, len, &pos, &value)) {
                evt->modifier = (int32_t)value;
                continue;
            }
            if (field_no == 3 && wire_type == 5 && vfg_read_fixed32(buf, len, &pos, &u32)) {
                evt->x = vfg_u32_to_float(u32);
                continue;
            }
            if (field_no == 4 && wire_type == 5 && vfg_read_fixed32(buf, len, &pos, &u32)) {
                evt->y = vfg_u32_to_float(u32);
                continue;
            }
            break;
        case 65:
        case 66:
            if (wire_type == 0 && vfg_read_varint(buf, len, &pos, &value)) {
                if (field_no == 2) evt->row = (int32_t)value;
                else if (field_no == 3) evt->col = (int32_t)value;
                continue;
            }
            break;
        case 14:
        case 16:
        case 44:
        case 46:
            if (wire_type == 0 && vfg_read_varint(buf, len, &pos, &value)) {
                if (field_no == 1) evt->key_code = (int32_t)value;
                else if (field_no == 2) evt->modifier = (int32_t)value;
                continue;
            }
            break;
        case 47:
        case 63:
            if (field_no == 1 && wire_type == 0 && vfg_read_varint(buf, len, &pos, &value)) {
                evt->row = (int32_t)value;
                continue;
            }
            if (field_no == 2 && wire_type == 0 && vfg_read_varint(buf, len, &pos, &value)) {
                evt->col = (int32_t)value;
                continue;
            }
            if (field_no == 3 && wire_type == 5 && vfg_read_fixed32(buf, len, &pos, &u32)) {
                evt->x = vfg_u32_to_float(u32);
                continue;
            }
            if (field_no == 4 && wire_type == 5 && vfg_read_fixed32(buf, len, &pos, &u32)) {
                evt->y = vfg_u32_to_float(u32);
                continue;
            }
            if (field_no == 5 && wire_type == 5 && vfg_read_fixed32(buf, len, &pos, &u32)) {
                evt->width = vfg_u32_to_float(u32);
                continue;
            }
            if (field_no == 6 && wire_type == 5 && vfg_read_fixed32(buf, len, &pos, &u32)) {
                evt->height = vfg_u32_to_float(u32);
                continue;
            }
            break;
        case 15:
        case 45:
            if (field_no == 1 && wire_type == 0 && vfg_read_varint(buf, len, &pos, &value)) {
                evt->key_ascii = (int32_t)value;
                continue;
            }
            break;
        default:
            break;
        }
        if (!vfg_skip_wire(buf, len, &pos, wire_type)) return;
    }
}

static int vfg_decode_grid_event(const uint8_t *buf, int32_t len, VFGProtoEvent *evt) {
    int32_t pos = 0;
    if (!buf || len <= 0 || !evt) return 0;
    vfg_proto_event_init(evt);
    while (pos < len) {
        uint64_t key = 0;
        uint64_t value = 0;
        uint32_t field_no;
        uint32_t wire_type;
        if (!vfg_read_varint(buf, len, &pos, &key)) return 0;
        field_no = (uint32_t)(key >> 3);
        wire_type = (uint32_t)(key & 0x7);
        if (field_no == 100 && wire_type == 0) {
            if (!vfg_read_varint(buf, len, &pos, &value)) return 0;
            evt->event_id = (int64_t)value;
            continue;
        }
        if (wire_type == 2 && field_no >= 2 && field_no <= 68) {
            uint64_t msg_len = 0;
            int32_t msg_pos;
            if (!vfg_read_varint(buf, len, &pos, &msg_len)) return 0;
            if (msg_len > (uint64_t)(len - pos)) return 0;
            msg_pos = pos;
            vfg_decode_nested_event(field_no, buf + msg_pos, (int32_t)msg_len, evt);
            pos += (int32_t)msg_len;
            continue;
        }
        if (!vfg_skip_wire(buf, len, &pos, wire_type)) return 0;
    }
    return evt->kind != 0;
}

static void vfg_free_sink_entries(VolvoxGridObject *obj) {
    UINT i;
    if (!obj || !obj->sinks) return;
    for (i = 0; i < obj->sink_count; ++i) {
        if (obj->sinks[i].dispatch) {
            IDispatch_Release(obj->sinks[i].dispatch);
        }
    }
    HeapFree(GetProcessHeap(), 0, obj->sinks);
    obj->sinks = NULL;
    obj->sink_count = 0;
    obj->sink_capacity = 0;
}

static HRESULT vfg_fire_event(VolvoxGridObject *obj, DISPID dispid, VARIANT *args, UINT cArgs) {
    UINT i;
    UINT sink_count;
    IDispatch **snapshot;
    if (!obj || obj->frozen_events) return S_OK;
    sink_count = obj->sink_count;
    if (sink_count == 0) return S_OK;

    snapshot = (IDispatch **)HeapAlloc(
        GetProcessHeap(), HEAP_ZERO_MEMORY, (SIZE_T)sink_count * sizeof(IDispatch *));
    if (!snapshot) return E_OUTOFMEMORY;

    for (i = 0; i < sink_count; ++i) {
        if (i < obj->sink_count && obj->sinks[i].dispatch) {
            snapshot[i] = obj->sinks[i].dispatch;
            IDispatch_AddRef(snapshot[i]);
        }
    }

    for (i = 0; i < sink_count; ++i) {
        DISPPARAMS dp;
        if (!snapshot[i]) continue;
        memset(&dp, 0, sizeof(dp));
        dp.rgvarg = args;
        dp.cArgs = cArgs;
        IDispatch_Invoke(
            snapshot[i],
            dispid,
            &IID_NULL,
            LOCALE_USER_DEFAULT,
            DISPATCH_METHOD,
            &dp,
            NULL,
            NULL,
            NULL);
        IDispatch_Release(snapshot[i]);
    }
    HeapFree(GetProcessHeap(), 0, snapshot);
    return S_OK;
}

static HRESULT vfg_fire_before_edit_event(
    VolvoxGridObject *obj, int32_t row, int32_t col, VARIANT_BOOL *cancel)
{
    VARIANT args[3];
    VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = row;
    VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = col;
    VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = cancel;
    return vfg_fire_event(obj, DISPID_VFG_EVT_BEFOREEDIT, args, 3);
}

static HRESULT vfg_fire_before_sort_event(
    VolvoxGridObject *obj, int32_t col, short *order_io)
{
    VARIANT args[2];
    VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = col;
    VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_I2; args[0].piVal = order_io;
    return vfg_fire_event(obj, DISPID_VFG_EVT_BEFORESORT, args, 2);
}

static int32_t vfg_custom_compare_callback(
    void *user_data, int32_t row1, int32_t row2, int32_t col)
{
    VolvoxGridObject *obj = (VolvoxGridObject *)user_data;
    short cmp = 0;
    VARIANT args[3];
    (void)col;

    if (!obj) return 0;

    VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = row1;
    VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = row2;
    VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_I2; args[0].piVal = &cmp;
    vfg_fire_event(obj, DISPID_VFG_EVT_COMPARE, args, 3);

    if (cmp < 0) return -1;
    if (cmp > 0) return 1;
    return 0;
}

static HRESULT vfg_fire_before_data_refresh_event(
    VolvoxGridObject *obj, VARIANT_BOOL *cancel)
{
    VARIANT args[1];
    VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = cancel;
    return vfg_fire_event(obj, DISPID_VFG_EVT_BEFOREDATAREFRESH, args, 1);
}

static void vfg_fire_ado_data_error_event(VolvoxGridObject *obj, HRESULT hr) {
    VARIANT_BOOL show_msg = VARIANT_TRUE;
    VARIANT args[2];
    VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = (LONG)hr;
    VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = &show_msg;
    vfg_fire_event(obj, DISPID_VFG_EVT_ERROR, args, 2);
}

static void vfg_fire_simple_event(VolvoxGridObject *obj, DISPID dispid) {
    vfg_fire_event(obj, dispid, NULL, 0);
}

static void vfg_fire_after_row_col_change_event(
    VolvoxGridObject *obj, int32_t old_row, int32_t old_col, int32_t new_row, int32_t new_col)
{
    VARIANT args[4];
    VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = old_row;
    VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = old_col;
    VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = new_row;
    VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = new_col;
    vfg_fire_event(obj, DISPID_VFG_EVT_AFTERROWCOLCHANGE, args, 4);
}

static void vfg_fire_start_edit_event(
    VolvoxGridObject *obj, int32_t row, int32_t col, VARIANT_BOOL *cancel)
{
    VARIANT args[3];
    VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = row;
    VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = col;
    VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = cancel;
    vfg_fire_event(obj, DISPID_VFG_EVT_STARTEDIT, args, 3);
}

static void vfg_fire_after_edit_event(VolvoxGridObject *obj, int32_t row, int32_t col) {
    VARIANT args[2];
    VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = row;
    VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = col;
    vfg_fire_event(obj, DISPID_VFG_EVT_AFTEREDIT, args, 2);
}

static void vfg_fire_validate_edit_event(
    VolvoxGridObject *obj, int32_t row, int32_t col, VARIANT_BOOL *cancel)
{
    VARIANT args[3];
    VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = row;
    VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = col;
    VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = cancel;
    vfg_fire_event(obj, DISPID_VFG_EVT_VALIDATEEDIT, args, 3);
}

static void vfg_fire_before_sel_change_event(
    VolvoxGridObject *obj, int32_t old_row, int32_t old_col, int32_t new_row, int32_t new_col,
    VARIANT_BOOL *cancel)
{
    VARIANT args[5];
    VariantInit(&args[4]); args[4].vt = VT_I4; args[4].lVal = old_row;
    VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = old_col;
    VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = new_row;
    VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = new_col;
    VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = cancel;
    vfg_fire_event(obj, DISPID_VFG_EVT_BEFORESELCHANGE, args, 5);
}

static void vfg_fire_after_sel_change_event(
    VolvoxGridObject *obj, int32_t old_row, int32_t old_col, int32_t new_row, int32_t new_col)
{
    VARIANT args[4];
    VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = old_row;
    VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = old_col;
    VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = new_row;
    VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = new_col;
    vfg_fire_event(obj, DISPID_VFG_EVT_AFTERSELCHANGE, args, 4);
}

static void vfg_fire_before_scroll_event(
    VolvoxGridObject *obj, int32_t old_top, int32_t old_left, int32_t new_top, int32_t new_left,
    VARIANT_BOOL *cancel)
{
    VARIANT args[5];
    VariantInit(&args[4]); args[4].vt = VT_I4; args[4].lVal = old_top;
    VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = old_left;
    VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = new_top;
    VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = new_left;
    VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = cancel;
    vfg_fire_event(obj, DISPID_VFG_EVT_BEFORESCROLL, args, 5);
}

static void vfg_fire_after_scroll_event(
    VolvoxGridObject *obj, int32_t old_top, int32_t old_left, int32_t new_top, int32_t new_left)
{
    VARIANT args[4];
    VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = old_top;
    VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = old_left;
    VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = new_top;
    VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = new_left;
    vfg_fire_event(obj, DISPID_VFG_EVT_AFTERSCROLL, args, 4);
}

static void vfg_fire_after_sort_event(VolvoxGridObject *obj, int32_t col, int32_t order) {
    VARIANT args[2];
    short order_short = (short)order;
    VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = col;
    VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_I2; args[0].piVal = &order_short;
    vfg_fire_event(obj, DISPID_VFG_EVT_AFTERSORT, args, 2);
}

static void vfg_fire_cell_button_click_event(
    VolvoxGridObject *obj, int32_t row, int32_t col)
{
    VARIANT args[2];
    VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = row;
    VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = col;
    vfg_fire_event(obj, DISPID_VFG_EVT_CELLBUTTONCLICK, args, 2);
}

static HRESULT vfg_fire_before_mouse_down_event(
    VolvoxGridObject *obj, int32_t button, int32_t shift, float x, float y, VARIANT_BOOL *cancel)
{
    short button_short = (short)button;
    short shift_short = (short)shift;
    VARIANT args[5];
    VariantInit(&args[4]); args[4].vt = VT_I2; args[4].iVal = button_short;
    VariantInit(&args[3]); args[3].vt = VT_I2; args[3].iVal = shift_short;
    VariantInit(&args[2]); args[2].vt = VT_R4; args[2].fltVal = x;
    VariantInit(&args[1]); args[1].vt = VT_R4; args[1].fltVal = y;
    VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = cancel;
    return vfg_fire_event(obj, DISPID_VFG_EVT_BEFOREMOUSEDOWN, args, 5);
}

static int32_t volvox_grid_set_top_row_compat(int64_t grid_id, int32_t row) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    int32_t old_top = volvox_grid_get_top_row(grid_id);
    int32_t old_left = vfg_get_left_col_cached(grid_id);
    int32_t rows = volvox_grid_get_rows(grid_id);
    int32_t new_top = rows > 0 ? vfg_clamp_cached_index(row, rows, old_top) : old_top;
    int32_t out_len = 0;
    uint8_t *out;
    int32_t status;

    if (obj && new_top != old_top) {
        VARIANT_BOOL cancel = VARIANT_FALSE;
        vfg_fire_before_scroll_event(obj, old_top, old_left, new_top, old_left, &cancel);
        if (cancel != VARIANT_FALSE) return 0;
    }

    out = vfg_native_set_top_row(grid_id, row, &out_len);
    status = vfg_take_status_response(out);
    if (status == 0 && obj && new_top != old_top) {
        HRESULT hr_fetch = vfg_bound_fetch_visible_window(obj);
        if (FAILED(hr_fetch)) {
            vfg_fire_ado_data_error_event(obj, hr_fetch);
            return -1;
        }
        vfg_fire_after_scroll_event(obj, old_top, old_left, new_top, old_left);
    }
    return status;
}

static int32_t volvox_grid_set_left_col_compat(int64_t grid_id, int32_t col) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    int32_t old_top = volvox_grid_get_top_row(grid_id);
    int32_t old_left = vfg_get_left_col_cached(grid_id);
    int32_t cols = volvox_grid_get_cols(grid_id);
    int32_t engine_col = vfg_col_engine_from_property(obj, col);
    int32_t new_left = old_left;
    int32_t out_len = 0;
    uint8_t *out;
    int32_t status;

    if (cols > 0) {
        int32_t clamped_engine_col =
            vfg_clamp_cached_index(engine_col, cols, volvox_grid_get_left_col(grid_id));
        new_left = vfg_col_property_from_engine(obj, clamped_engine_col);
    }
    if (obj && new_left != old_left) {
        VARIANT_BOOL cancel = VARIANT_FALSE;
        vfg_fire_before_scroll_event(obj, old_top, old_left, old_top, new_left, &cancel);
        if (cancel != VARIANT_FALSE) return 0;
    }

    out = vfg_native_set_left_col(grid_id, engine_col, &out_len);
    status = vfg_take_status_response(out);
    if (status == 0 && obj && new_left != old_left) {
        vfg_fire_after_scroll_event(obj, old_top, old_left, old_top, new_left);
    }
    return status;
}

static int32_t volvox_grid_set_col_position_compat(int64_t grid_id, int32_t col, int32_t position) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    LONG final_position = position;
    int32_t cols = volvox_grid_get_cols(grid_id);
    int32_t old_position = col;
    int32_t out_len = 0;
    uint8_t *out;
    int32_t status;

    if (old_position < 0 || old_position >= cols || final_position < 0 || final_position >= cols) return 0;

    if (obj && position != old_position) {
        VARIANT args[2];
        VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = col;
        VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_I4; args[0].plVal = &final_position;
        vfg_fire_event(obj, DISPID_VFG_EVT_BEFOREMOVECOLUMN, args, 2);
    }
    if (final_position == old_position || final_position < 0 || final_position >= cols) return 0;

    out = vfg_native_set_col_position(grid_id, col, final_position, &out_len);
    status = vfg_take_status_response(out);
    if (status == 0 && obj) {
        VARIANT args[2];
        VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = col;
        VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = old_position;
        vfg_fire_event(obj, DISPID_VFG_EVT_AFTERMOVECOLUMN, args, 2);
    }
    return status;
}

static int32_t volvox_grid_set_row_position_compat(int64_t grid_id, int32_t row, int32_t position) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    LONG final_position = position;
    int32_t rows = volvox_grid_get_rows(grid_id);
    int32_t old_position = row;
    int32_t out_len = 0;
    uint8_t *out;
    int32_t status;

    if (old_position < 0 || old_position >= rows || final_position < 0 || final_position >= rows) return 0;

    if (obj && position != old_position) {
        VARIANT args[2];
        VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = row;
        VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_I4; args[0].plVal = &final_position;
        vfg_fire_event(obj, DISPID_VFG_EVT_BEFOREMOVEROW, args, 2);
    }
    if (final_position == old_position || final_position < 0 || final_position >= rows) return 0;

    out = vfg_native_set_row_position(grid_id, row, final_position, &out_len);
    status = vfg_take_status_response(out);
    if (status == 0 && obj) {
        VARIANT args[2];
        VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = row;
        VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = old_position;
        vfg_fire_event(obj, DISPID_VFG_EVT_AFTERMOVEROW, args, 2);
    }
    return status;
}

static int32_t volvox_grid_set_row_height_compat(int64_t grid_id, int32_t row, int32_t height) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    if (height >= 0 && obj && obj->row_height_min_twips > 0) {
        int32_t min_height = vfg_twips_to_px_y(obj->row_height_min_twips);
        if (min_height > 0 && height < min_height) height = min_height;
    }
    int32_t old_height = volvox_grid_get_row_height(grid_id, row);
    int32_t out_len = 0;
    uint8_t *out;
    int32_t status;

    if (obj && old_height != height) {
        VARIANT_BOOL cancel = VARIANT_FALSE;
        VARIANT args[3];
        VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = row;
        VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = -1;
        VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = &cancel;
        vfg_fire_event(obj, DISPID_VFG_EVT_BEFOREUSERRESIZE, args, 3);
        if (cancel != VARIANT_FALSE) return 0;
    }

    out = vfg_native_set_row_height(grid_id, row, height, &out_len);
    status = vfg_take_status_response(out);
    if (status == 0 && obj && old_height != height) {
        VARIANT args[2];
        VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = row;
        VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = -1;
        vfg_fire_event(obj, DISPID_VFG_EVT_AFTERUSERRESIZE, args, 2);
    }
    return status;
}

static int32_t volvox_grid_set_col_width_compat(int64_t grid_id, int32_t col, int32_t width) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    if (width >= 0 && obj && obj->col_width_min_twips > 0) {
        int32_t min_width = vfg_twips_to_px_x(obj->col_width_min_twips);
        if (min_width > 0 && width < min_width) width = min_width;
    }
    int32_t old_width = volvox_grid_get_col_width(grid_id, col);
    int32_t out_len = 0;
    uint8_t *out;
    int32_t status;

    if (obj && old_width != width) {
        VARIANT_BOOL cancel = VARIANT_FALSE;
        VARIANT args[3];
        VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = -1;
        VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = col;
        VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = &cancel;
        vfg_fire_event(obj, DISPID_VFG_EVT_BEFOREUSERRESIZE, args, 3);
        if (cancel != VARIANT_FALSE) return 0;
    }

    out = vfg_native_set_col_width(grid_id, col, width, &out_len);
    status = vfg_take_status_response(out);
    if (status == 0 && obj && old_width != width) {
        VARIANT args[2];
        VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = -1;
        VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = col;
        vfg_fire_event(obj, DISPID_VFG_EVT_AFTERUSERRESIZE, args, 2);
    }
    return status;
}

static int32_t volvox_grid_set_is_collapsed_compat(int64_t grid_id, int32_t row, int32_t collapsed) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(grid_id);
    int32_t old_state = volvox_grid_get_is_collapsed(grid_id, row) ? 1 : 0;
    int32_t new_state = collapsed != 0 ? 1 : 0;
    short state = (short)new_state;
    int32_t out_len = 0;
    uint8_t *out;
    int32_t status;

    if (obj && old_state != new_state) {
        VARIANT_BOOL cancel = VARIANT_FALSE;
        VARIANT args[3];
        VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = row;
        VariantInit(&args[1]); args[1].vt = VT_I2; args[1].iVal = state;
        VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = &cancel;
        vfg_fire_event(obj, DISPID_VFG_EVT_BEFORECOLLAPSE, args, 3);
        if (cancel != VARIANT_FALSE) return 0;
    }

    out = vfg_native_set_is_collapsed(grid_id, row, collapsed, &out_len);
    status = vfg_take_status_response(out);
    if (status == 0 && obj && old_state != new_state) {
        VARIANT args[2];
        VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = row;
        VariantInit(&args[0]); args[0].vt = VT_I2; args[0].iVal = state;
        vfg_fire_event(obj, DISPID_VFG_EVT_AFTERCOLLAPSE, args, 2);
    }
    return status;
}

static void vfg_fire_key_event(VolvoxGridObject *obj, DISPID dispid, int32_t key_code, int32_t shift) {
    short key_code_short = (short)key_code;
    short shift_short = (short)shift;
    VARIANT args[2];
    VariantInit(&args[1]); args[1].vt = VT_BYREF | VT_I2; args[1].piVal = &key_code_short;
    VariantInit(&args[0]); args[0].vt = VT_I2; args[0].iVal = shift_short;
    vfg_fire_event(obj, dispid, args, 2);
}

static void vfg_fire_key_press_event(VolvoxGridObject *obj, int32_t key_ascii) {
    short key_ascii_short = (short)key_ascii;
    VARIANT arg;
    VariantInit(&arg);
    arg.vt = VT_BYREF | VT_I2;
    arg.piVal = &key_ascii_short;
    vfg_fire_event(obj, DISPID_VFG_EVT_KEYPRESS, &arg, 1);
}

static void vfg_fire_key_edit_event(
    VolvoxGridObject *obj, DISPID dispid, int32_t row, int32_t col, int32_t key_code, int32_t shift)
{
    short key_code_short = (short)key_code;
    short shift_short = (short)shift;
    VARIANT args[4];
    VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = row;
    VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = col;
    VariantInit(&args[1]); args[1].vt = VT_BYREF | VT_I2; args[1].piVal = &key_code_short;
    VariantInit(&args[0]); args[0].vt = VT_I2; args[0].iVal = shift_short;
    vfg_fire_event(obj, dispid, args, 4);
}

static void vfg_fire_key_press_edit_event(
    VolvoxGridObject *obj, int32_t row, int32_t col, int32_t key_ascii)
{
    short key_ascii_short = (short)key_ascii;
    VARIANT args[3];
    VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = row;
    VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = col;
    VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_I2; args[0].piVal = &key_ascii_short;
    vfg_fire_event(obj, DISPID_VFG_EVT_KEYPRESSEDIT, args, 3);
}

static void vfg_fire_mouse_event(
    VolvoxGridObject *obj, DISPID dispid, int32_t button, int32_t shift, float x, float y)
{
    VARIANT args[4];
    VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = button;
    VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = shift;
    VariantInit(&args[1]); args[1].vt = VT_R4; args[1].fltVal = x;
    VariantInit(&args[0]); args[0].vt = VT_R4; args[0].fltVal = y;
    vfg_fire_event(obj, dispid, args, 4);
}

static HRESULT vfg_notify_view_change(VolvoxGridObject *obj) {
    if (obj && obj->hwnd_ctrl) {
        InvalidateRect(obj->hwnd_ctrl, NULL, FALSE);
        UpdateWindow(obj->hwnd_ctrl);
    }
    return S_OK;
}

static HRESULT vfg_invalidate_control(VolvoxGridObject *obj) {
    if (obj && obj->hwnd_ctrl) {
        InvalidateRect(obj->hwnd_ctrl, NULL, FALSE);
    }
    return S_OK;
}

static int vfg_current_modifier_flags(void) {
    int flags = 0;
    if (GetKeyState(VK_SHIFT) & 0x8000) flags |= 0x01;
    if (GetKeyState(VK_CONTROL) & 0x8000) flags |= 0x02;
    if (GetKeyState(VK_MENU) & 0x8000) flags |= 0x04;
    return flags;
}

static const VG_NameEntry *vfg_lookup_legacy_name_by_dispid(DISPID dispid) {
    const VG_NameEntry *entry = vfg_legacy_names;
    while (entry && entry->name) {
        if (entry->id == dispid) return entry;
        ++entry;
    }
    return NULL;
}

static void vfg_init_byref_default(VARIANT *arg) {
    VARTYPE vt;
    if (!arg || !(V_VT(arg) & VT_BYREF)) return;
    vt = V_VT(arg) & ~VT_BYREF;
    switch (vt) {
    case VT_I2:
        if (V_I2REF(arg)) *V_I2REF(arg) = 0;
        break;
    case VT_I4:
    case VT_INT:
        if (V_I4REF(arg)) *V_I4REF(arg) = 0;
        break;
    case VT_UI4:
    case VT_UINT:
        if (V_UI4REF(arg)) *V_UI4REF(arg) = 0;
        break;
    case VT_R4:
        if (V_R4REF(arg)) *V_R4REF(arg) = 0.0f;
        break;
    case VT_R8:
        if (V_R8REF(arg)) *V_R8REF(arg) = 0.0;
        break;
    case VT_BOOL:
        if (V_BOOLREF(arg)) *V_BOOLREF(arg) = VARIANT_FALSE;
        break;
    case VT_BSTR:
        if (V_BSTRREF(arg)) {
            if (*V_BSTRREF(arg)) SysFreeString(*V_BSTRREF(arg));
            *V_BSTRREF(arg) = SysAllocString(L"");
        }
        break;
    case VT_DISPATCH:
        if (V_DISPATCHREF(arg)) *V_DISPATCHREF(arg) = NULL;
        break;
    case VT_UNKNOWN:
        if (V_UNKNOWNREF(arg)) *V_UNKNOWNREF(arg) = NULL;
        break;
    case VT_VARIANT:
        if (V_VARIANTREF(arg)) VariantInit(V_VARIANTREF(arg));
        break;
    default:
        break;
    }
}

static HRESULT vfg_try_public_dispatch_fallback(
    VolvoxGridObject *obj,
    DISPID dispid,
    WORD wFlags,
    DISPPARAMS *pDispParams,
    VARIANT *pVarResult)
{
    HRESULT hr;
    int has_index = 0;
    int32_t index = 0;

    if (!obj || !vfg_lookup_legacy_name_by_dispid(dispid)) return DISP_E_MEMBERNOTFOUND;

    if ((wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) && pDispParams) {
        if (pDispParams->cArgs >= 2) {
            has_index = 1;
            variant_to_i4(&pDispParams->rgvarg[1], &index);
        }
        return vfg_set_variant_slot(&obj->compat_values, dispid, has_index, index, &pDispParams->rgvarg[0]);
    }

    if ((wFlags & DISPATCH_PROPERTYGET) && pDispParams && pDispParams->cArgs >= 1) {
        has_index = 1;
        variant_to_i4(&pDispParams->rgvarg[0], &index);
    }

    if (wFlags & DISPATCH_PROPERTYGET) {
        if (!pVarResult) return E_POINTER;
        hr = vfg_copy_variant_slot(obj->compat_values, dispid, has_index, index, pVarResult);
        if (FAILED(hr)) {
            VariantInit(pVarResult);
            hr = S_OK;
        }
        return hr;
    }

    if (wFlags & DISPATCH_METHOD) {
        if (pDispParams) {
            for (UINT i = 0; i < pDispParams->cArgs; ++i) {
                vfg_init_byref_default(&pDispParams->rgvarg[i]);
            }
        }
        if (pVarResult) {
            VariantInit(pVarResult);
            hr = S_OK;
        } else {
            hr = S_OK;
        }
        return hr;
    }

    return DISP_E_MEMBERNOTFOUND;
}

int32_t volvox_grid_get_dispid_default_native(int64_t id, int32_t dispid, void *variant_out) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(id);
    DISPPARAMS empty;
    if (!obj || !variant_out) return E_POINTER;
    memset(&empty, 0, sizeof(empty));
    return vfg_try_public_dispatch_fallback(
        obj,
        (DISPID)dispid,
        DISPATCH_PROPERTYGET,
        &empty,
        (VARIANT *)variant_out);
}

static int vfg_fire_owner_draw_cell_hdc(
    VolvoxGridObject *obj, HDC hdc, int32_t row, int32_t col, const RECT *cell_rect)
{
    VARIANT_BOOL done = VARIANT_FALSE;
    VARIANT args[8];
    int saved_dc;
    if (!obj || !hdc || !cell_rect) return 0;
    saved_dc = SaveDC(hdc);
    if (!saved_dc) return 0;
    IntersectClipRect(hdc, cell_rect->left, cell_rect->top, cell_rect->right, cell_rect->bottom);
    if (obj->owner_draw_callback) {
        int32_t done = obj->owner_draw_callback(
            obj->owner_draw_callback_ctx,
            obj->grid_id,
            hdc,
            row,
            col,
            cell_rect->left,
            cell_rect->top,
            cell_rect->right,
            cell_rect->bottom);
        if (done != 0) {
            RestoreDC(hdc, saved_dc);
            return 1;
        }
    }
    VariantInit(&args[7]); args[7].vt = VT_I4; args[7].lVal = (LONG)(LONG_PTR)hdc;
    VariantInit(&args[6]); args[6].vt = VT_I4; args[6].lVal = row;
    VariantInit(&args[5]); args[5].vt = VT_I4; args[5].lVal = col;
    VariantInit(&args[4]); args[4].vt = VT_I4; args[4].lVal = cell_rect->left;
    VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = cell_rect->top;
    VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = cell_rect->right;
    VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = cell_rect->bottom;
    VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = &done;
    vfg_fire_event(obj, DISPID_VFG_EVT_DRAWCELL, args, 8);
    RestoreDC(hdc, saved_dc);
    return done != VARIANT_FALSE;
}

static void vfg_owner_draw_add_done_rect(HRGN done_rgn, const RECT *cell) {
    HRGN cell_rgn;
    if (!done_rgn || !cell) return;
    cell_rgn = CreateRectRgn(cell->left, cell->top, cell->right, cell->bottom);
    if (!cell_rgn) return;
    CombineRgn(done_rgn, done_rgn, cell_rgn, RGN_OR);
    DeleteObject(cell_rgn);
}

static int vfg_fire_owner_draw_row_hdc(
    VolvoxGridObject *obj,
    HDC hdc,
    const RECT *bounds,
    HRGN done_rgn,
    int32_t row,
    int top,
    int bottom)
{
    int32_t cols;
    int32_t fixed_cols;
    int32_t left_col;
    int x;
    int emitted = 0;
    int done_count = 0;
    if (!obj || !hdc || !bounds || top >= bounds->bottom || bottom <= bounds->top) return 0;
    cols = volvox_grid_get_cols(obj->grid_id);
    fixed_cols = obj->fixed_cols_cached;
    if (fixed_cols < 0) fixed_cols = 0;
    if (fixed_cols > cols) fixed_cols = cols;
    left_col = vfg_get_left_col_cached(obj->grid_id);
    if (left_col < fixed_cols) left_col = fixed_cols;
    if (left_col < 0) left_col = 0;

    x = bounds->left;
    for (int32_t col = 0; col < fixed_cols && col < cols && x < bounds->right; ++col) {
        int cw = volvox_grid_get_col_width(obj->grid_id, col);
        RECT cell;
        if (cw <= 0) cw = 1;
        SetRect(&cell, x, top, x + cw, bottom);
        if (cell.right > bounds->left && cell.left < bounds->right) {
            if (vfg_fire_owner_draw_cell_hdc(obj, hdc, row, col, &cell)) {
                vfg_owner_draw_add_done_rect(done_rgn, &cell);
                done_count++;
            }
        }
        x += cw;
        emitted++;
        if (emitted > 256) return done_count;
    }

    for (int32_t col = left_col; col < cols && x < bounds->right; ++col) {
        int cw = volvox_grid_get_col_width(obj->grid_id, col);
        RECT cell;
        if (cw <= 0) cw = 1;
        SetRect(&cell, x, top, x + cw, bottom);
        if (cell.right > bounds->left && cell.left < bounds->right) {
            if (vfg_fire_owner_draw_cell_hdc(obj, hdc, row, col, &cell)) {
                vfg_owner_draw_add_done_rect(done_rgn, &cell);
                done_count++;
            }
        }
        x += cw;
        emitted++;
        if (emitted > 256) return done_count;
    }
    return done_count;
}

static HRGN vfg_fire_owner_draw_visible_hdc(VolvoxGridObject *obj, HDC hdc, const RECT *bounds) {
    int32_t mode;
    int32_t rows;
    int32_t fixed_rows;
    int32_t top_row;
    int y;
    int emitted = 0;
    int done_count = 0;
    HRGN done_rgn;
    if (!obj || !hdc || !bounds || obj->sink_count == 0) return NULL;
    mode = volvox_grid_get_owner_draw_compat(obj->grid_id);
    if (mode == 0) return NULL;
    done_rgn = CreateRectRgn(0, 0, 0, 0);
    if (!done_rgn) return NULL;
    rows = volvox_grid_get_rows(obj->grid_id);
    fixed_rows = obj->fixed_rows_cached;
    if (fixed_rows < 0) fixed_rows = 0;
    if (fixed_rows > rows) fixed_rows = rows;
    top_row = volvox_grid_get_top_row(obj->grid_id);
    if (top_row < fixed_rows) top_row = fixed_rows;
    if (top_row < 0) top_row = 0;

    y = bounds->top;
    for (int32_t row = 0; row < fixed_rows && row < rows && y < bounds->bottom; ++row) {
        int rh = volvox_grid_get_row_height(obj->grid_id, row);
        if (rh <= 0) rh = 1;
        done_count += vfg_fire_owner_draw_row_hdc(obj, hdc, bounds, done_rgn, row, y, y + rh);
        y += rh;
        emitted++;
        if (emitted > 512) break;
    }

    for (int32_t row = top_row; emitted <= 512 && row < rows && y < bounds->bottom; ++row) {
        int rh = volvox_grid_get_row_height(obj->grid_id, row);
        if (rh <= 0) rh = 1;
        done_count += vfg_fire_owner_draw_row_hdc(obj, hdc, bounds, done_rgn, row, y, y + rh);
        y += rh;
        emitted++;
    }
    if (done_count <= 0) {
        DeleteObject(done_rgn);
        return NULL;
    }
    return done_rgn;
}

int32_t volvox_grid_set_owner_draw_callback_native(
    int64_t id,
    volvox_grid_owner_draw_callback_fn callback,
    void *ctx)
{
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(id);
    if (!obj) return E_INVALIDARG;
    obj->owner_draw_callback = callback;
    obj->owner_draw_callback_ctx = ctx;
    return S_OK;
}

int32_t volvox_grid_owner_draw_reply_native(int64_t id, int32_t done) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(id);
    if (!obj) return E_INVALIDARG;
    obj->owner_draw_reply_done = done != 0;
    return S_OK;
}

int32_t volvox_grid_owner_draw_measure_callback_native(
    int64_t id,
    volvox_grid_owner_draw_measure_fn callback,
    void *ctx)
{
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(id);
    if (!obj) return E_INVALIDARG;
    obj->owner_draw_measure_callback = callback;
    obj->owner_draw_measure_ctx = ctx;
    return S_OK;
}

static HRESULT vfg_draw_to_dc_sized(
    VolvoxGridObject *obj, HDC hdcDraw, const RECT *bounds, int render_w, int render_h)
{
    int w;
    int h;
    int stride;
    uint8_t *pixels;
    BITMAPINFO bmi;
    int32_t rc;
    HRGN done_rgn = NULL;
    int saved_clip_dc = 0;
    if (!obj || !hdcDraw || !bounds) return E_INVALIDARG;
    w = (int)(bounds->right - bounds->left);
    h = (int)(bounds->bottom - bounds->top);
    if (w <= 0 || h <= 0 || render_w <= 0 || render_h <= 0) return S_OK;

    stride = render_w * 4;
    pixels = (uint8_t *)HeapAlloc(GetProcessHeap(), 0, stride * render_h);
    if (!pixels) return E_OUTOFMEMORY;

    rc = volvox_grid_render_bgra(obj->grid_id, pixels, render_w, render_h);
    if (rc != 0) {
        FillRect(hdcDraw, bounds, (HBRUSH)GetStockObject(LTGRAY_BRUSH));
        HeapFree(GetProcessHeap(), 0, pixels);
        return S_OK;
    }

    memset(&bmi, 0, sizeof(bmi));
    bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = render_w;
    bmi.bmiHeader.biHeight = -render_h;
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 32;
    bmi.bmiHeader.biCompression = BI_RGB;

    if (volvox_grid_get_owner_draw_compat(obj->grid_id) != 0 && obj->sink_count > 0) {
        FillRect(hdcDraw, bounds, (HBRUSH)GetStockObject(WHITE_BRUSH));
        done_rgn = vfg_fire_owner_draw_visible_hdc(obj, hdcDraw, bounds);
        if (done_rgn) {
            HRGN full_rgn = CreateRectRgn(bounds->left, bounds->top, bounds->right, bounds->bottom);
            HRGN blit_rgn = CreateRectRgn(0, 0, 0, 0);
            if (full_rgn && blit_rgn &&
                CombineRgn(blit_rgn, full_rgn, done_rgn, RGN_DIFF) != ERROR) {
                saved_clip_dc = SaveDC(hdcDraw);
                if (saved_clip_dc) SelectClipRgn(hdcDraw, blit_rgn);
            }
            if (full_rgn) DeleteObject(full_rgn);
            if (blit_rgn) DeleteObject(blit_rgn);
            DeleteObject(done_rgn);
            done_rgn = NULL;
        }
    }

    if (render_w == w && render_h == h) {
        SetDIBitsToDevice(
            hdcDraw,
            bounds->left,
            bounds->top,
            w,
            h,
            0,
            0,
            0,
            render_h,
            pixels,
            &bmi,
            DIB_RGB_COLORS);
    } else {
        SetStretchBltMode(hdcDraw, HALFTONE);
        StretchDIBits(
            hdcDraw,
            bounds->left,
            bounds->top,
            w,
            h,
            0,
            0,
            render_w,
            render_h,
            pixels,
            &bmi,
            DIB_RGB_COLORS,
            SRCCOPY);
    }
    if (saved_clip_dc) RestoreDC(hdcDraw, saved_clip_dc);

    HeapFree(GetProcessHeap(), 0, pixels);
    return S_OK;
}

static HRESULT vfg_draw_to_dc(VolvoxGridObject *obj, HDC hdcDraw, const RECT *bounds) {
    int w;
    int h;
    if (!obj || !hdcDraw || !bounds) return E_INVALIDARG;
    w = (int)(bounds->right - bounds->left);
    h = (int)(bounds->bottom - bounds->top);
    return vfg_draw_to_dc_sized(obj, hdcDraw, bounds, w, h);
}

int32_t volvox_grid_get_extent_himetric_native(int64_t id, int32_t *cx, int32_t *cy) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(id);
    if (!obj || !cx || !cy) return E_POINTER;
    *cx = obj->extent_himetric.cx;
    *cy = obj->extent_himetric.cy;
    return S_OK;
}

int32_t volvox_grid_paint_to_hdc_native(
    int64_t id,
    void *hdc,
    int32_t x,
    int32_t y,
    int32_t w,
    int32_t h,
    int32_t aspect)
{
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(id);
    RECT bounds;
    if (!obj || !hdc) return E_POINTER;
    if (aspect != DVASPECT_CONTENT) return DV_E_DVASPECT;
    if (w <= 0 || h <= 0) return S_OK;
    SetRect(&bounds, x, y, x + w, y + h);
    return vfg_draw_to_dc_sized(obj, (HDC)hdc, &bounds, w, h);
}

static HRESULT vfg_print_grid(VolvoxGridObject *obj) {
    PRINTDLGW pd;
    DOCINFOW docinfo;
    HDC hdc = NULL;
    RECT page_rect;
    RECT draw_rect;
    RECT client_rect;
    int page_w;
    int page_h;
    int dpi_x;
    int dpi_y;
    int render_w;
    int render_h;
    int rows;
    int fixed_rows;
    int fixed_h = 0;
    int available_h;
    int page_start_row;
    int saved_top_row = 0;
    int saved_left_col = 0;
    int restore_w = 0;
    int restore_h = 0;
    int32_t out_len = 0;
    uint8_t *ignore = NULL;
    HRESULT hr = S_OK;

    if (!obj) return E_POINTER;

    ZeroMemory(&pd, sizeof(pd));
    pd.lStructSize = sizeof(pd);
    pd.hwndOwner = obj->hwnd_ctrl ? obj->hwnd_ctrl : obj->hwnd_parent;
    pd.Flags = PD_RETURNDC | PD_NOPAGENUMS | PD_NOSELECTION | PD_USEDEVMODECOPIESANDCOLLATE;
    if (!PrintDlgW(&pd)) {
        return CommDlgExtendedError() == 0 ? S_OK : E_FAIL;
    }

    hdc = pd.hDC;
    page_w = GetDeviceCaps(hdc, HORZRES);
    page_h = GetDeviceCaps(hdc, VERTRES);
    dpi_x = GetDeviceCaps(hdc, LOGPIXELSX);
    dpi_y = GetDeviceCaps(hdc, LOGPIXELSY);
    render_w = MulDiv(page_w, VFG_DEFAULT_DPI, dpi_x > 0 ? dpi_x : VFG_DEFAULT_DPI);
    render_h = MulDiv(page_h, VFG_DEFAULT_DPI, dpi_y > 0 ? dpi_y : VFG_DEFAULT_DPI);
    if (render_w <= 0) render_w = page_w;
    if (render_h <= 0) render_h = page_h;

    ZeroMemory(&docinfo, sizeof(docinfo));
    docinfo.cbSize = sizeof(docinfo);
    docinfo.lpszDocName = L"VolvoxGrid";
    if (StartDocW(hdc, &docinfo) <= 0) {
        hr = E_FAIL;
        goto cleanup;
    }

    SetRect(&page_rect, 0, 0, page_w, page_h);
    if (obj->hwnd_ctrl && GetClientRect(obj->hwnd_ctrl, &client_rect)) {
        restore_w = (int)(client_rect.right - client_rect.left);
        restore_h = (int)(client_rect.bottom - client_rect.top);
    }
    rows = volvox_grid_get_rows(obj->grid_id);
    fixed_rows = obj->fixed_rows_cached;
    if (fixed_rows < 0) fixed_rows = 0;
    if (fixed_rows > rows) fixed_rows = rows;
    for (int row = 0; row < fixed_rows; ++row) {
        int rh = volvox_grid_get_row_height(obj->grid_id, row);
        fixed_h += rh > 0 ? rh : 1;
    }
    available_h = render_h - fixed_h;
    if (available_h <= 0) available_h = render_h;

    saved_top_row = volvox_grid_get_top_row(obj->grid_id);
    saved_left_col = vfg_get_left_col_cached(obj->grid_id);
    ignore = vfg_native_set_left_col(obj->grid_id, saved_left_col, &out_len);
    if (ignore) volvox_grid_free(ignore, out_len);

    page_start_row = fixed_rows < rows ? fixed_rows : 0;
    if (rows <= 0) page_start_row = 0;

    for (;;) {
        int candidate_next = page_start_row;
        int break_row = rows;
        int data_h = 0;
        int draw_render_h;

        while (candidate_next < rows) {
            int rh = volvox_grid_get_row_height(obj->grid_id, candidate_next);
            if (rh <= 0) rh = 1;
            if (data_h + rh > available_h && candidate_next > page_start_row) {
                break;
            }
            data_h += rh;
            candidate_next++;
        }

        if (candidate_next < rows) {
            int chosen = 0;
            for (int probe = candidate_next; probe > page_start_row; --probe) {
                VARIANT_BOOL break_ok = VARIANT_TRUE;
                VARIANT args[2];
                VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = probe;
                VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = &break_ok;
                vfg_fire_event(obj, DISPID_VFG_EVT_BEFOREPAGEBREAK, args, 2);
                if (break_ok != VARIANT_FALSE) {
                    break_row = probe;
                    chosen = 1;
                    break;
                }
            }
            if (!chosen) {
                break_row = candidate_next;
            }
            data_h = 0;
            for (int row = page_start_row; row < break_row; ++row) {
                int rh = volvox_grid_get_row_height(obj->grid_id, row);
                data_h += rh > 0 ? rh : 1;
            }
        }

        draw_render_h = fixed_h + data_h;
        if (draw_render_h <= 0 || draw_render_h > render_h) draw_render_h = render_h;
        draw_rect = page_rect;
        draw_rect.bottom = draw_rect.top + MulDiv(page_h, draw_render_h, render_h);
        if (draw_rect.bottom <= draw_rect.top || draw_rect.bottom > page_rect.bottom) {
            draw_rect.bottom = page_rect.bottom;
        }

        ignore = vfg_native_set_top_row(obj->grid_id, page_start_row, &out_len);
        if (ignore) volvox_grid_free(ignore, out_len);

        if (StartPage(hdc) <= 0) {
            AbortDoc(hdc);
            hr = E_FAIL;
            goto cleanup;
        }
        hr = vfg_draw_to_dc_sized(obj, hdc, &draw_rect, render_w, draw_render_h);
        if (FAILED(hr) || EndPage(hdc) <= 0) {
            AbortDoc(hdc);
            hr = E_FAIL;
            goto cleanup;
        }

        if (break_row >= rows) {
            break;
        }
        page_start_row = break_row;
    }

    if (EndDoc(hdc) <= 0) {
        AbortDoc(hdc);
        hr = E_FAIL;
    }

cleanup:
    ignore = vfg_native_set_top_row(obj->grid_id, saved_top_row, &out_len);
    if (ignore) volvox_grid_free(ignore, out_len);
    ignore = vfg_native_set_left_col(obj->grid_id, saved_left_col, &out_len);
    if (ignore) volvox_grid_free(ignore, out_len);
    if (restore_w > 0 && restore_h > 0) {
        volvox_grid_resize_viewport_native(obj->grid_id, restore_w, restore_h);
    }
    if (hdc) DeleteDC(hdc);
    if (pd.hDevMode) GlobalFree(pd.hDevMode);
    if (pd.hDevNames) GlobalFree(pd.hDevNames);
    return hr;
}

static HRESULT vfg_pump_engine_events(VolvoxGridObject *obj) {
    for (;;) {
        int32_t event_len = 0;
        uint8_t *event_buf = NULL;
        VFGProtoEvent evt;
        VARIANT_BOOL cancel = VARIANT_FALSE;

        if (!obj || obj->grid_id < 0) return E_FAIL;
        event_buf = volvox_grid_peek_next_event_native(obj->grid_id, &event_len);
        if (!event_buf || event_len <= 0) {
            if (event_buf) volvox_grid_free(event_buf, event_len);
            break;
        }
        if (!vfg_decode_grid_event(event_buf, event_len, &evt)) {
            volvox_grid_free(event_buf, event_len);
            volvox_grid_ack_event_native(obj->grid_id, 0);
            continue;
        }
        volvox_grid_free(event_buf, event_len);

        switch (evt.kind) {
        case 2: {
            VARIANT args[5];
            VariantInit(&args[4]); args[4].vt = VT_I4; args[4].lVal = evt.old_row;
            VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = evt.old_col;
            VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = evt.new_row;
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = evt.new_col;
            VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = &cancel;
            vfg_fire_event(obj, DISPID_VFG_EVT_BEFOREROWCOLCHANGE, args, 5);
            if (evt.event_id > 0) {
                volvox_grid_send_event_decision_native(
                    obj->grid_id, evt.event_id, cancel != VARIANT_FALSE);
            }
            break;
        }
        case 3:
            vfg_fire_after_row_col_change_event(
                obj, evt.old_row, evt.old_col, evt.new_row, evt.new_col);
            vfg_fire_simple_event(obj, DISPID_VFG_EVT_ROWCOLCHANGE);
            break;
        case 4:
            vfg_fire_before_sel_change_event(
                obj, evt.old_row, evt.old_col, evt.new_row, evt.new_col, &cancel);
            if (evt.event_id > 0) {
                volvox_grid_send_event_decision_native(
                    obj->grid_id, evt.event_id, cancel != VARIANT_FALSE);
            }
            break;
        case 5:
            vfg_fire_after_sel_change_event(
                obj, evt.old_row, evt.old_col, evt.new_row, evt.new_col);
            vfg_fire_simple_event(obj, DISPID_VFG_EVT_SELCHANGE);
            break;
        case 6:
            vfg_fire_simple_event(obj, DISPID_VFG_EVT_ENTERCELL);
            break;
        case 7:
            vfg_fire_simple_event(obj, DISPID_VFG_EVT_LEAVECELL);
            break;
        case 8:
            vfg_fire_before_edit_event(obj, evt.row, evt.col, &cancel);
            if (evt.event_id > 0) {
                volvox_grid_send_event_decision_native(
                    obj->grid_id, evt.event_id, cancel != VARIANT_FALSE);
            }
            break;
        case 9: {
            vfg_fire_start_edit_event(obj, evt.row, evt.col, &cancel);
            if (cancel != VARIANT_FALSE) {
                int32_t out_len = 0;
                uint8_t *resp = volvox_grid_cancel_edit(obj->grid_id, &out_len);
                if (resp) volvox_grid_free(resp, out_len);
            }
            break;
        }
        case 10:
            vfg_fire_after_edit_event(obj, evt.row, evt.col);
            break;
        case 11:
            vfg_fire_validate_edit_event(obj, evt.row, evt.col, &cancel);
            if (evt.event_id > 0) {
                volvox_grid_send_event_decision_native(
                    obj->grid_id, evt.event_id, cancel != VARIANT_FALSE);
            }
            break;
        case 12:
            vfg_fire_simple_event(obj, DISPID_VFG_EVT_CHANGEEDIT);
            break;
        case 14:
            vfg_fire_key_edit_event(
                obj,
                DISPID_VFG_EVT_KEYDOWNEDIT,
                evt.row >= 0 ? evt.row : volvox_grid_get_row(obj->grid_id),
                evt.col >= 0 ? evt.col : volvox_grid_get_col(obj->grid_id),
                evt.key_code,
                evt.modifier);
            break;
        case 15:
            vfg_fire_key_press_edit_event(
                obj,
                evt.row >= 0 ? evt.row : volvox_grid_get_row(obj->grid_id),
                evt.col >= 0 ? evt.col : volvox_grid_get_col(obj->grid_id),
                evt.key_ascii);
            break;
        case 16:
            vfg_fire_key_edit_event(
                obj,
                DISPID_VFG_EVT_KEYUPEDIT,
                evt.row >= 0 ? evt.row : volvox_grid_get_row(obj->grid_id),
                evt.col >= 0 ? evt.col : volvox_grid_get_col(obj->grid_id),
                evt.key_code,
                evt.modifier);
            break;
        case 17:
        case 18: {
            VARIANT args[2];
            DISPID dispid = evt.kind == 17
                ? DISPID_VFG_EVT_SETUPEDITSTYLE
                : DISPID_VFG_EVT_SETUPEDITWINDOW;
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = evt.row;
            VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = evt.col;
            vfg_fire_event(obj, dispid, args, 2);
            break;
        }
        case 19: {
            VARIANT args[3];
            int32_t row = evt.row >= 0 ? evt.row : volvox_grid_get_row(obj->grid_id);
            int32_t col = evt.col >= 0 ? evt.col : volvox_grid_get_col(obj->grid_id);
            VARIANT_BOOL finish_edit = VARIANT_FALSE;
            VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = row;
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = col;
            VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = &finish_edit;
            vfg_fire_event(obj, DISPID_VFG_EVT_COMBOCLOSEUP, args, 3);
            break;
        }
        case 20: {
            VARIANT args[2];
            int32_t row = evt.row >= 0 ? evt.row : volvox_grid_get_row(obj->grid_id);
            int32_t col = evt.col >= 0 ? evt.col : volvox_grid_get_col(obj->grid_id);
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = row;
            VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = col;
            vfg_fire_event(obj, DISPID_VFG_EVT_COMBODROPDOWN, args, 2);
            break;
        }
        case 21: {
            VARIANT args[2];
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = evt.row;
            VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = evt.col;
            vfg_fire_event(obj, DISPID_VFG_EVT_CELLCHANGED, args, 2);
            break;
        }
        case 23: {
            short order_short = (short)obj->sort_order_cached;
            vfg_fire_before_sort_event(obj, evt.row, &order_short);
            break;
        }
        case 24:
            vfg_fire_after_sort_event(obj, evt.col >= 0 ? evt.col : evt.row, obj->sort_order_cached);
            break;
        case 25: {
            short cmp = (short)evt.extra2;
            VARIANT args[3];
            VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = evt.row;
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = evt.col;
            VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_I2; args[0].piVal = &cmp;
            vfg_fire_event(obj, DISPID_VFG_EVT_COMPARE, args, 3);
            break;
        }
        case 26: {
            short state = (short)(evt.col != 0);
            VARIANT args[3];
            VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = evt.row;
            VariantInit(&args[1]); args[1].vt = VT_I2; args[1].iVal = state;
            VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = &cancel;
            vfg_fire_event(obj, DISPID_VFG_EVT_BEFORECOLLAPSE, args, 3);
            if (evt.event_id > 0) {
                volvox_grid_send_event_decision_native(
                    obj->grid_id, evt.event_id, cancel != VARIANT_FALSE);
            }
            break;
        }
        case 27: {
            short state = (short)(evt.col != 0);
            VARIANT args[2];
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = evt.row;
            VariantInit(&args[0]); args[0].vt = VT_I2; args[0].iVal = state;
            vfg_fire_event(obj, DISPID_VFG_EVT_AFTERCOLLAPSE, args, 2);
            break;
        }
        case 65: {
            short state = (short)(evt.col != 0);
            VARIANT args[3];
            VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = evt.row;
            VariantInit(&args[1]); args[1].vt = VT_I2; args[1].iVal = state;
            VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = &cancel;
            vfg_fire_event(obj, DISPID_VFG_EVT_BEFORECOLLAPSE, args, 3);
            if (evt.event_id > 0) {
                volvox_grid_send_event_decision_native(
                    obj->grid_id, evt.event_id, cancel != VARIANT_FALSE);
            }
            break;
        }
        case 66: {
            short state = (short)(evt.col != 0);
            VARIANT args[2];
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = evt.row;
            VariantInit(&args[0]); args[0].vt = VT_I2; args[0].iVal = state;
            vfg_fire_event(obj, DISPID_VFG_EVT_AFTERCOLLAPSE, args, 2);
            break;
        }
        case 28:
            vfg_fire_before_scroll_event(
                obj, evt.old_row, evt.old_col, evt.new_row, evt.new_col, &cancel);
            if (evt.event_id > 0) {
                volvox_grid_send_event_decision_native(
                    obj->grid_id, evt.event_id, cancel != VARIANT_FALSE);
            }
            break;
        case 29:
            vfg_fire_after_scroll_event(obj, evt.old_row, evt.old_col, evt.new_row, evt.new_col);
            break;
        case 30: {
            VARIANT arg;
            VariantInit(&arg);
            arg.vt = VT_I4;
            arg.lVal = volvox_grid_get_row(obj->grid_id);
            vfg_fire_event(obj, DISPID_VFG_EVT_BEFORESCROLLTIP, &arg, 1);
            break;
        }
        case 31: {
            VARIANT args[3];
            VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = evt.row;
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = evt.col;
            VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = &cancel;
            vfg_fire_event(obj, DISPID_VFG_EVT_BEFOREUSERRESIZE, args, 3);
            if (evt.event_id > 0) {
                volvox_grid_send_event_decision_native(
                    obj->grid_id, evt.event_id, cancel != VARIANT_FALSE);
            }
            break;
        }
        case 32: {
            VARIANT args[2];
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = evt.row;
            VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = evt.col;
            vfg_fire_event(obj, DISPID_VFG_EVT_AFTERUSERRESIZE, args, 2);
            break;
        }
        case 33:
            obj->frozen_rows_cached = evt.row;
            obj->frozen_cols_cached = evt.col;
            vfg_fire_simple_event(obj, DISPID_VFG_EVT_AFTERUSERFREEZE);
            break;
        case 34:
        case 35:
        case 36:
        case 37: {
            VARIANT args[2];
            LONG position = (LONG)evt.col;
            DISPID dispid = DISPID_VFG_EVT_BEFOREMOVECOLUMN;
            if (evt.kind == 35) dispid = DISPID_VFG_EVT_AFTERMOVECOLUMN;
            else if (evt.kind == 36) dispid = DISPID_VFG_EVT_BEFOREMOVEROW;
            else if (evt.kind == 37) dispid = DISPID_VFG_EVT_AFTERMOVEROW;
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = evt.row;
            VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_I4; args[0].plVal = &position;
            vfg_fire_event(obj, dispid, args, 2);
            break;
        }
        case 38:
            vfg_fire_before_mouse_down_event(
                obj,
                obj->last_pointer_button,
                obj->last_pointer_modifier,
                obj->last_pointer_x,
                obj->last_pointer_y,
                &cancel);
            if (evt.event_id > 0) {
                volvox_grid_send_event_decision_native(
                    obj->grid_id, evt.event_id, cancel != VARIANT_FALSE);
            }
            break;
        case 39:
            vfg_fire_mouse_event(
                obj, DISPID_VFG_EVT_MOUSEDOWN, evt.button, evt.modifier, evt.x, evt.y);
            break;
        case 40:
            vfg_fire_mouse_event(
                obj, DISPID_VFG_EVT_MOUSEUP, evt.button, evt.modifier, evt.x, evt.y);
            break;
        case 41:
            vfg_fire_mouse_event(
                obj, DISPID_VFG_EVT_MOUSEMOVE, evt.button, evt.modifier, evt.x, evt.y);
            break;
        case 42:
            vfg_fire_simple_event(obj, DISPID_VFG_EVT_CLICK);
            if (evt.hit_area == VFG_PROTO_HIT_BUTTON
                || evt.hit_area == VFG_PROTO_HIT_DROPDOWN
                || evt.interaction == VFG_PROTO_INTERACTION_BUTTON) {
                vfg_fire_cell_button_click_event(obj, evt.row, evt.col);
            }
            break;
        case 43:
            vfg_fire_simple_event(obj, DISPID_VFG_EVT_DBLCLICK);
            break;
        case 44:
            vfg_fire_key_event(obj, DISPID_VFG_EVT_KEYDOWN, evt.key_code, evt.modifier);
            break;
        case 45:
            vfg_fire_key_press_event(obj, evt.key_ascii);
            break;
        case 46:
            vfg_fire_key_event(obj, DISPID_VFG_EVT_KEYUP, evt.key_code, evt.modifier);
            break;
        case 47: {
            LONG left = (LONG)evt.x;
            LONG top = (LONG)evt.y;
            LONG right = left + (LONG)evt.width;
            LONG bottom = top + (LONG)evt.height;
            VARIANT_BOOL done = VARIANT_FALSE;
            VARIANT args[8];
            VariantInit(&args[7]); args[7].vt = VT_I4; args[7].lVal = 0;
            VariantInit(&args[6]); args[6].vt = VT_I4; args[6].lVal = evt.row;
            VariantInit(&args[5]); args[5].vt = VT_I4; args[5].lVal = evt.col;
            VariantInit(&args[4]); args[4].vt = VT_I4; args[4].lVal = left;
            VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = top;
            VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = right;
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = bottom;
            VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = &done;
            vfg_fire_event(obj, DISPID_VFG_EVT_DRAWCELL, args, 8);
            break;
        }
        case 52:
            vfg_fire_simple_event(obj, DISPID_VFG_EVT_STARTAUTOSEARCH);
            break;
        case 53:
            vfg_fire_simple_event(obj, DISPID_VFG_EVT_ENDAUTOSEARCH);
            break;
        case 54:
            vfg_fire_before_data_refresh_event(obj, &cancel);
            if (evt.event_id > 0) {
                volvox_grid_send_event_decision_native(
                    obj->grid_id, evt.event_id, cancel != VARIANT_FALSE);
            }
            break;
        case 55:
            vfg_fire_simple_event(obj, DISPID_VFG_EVT_AFTERDATAREFRESH);
            break;
        case 56: {
            VARIANT args[2];
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = evt.row;
            VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = evt.col;
            vfg_fire_event(obj, DISPID_VFG_EVT_FILTERDATA, args, 2);
            break;
        }
        case 57: {
            VARIANT_BOOL show_msg = VARIANT_TRUE;
            VARIANT args[2];
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = evt.row;
            VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = &show_msg;
            vfg_fire_event(obj, DISPID_VFG_EVT_ERROR, args, 2);
            break;
        }
        case 58: {
            VARIANT_BOOL break_ok = VARIANT_TRUE;
            VARIANT args[2];
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = evt.row;
            VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = &break_ok;
            vfg_fire_event(obj, DISPID_VFG_EVT_BEFOREPAGEBREAK, args, 2);
            break;
        }
        case 59: {
            VARIANT_BOOL page_cancel = VARIANT_FALSE;
            VARIANT args[3];
            VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = 0;
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = evt.row;
            VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = &page_cancel;
            vfg_fire_event(obj, DISPID_VFG_EVT_STARTPAGE, args, 3);
            break;
        }
        case 60: {
            LONG header_row = evt.row;
            VARIANT args[2];
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = evt.row;
            VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_I4; args[0].plVal = &header_row;
            vfg_fire_event(obj, DISPID_VFG_EVT_GETHEADERROW, args, 2);
            break;
        }
        case 63: {
            VARIANT args[2];
            int32_t row = evt.row >= 0 ? evt.row : volvox_grid_get_row(obj->grid_id);
            int32_t col = evt.col >= 0 ? evt.col : volvox_grid_get_col(obj->grid_id);
            VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = row;
            VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = col;
            vfg_fire_event(obj, DISPID_VFG_EVT_COMBODROPDOWN, args, 2);
            if (evt.event_id > 0) {
                volvox_grid_send_event_decision_native(obj->grid_id, evt.event_id, 0);
            }
            break;
        }
        default:
            break;
        }
        volvox_grid_ack_event_native(obj->grid_id, evt.event_id);
    }
    return vfg_invalidate_control(obj);
}

static HRESULT vfg_handle_pointer_down(
    VolvoxGridObject *obj, float x, float y, int32_t button, int32_t modifier, int32_t dbl_click)
{
    if (!obj) return E_POINTER;
    obj->last_pointer_button = button;
    obj->last_pointer_modifier = modifier;
    obj->last_pointer_x = x;
    obj->last_pointer_y = y;
    if (volvox_grid_pointer_down_native(obj->grid_id, x, y, button, modifier, dbl_click) != 0) {
        return E_FAIL;
    }
    return vfg_pump_engine_events(obj);
}

static HRESULT vfg_handle_pointer_move(
    VolvoxGridObject *obj, float x, float y, int32_t button, int32_t modifier)
{
    if (!obj) return E_POINTER;
    if (volvox_grid_pointer_move_native(obj->grid_id, x, y, button, modifier) != 0) {
        return E_FAIL;
    }
    return vfg_pump_engine_events(obj);
}

static HRESULT vfg_handle_pointer_up(
    VolvoxGridObject *obj, float x, float y, int32_t button, int32_t modifier)
{
    if (!obj) return E_POINTER;
    if (volvox_grid_pointer_up_native(obj->grid_id, x, y, button, modifier) != 0) {
        return E_FAIL;
    }
    return vfg_pump_engine_events(obj);
}

static HCURSOR vfg_cursor_from_mouse_pointer(int32_t mouse_pointer) {
    switch (mouse_pointer) {
    case 1:
        return LoadCursor(NULL, IDC_ARROW);
    case 2:
        return LoadCursor(NULL, IDC_CROSS);
    case 3:
        return LoadCursor(NULL, IDC_IBEAM);
    case 5:
    case 15:
        return LoadCursor(NULL, IDC_SIZEALL);
    case 6:
        return LoadCursor(NULL, IDC_SIZENESW);
    case 7:
        return LoadCursor(NULL, IDC_SIZENS);
    case 8:
        return LoadCursor(NULL, IDC_SIZENWSE);
    case 9:
        return LoadCursor(NULL, IDC_SIZEWE);
    case 10:
        return LoadCursor(NULL, IDC_UPARROW);
    case 11:
        return LoadCursor(NULL, IDC_WAIT);
    case 12:
        return LoadCursor(NULL, IDC_NO);
    case 13:
        return LoadCursor(NULL, IDC_APPSTARTING);
    case 14:
        return LoadCursor(NULL, IDC_HELP);
    default:
        return LoadCursor(NULL, IDC_ARROW);
    }
}

/* Maps the engine's semantic cursor hint (pb::CursorType, see
 * proto/volvoxgrid.proto) to a Win32 HCURSOR. */
static HCURSOR vfg_cursor_from_engine_hint(int32_t cursor_hint) {
    switch (cursor_hint) {
    case 1:  /* CURSOR_RESIZE_COL  */ return LoadCursor(NULL, IDC_SIZEWE);
    case 2:  /* CURSOR_RESIZE_ROW  */ return LoadCursor(NULL, IDC_SIZENS);
    case 3:  /* CURSOR_MOVE_COL    */ return LoadCursor(NULL, IDC_SIZEALL);
    case 4:  /* CURSOR_TEXT        */ return LoadCursor(NULL, IDC_IBEAM);
    case 5:  /* CURSOR_HAND        */ return LoadCursor(NULL, IDC_HAND);
    case 6:  /* CURSOR_MOVE_ROW    */ return LoadCursor(NULL, IDC_SIZEALL);
    case 7:  /* CURSOR_WAIT        */ return LoadCursor(NULL, IDC_WAIT);
    case 8:  /* CURSOR_NOT_ALLOWED */ return LoadCursor(NULL, IDC_NO);
    case 9:  /* CURSOR_CROSSHAIR   */ return LoadCursor(NULL, IDC_CROSS);
    case 10: /* CURSOR_COPY        */ return LoadCursor(NULL, IDC_HAND);
    default: /* CURSOR_DEFAULT     */ return LoadCursor(NULL, IDC_ARROW);
    }
}

static HCURSOR vfg_resolve_cursor(VolvoxGridObject *obj) {
    HCURSOR cursor = NULL;
    if (!obj) return LoadCursor(NULL, IDC_ARROW);
    if (obj->mouse_pointer_cached != 0) {
        cursor = vfg_cursor_from_mouse_pointer(obj->mouse_pointer_cached);
    } else {
        cursor = vfg_cursor_from_engine_hint(volvox_grid_get_cursor_hint_native(obj->grid_id));
    }
    return cursor ? cursor : LoadCursor(NULL, IDC_ARROW);
}

static void vfg_update_host_cursor(VolvoxGridObject *obj) {
    if (!obj || !obj->hwnd_ctrl) return;
    SetCursor(vfg_resolve_cursor(obj));
}

static HRESULT vfg_handle_key_down(
    VolvoxGridObject *obj, int32_t key_code, int32_t modifier)
{
    if (!obj) return E_POINTER;
    if (volvox_grid_key_down_native(obj->grid_id, key_code, modifier) != 0) {
        return E_FAIL;
    }
    return vfg_pump_engine_events(obj);
}

static HRESULT vfg_handle_key_press(
    VolvoxGridObject *obj, uint32_t char_code)
{
    if (!obj) return E_POINTER;
    if (volvox_grid_key_press_native(obj->grid_id, char_code) != 0) {
        return E_FAIL;
    }
    return vfg_pump_engine_events(obj);
}

static int vfg_button_from_msg(UINT msg, WPARAM wp) {
    switch (msg) {
    case WM_LBUTTONDOWN:
    case WM_LBUTTONUP:
    case WM_LBUTTONDBLCLK:
        return 1;
    case WM_MBUTTONDOWN:
    case WM_MBUTTONUP:
    case WM_MBUTTONDBLCLK:
        return 2;
    case WM_RBUTTONDOWN:
    case WM_RBUTTONUP:
    case WM_RBUTTONDBLCLK:
        return 3;
    default:
        if (wp & MK_LBUTTON) return 1;
        if (wp & MK_MBUTTON) return 2;
        if (wp & MK_RBUTTON) return 3;
        return 0;
    }
}

static LRESULT CALLBACK vfg_control_wndproc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    VolvoxGridObject *obj = (VolvoxGridObject *)GetWindowLongPtrW(hwnd, GWLP_USERDATA);
    switch (msg) {
    case WM_NCCREATE: {
        CREATESTRUCTW *cs = (CREATESTRUCTW *)lp;
        obj = (VolvoxGridObject *)cs->lpCreateParams;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)obj);
        return TRUE;
    }
    case WM_PAINT:
        if (obj) {
            PAINTSTRUCT ps;
            RECT rc;
            HDC hdc = BeginPaint(hwnd, &ps);
            GetClientRect(hwnd, &rc);
            vfg_draw_to_dc(obj, hdc, &rc);
            EndPaint(hwnd, &ps);
            return 0;
        }
        break;
    case WM_SIZE:
        if (obj) {
            volvox_grid_resize_viewport_native(obj->grid_id, LOWORD(lp), HIWORD(lp));
            vfg_notify_view_change(obj);
            return 0;
        }
        break;
    case WM_SETFOCUS:
        if (obj) {
            obj->has_focus = 1;
            return 0;
        }
        break;
    case WM_KILLFOCUS:
        if (obj) {
            obj->has_focus = 0;
            return 0;
        }
        break;
    case WM_GETDLGCODE:
        if (obj && volvox_grid_get_tab_behavior_native(obj->grid_id) == 1) {
            return DLGC_WANTTAB | DLGC_WANTARROWS | DLGC_WANTCHARS;
        }
        break;
    case WM_LBUTTONDOWN:
    case WM_RBUTTONDOWN:
    case WM_MBUTTONDOWN:
        if (obj) {
            SetFocus(hwnd);
            SetCapture(hwnd);
            vfg_handle_pointer_down(
                obj,
                (float)GET_X_LPARAM(lp),
                (float)GET_Y_LPARAM(lp),
                vfg_button_from_msg(msg, wp),
                vfg_current_modifier_flags(),
                0);
            vfg_update_host_cursor(obj);
            return 0;
        }
        break;
    case WM_LBUTTONDBLCLK:
    case WM_RBUTTONDBLCLK:
    case WM_MBUTTONDBLCLK:
        if (obj) {
            SetFocus(hwnd);
            SetCapture(hwnd);
            vfg_handle_pointer_down(
                obj,
                (float)GET_X_LPARAM(lp),
                (float)GET_Y_LPARAM(lp),
                vfg_button_from_msg(msg, wp),
                vfg_current_modifier_flags(),
                1);
            vfg_update_host_cursor(obj);
            return 0;
        }
        break;
    case WM_LBUTTONUP:
    case WM_RBUTTONUP:
    case WM_MBUTTONUP:
        if (obj) {
            vfg_handle_pointer_up(
                obj,
                (float)GET_X_LPARAM(lp),
                (float)GET_Y_LPARAM(lp),
                vfg_button_from_msg(msg, wp),
                vfg_current_modifier_flags());
            if (GetCapture() == hwnd) ReleaseCapture();
            vfg_update_host_cursor(obj);
            return 0;
        }
        break;
    case WM_MOUSEMOVE:
        if (obj) {
            vfg_handle_pointer_move(
                obj,
                (float)GET_X_LPARAM(lp),
                (float)GET_Y_LPARAM(lp),
                vfg_button_from_msg(msg, wp),
                vfg_current_modifier_flags());
            vfg_update_host_cursor(obj);
            return 0;
        }
        break;
    case WM_SETCURSOR:
        if (obj && LOWORD(lp) == HTCLIENT) {
            vfg_update_host_cursor(obj);
            return TRUE;
        }
        break;
    case WM_MOUSEWHEEL:
        if (obj) {
            float delta_y = (float)(-(SHORT)HIWORD(wp)) / (float)WHEEL_DELTA;
            volvox_grid_scroll_native(obj->grid_id, 0.0f, delta_y);
            vfg_pump_engine_events(obj);
            return 0;
        }
        break;
    case WM_TIMER:
        if (obj && wp == VFG_EVENT_TIMER_ID) {
            vfg_pump_engine_events(obj);
            return 0;
        }
        break;
    case WM_KEYDOWN:
        if (obj) {
            vfg_handle_key_down(obj, (int32_t)wp, vfg_current_modifier_flags());
            return 0;
        }
        break;
    case WM_CHAR:
        if (obj) {
            vfg_handle_key_press(obj, (uint32_t)wp);
            return 0;
        }
        break;
    case WM_KEYUP:
        if (obj) {
            vfg_fire_key_event(obj, DISPID_VFG_EVT_KEYUP, (int32_t)wp, vfg_current_modifier_flags());
            return 0;
        }
        break;
    default:
        break;
    }
    return DefWindowProcW(hwnd, msg, wp, lp);
}

static HRESULT vfg_ensure_window_class(void) {
    static ATOM atom = 0;
    WNDCLASSW wc;
    if (atom) return S_OK;
    memset(&wc, 0, sizeof(wc));
    wc.style = CS_DBLCLKS;
    wc.lpfnWndProc = vfg_control_wndproc;
    wc.hInstance = GetModuleHandleW(NULL);
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    wc.lpszClassName = VFG_WINDOW_CLASS_NAME;
    atom = RegisterClassW(&wc);
    return atom ? S_OK : HRESULT_FROM_WIN32(GetLastError());
}

static HRESULT vfg_resize_control_window(VolvoxGridObject *obj) {
    int width;
    int height;
    if (!obj || !obj->hwnd_ctrl) return S_OK;
    width = obj->pos_rect.right - obj->pos_rect.left;
    height = obj->pos_rect.bottom - obj->pos_rect.top;
    if (width < 0) width = 0;
    if (height < 0) height = 0;
    MoveWindow(
        obj->hwnd_ctrl,
        obj->pos_rect.left,
        obj->pos_rect.top,
        width,
        height,
        TRUE);
    volvox_grid_resize_viewport_native(obj->grid_id, width, height);
    return S_OK;
}

static HRESULT vfg_activate_in_place(
    VolvoxGridObject *obj, HWND hwndParent, const RECT *lprcPosRect, BOOL ui_activate)
{
    RECT rc = { 0, 0, 0, 0 };
    OLEINPLACEFRAMEINFO fi;
    HRESULT hr;
    if (!obj || !obj->client_site) return OLE_E_NOTRUNNING;
    if (!obj->inplace_site) {
        hr = IOleClientSite_QueryInterface(
            obj->client_site, &IID_IOleInPlaceSite, (void **)&obj->inplace_site);
        if (FAILED(hr)) return hr;
    }

    hr = IOleInPlaceSite_CanInPlaceActivate(obj->inplace_site);
    if (FAILED(hr)) return hr;
    if (!obj->in_place_active) {
        hr = IOleInPlaceSite_OnInPlaceActivate(obj->inplace_site);
        if (FAILED(hr)) return hr;
        obj->in_place_active = 1;
    }

    if (!hwndParent) {
        hr = IOleInPlaceSite_GetWindow(obj->inplace_site, &hwndParent);
        if (FAILED(hr)) return hr;
    }
    obj->hwnd_parent = hwndParent;

    if (lprcPosRect) {
        obj->pos_rect = *lprcPosRect;
        obj->clip_rect = *lprcPosRect;
    } else {
        GetClientRect(hwndParent, &rc);
        obj->pos_rect = rc;
        obj->clip_rect = rc;
    }

    if (obj->inplace_frame) { IOleInPlaceFrame_Release(obj->inplace_frame); obj->inplace_frame = NULL; }
    if (obj->inplace_uiwindow) { IOleInPlaceUIWindow_Release(obj->inplace_uiwindow); obj->inplace_uiwindow = NULL; }
    memset(&fi, 0, sizeof(fi));
    fi.cb = sizeof(fi);
    hr = IOleInPlaceSite_GetWindowContext(
        obj->inplace_site,
        &obj->inplace_frame,
        &obj->inplace_uiwindow,
        &obj->pos_rect,
        &obj->clip_rect,
        &fi);
    if (FAILED(hr) && !lprcPosRect) {
        GetClientRect(hwndParent, &obj->pos_rect);
        obj->clip_rect = obj->pos_rect;
    }

    hr = vfg_ensure_window_class();
    if (FAILED(hr)) return hr;
    if (!obj->hwnd_ctrl) {
        obj->hwnd_ctrl = CreateWindowExW(
            0,
            VFG_WINDOW_CLASS_NAME,
            L"",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | WS_CLIPSIBLINGS | WS_CLIPCHILDREN,
            obj->pos_rect.left,
            obj->pos_rect.top,
            obj->pos_rect.right - obj->pos_rect.left,
            obj->pos_rect.bottom - obj->pos_rect.top,
            hwndParent,
            NULL,
            GetModuleHandleW(NULL),
            obj);
        if (!obj->hwnd_ctrl) {
            return HRESULT_FROM_WIN32(GetLastError());
        }
    }
    if (!obj->ole_initialized) {
        HRESULT ole_hr = OleInitialize(NULL);
        if (SUCCEEDED(ole_hr) || ole_hr == S_FALSE) {
            obj->ole_initialized = 1;
        }
    }
    if (obj->ole_initialized && !obj->drop_registered && obj->hwnd_ctrl) {
        HRESULT drop_hr = RegisterDragDrop(
            obj->hwnd_ctrl,
            (IDropTarget *)&obj->lpVtblDropTarget);
        if (SUCCEEDED(drop_hr) || drop_hr == DRAGDROP_E_ALREADYREGISTERED) {
            obj->drop_registered = 1;
        }
    }
    vfg_resize_control_window(obj);

    if (obj->inplace_frame) {
        IOleInPlaceFrame_SetActiveObject(
            obj->inplace_frame,
            (IOleInPlaceActiveObject *)&obj->lpVtblInPlaceActiveObject,
            L"VolvoxGrid");
    }
    if (ui_activate && !obj->ui_active) {
        IOleInPlaceSite_OnUIActivate(obj->inplace_site);
        obj->ui_active = 1;
        if (obj->inplace_uiwindow) {
            IOleInPlaceUIWindow_SetActiveObject(
                obj->inplace_uiwindow,
                (IOleInPlaceActiveObject *)&obj->lpVtblInPlaceActiveObject,
                L"VolvoxGrid");
        }
    }
    ShowWindow(obj->hwnd_ctrl, SW_SHOW);
    SetFocus(obj->hwnd_ctrl);
    obj->has_focus = 1;
    volvox_grid_set_event_decision_enabled_native(obj->grid_id, 1);
    if (!obj->event_timer_active) {
        if (SetTimer(obj->hwnd_ctrl, VFG_EVENT_TIMER_ID, VFG_EVENT_TIMER_MS, NULL)) {
            obj->event_timer_active = 1;
        }
    }
    return vfg_notify_view_change(obj);
}

static HRESULT vfg_deactivate_in_place(VolvoxGridObject *obj) {
    if (!obj) return E_POINTER;
    if (obj->ui_active && obj->inplace_site) {
        IOleInPlaceSite_OnUIDeactivate(obj->inplace_site, FALSE);
        obj->ui_active = 0;
    }
    if (obj->inplace_uiwindow) {
        IOleInPlaceUIWindow_SetActiveObject(obj->inplace_uiwindow, NULL, NULL);
        IOleInPlaceUIWindow_Release(obj->inplace_uiwindow);
        obj->inplace_uiwindow = NULL;
    }
    if (obj->inplace_frame) {
        IOleInPlaceFrame_SetActiveObject(obj->inplace_frame, NULL, NULL);
        IOleInPlaceFrame_Release(obj->inplace_frame);
        obj->inplace_frame = NULL;
    }
    if (obj->hwnd_ctrl) {
        if (obj->event_timer_active) {
            KillTimer(obj->hwnd_ctrl, VFG_EVENT_TIMER_ID);
            obj->event_timer_active = 0;
        }
        if (obj->drop_registered) {
            RevokeDragDrop(obj->hwnd_ctrl);
            obj->drop_registered = 0;
        }
        DestroyWindow(obj->hwnd_ctrl);
        obj->hwnd_ctrl = NULL;
    }
    if (obj->ole_initialized) {
        OleUninitialize();
        obj->ole_initialized = 0;
    }
    if (obj->in_place_active && obj->inplace_site) {
        IOleInPlaceSite_OnInPlaceDeactivate(obj->inplace_site);
        obj->in_place_active = 0;
    }
    obj->has_focus = 0;
    volvox_grid_set_event_decision_enabled_native(obj->grid_id, 0);
    return S_OK;
}

static void vfg_set_bstr_copy(BSTR *target, BSTR value) {
    if (!target) return;
    if (value) {
        BSTR copy = SysAllocStringLen(value, SysStringLen(value));
        if (!copy) return; /* OOM — keep old value */
        if (*target) SysFreeString(*target);
        *target = copy;
    } else {
        if (*target) {
            SysFreeString(*target);
            *target = NULL;
        }
    }
}

static void vfg_set_olestr_copy(BSTR *target, LPCOLESTR value) {
    if (!target) return;
    if (value) {
        BSTR copy = SysAllocString(value);
        if (!copy) return; /* OOM — keep old value */
        if (*target) SysFreeString(*target);
        *target = copy;
    } else {
        if (*target) {
            SysFreeString(*target);
            *target = NULL;
        }
    }
}

static void vfg_free_bstr_cache(BSTR *cache, int32_t len) {
    if (!cache) return;
    for (int32_t i = 0; i < len; ++i) {
        if (cache[i]) SysFreeString(cache[i]);
    }
    HeapFree(GetProcessHeap(), 0, cache);
}

static void vfg_set_cached_indexed_bstr(BSTR **cache, int32_t *pLen, int32_t index, BSTR value) {
    BSTR *updated;
    int32_t new_len;
    if (!cache || !pLen || index < 0) return;
    if (index >= *pLen) {
        new_len = index + 1;
        if (*cache) {
            updated = HeapReAlloc(
                GetProcessHeap(),
                HEAP_ZERO_MEMORY,
                *cache,
                (SIZE_T)new_len * sizeof(BSTR));
        } else {
            updated = HeapAlloc(
                GetProcessHeap(),
                HEAP_ZERO_MEMORY,
                (SIZE_T)new_len * sizeof(BSTR));
        }
        if (!updated) return;
        *cache = updated;
        *pLen = new_len;
    }
    if (value) {
        BSTR copy = SysAllocStringLen(value, SysStringLen(value));
        if (!copy) return; /* OOM — keep old value */
        if ((*cache)[index]) SysFreeString((*cache)[index]);
        (*cache)[index] = copy;
    } else {
        if ((*cache)[index]) {
            SysFreeString((*cache)[index]);
            (*cache)[index] = NULL;
        }
    }
}

static BSTR vfg_copy_cached_indexed_bstr(BSTR *cache, int32_t len, int32_t index) {
    BSTR src;
    if (!cache || index < 0 || index >= len) return SysAllocString(L"");
    src = cache[index];
    if (!src) return SysAllocString(L"");
    return SysAllocStringLen(src, SysStringLen(src));
}

static void vfg_set_cached_indexed_i32(int32_t **cache, int32_t *pLen, int32_t index, int32_t value) {
    int32_t *updated;
    int32_t new_len;
    if (!cache || !pLen || index < 0) return;
    if (index >= *pLen) {
        new_len = index + 1;
        if (*cache) {
            updated = HeapReAlloc(
                GetProcessHeap(),
                HEAP_ZERO_MEMORY,
                *cache,
                (SIZE_T)new_len * sizeof(int32_t));
        } else {
            updated = HeapAlloc(
                GetProcessHeap(),
                HEAP_ZERO_MEMORY,
                (SIZE_T)new_len * sizeof(int32_t));
        }
        if (!updated) return;
        *cache = updated;
        *pLen = new_len;
    }
    (*cache)[index] = value;
}

static VFGVariantSlot *vfg_find_variant_slot(
    VFGVariantSlot *head, DISPID dispid, int has_index, int32_t index)
{
    while (head) {
        if (head->dispid == dispid &&
            head->has_index == has_index &&
            (!has_index || head->index == index)) {
            return head;
        }
        head = head->next;
    }
    return NULL;
}

static void vfg_free_variant_slots(VFGVariantSlot *slot) {
    while (slot) {
        VFGVariantSlot *next = slot->next;
        VariantClear(&slot->value);
        HeapFree(GetProcessHeap(), 0, slot);
        slot = next;
    }
}

static void vfg_clear_stored_data_formats(VolvoxGridObject *obj) {
    VFGStoredDataFormat *slot;
    if (!obj) return;
    slot = obj->stored_data;
    while (slot) {
        VFGStoredDataFormat *next = slot->next;
        if (slot->bytes) HeapFree(GetProcessHeap(), 0, slot->bytes);
        HeapFree(GetProcessHeap(), 0, slot);
        slot = next;
    }
    obj->stored_data = NULL;
}

static VFGStoredDataFormat *vfg_find_stored_data_format(
    VolvoxGridObject *obj, CLIPFORMAT format)
{
    VFGStoredDataFormat *slot = obj ? obj->stored_data : NULL;
    while (slot) {
        if (slot->format == format) return slot;
        slot = slot->next;
    }
    return NULL;
}

static HRESULT vfg_store_data_format(
    VolvoxGridObject *obj, CLIPFORMAT format, const BYTE *bytes, SIZE_T len)
{
    VFGStoredDataFormat *slot;
    BYTE *copy = NULL;
    if (!obj || !format) return E_INVALIDARG;
    if (len > 0) {
        copy = (BYTE *)HeapAlloc(GetProcessHeap(), 0, len);
        if (!copy) return E_OUTOFMEMORY;
        if (bytes) memcpy(copy, bytes, len);
        else memset(copy, 0, len);
    }
    slot = vfg_find_stored_data_format(obj, format);
    if (!slot) {
        slot = (VFGStoredDataFormat *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*slot));
        if (!slot) {
            if (copy) HeapFree(GetProcessHeap(), 0, copy);
            return E_OUTOFMEMORY;
        }
        slot->format = format;
        slot->next = obj->stored_data;
        obj->stored_data = slot;
    }
    if (slot->bytes) HeapFree(GetProcessHeap(), 0, slot->bytes);
    slot->bytes = copy;
    slot->len = len;
    return S_OK;
}

int32_t volvox_grid_set_data_format_native(
    int64_t id,
    uint32_t cf,
    const uint8_t *bytes,
    int32_t len)
{
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(id);
    if (!obj || cf == 0 || len < 0) return E_INVALIDARG;
    return vfg_store_data_format(obj, (CLIPFORMAT)cf, bytes, (SIZE_T)len);
}

static HRESULT vfg_set_variant_slot(
    VFGVariantSlot **pHead, DISPID dispid, int has_index, int32_t index, VARIANT *value)
{
    VFGVariantSlot *slot;
    HRESULT hr;
    if (!pHead || !value) return E_POINTER;
    slot = vfg_find_variant_slot(*pHead, dispid, has_index, index);
    if (!slot) {
        slot = (VFGVariantSlot *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*slot));
        if (!slot) return E_OUTOFMEMORY;
        VariantInit(&slot->value);
        slot->dispid = dispid;
        slot->has_index = has_index;
        slot->index = index;
        slot->next = *pHead;
        *pHead = slot;
    }
    VariantClear(&slot->value);
    hr = VariantCopyInd(&slot->value, value);
    if (FAILED(hr)) {
        VariantInit(&slot->value);
    }
    return hr;
}

static HRESULT vfg_copy_variant_slot(
    VFGVariantSlot *head, DISPID dispid, int has_index, int32_t index, VARIANT *out)
{
    VFGVariantSlot *slot;
    if (!out) return E_POINTER;
    slot = vfg_find_variant_slot(head, dispid, has_index, index);
    if (!slot) return DISP_E_MEMBERNOTFOUND;
    VariantInit(out);
    return VariantCopy(out, &slot->value);
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

static HRESULT vfg_dispatch_get_with_arg(
    IDispatch *pDisp,
    LPCOLESTR name,
    VARIANT *pArg,
    VARIANT *pResult)
{
    DISPID dispid = 0;
    DISPPARAMS dp;
    EXCEPINFO ei;
    HRESULT hr = vfg_get_dispid(pDisp, name, &dispid);
    if (FAILED(hr)) return hr;
    if (!pResult) return E_POINTER;
    VariantInit(pResult);
    memset(&ei, 0, sizeof(ei));
    dp.rgvarg = pArg;
    dp.rgdispidNamedArgs = NULL;
    dp.cArgs = pArg ? 1 : 0;
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

static HRESULT vfg_bound_put_cell_value(
    VolvoxGridObject *obj,
    int32_t row,
    int32_t col,
    BSTR text)
{
    VARIANT vFields, vField, vValue;
    HRESULT hr;
    long saved_pos = -1;
    int32_t field_col;
    int32_t pos;

    if (!obj || !obj->recordset || row < VFG_BOUND_HEADER_ROWS) return S_FALSE;
    field_col = col - vfg_bound_physical_col_offset(obj);
    if (field_col < 0) return S_FALSE;
    pos = row - VFG_BOUND_HEADER_ROWS + 1;
    if (pos < 1) return S_FALSE;

    (void)vfg_recordset_get_absolute_position(obj->recordset, &saved_pos);
    hr = vfg_dispatch_put_i4(obj->recordset, L"AbsolutePosition", pos);
    if (FAILED(hr)) return hr;

    VariantInit(&vFields);
    hr = vfg_dispatch_get(obj->recordset, L"Fields", &vFields);
    if (FAILED(hr) || V_VT(&vFields) != VT_DISPATCH || !V_DISPATCH(&vFields)) {
        VariantClear(&vFields);
        if (saved_pos >= 1) {
            (void)vfg_dispatch_put_i4(obj->recordset, L"AbsolutePosition", (int32_t)saved_pos);
        }
        return FAILED(hr) ? hr : E_FAIL;
    }

    VariantInit(&vField);
    hr = vfg_dispatch_get_indexed(V_DISPATCH(&vFields), L"Item", field_col, &vField);
    if (SUCCEEDED(hr) && V_VT(&vField) == VT_DISPATCH && V_DISPATCH(&vField)) {
        VariantInit(&vValue);
        V_VT(&vValue) = VT_BSTR;
        V_BSTR(&vValue) = SysAllocStringLen(text ? text : L"", text ? SysStringLen(text) : 0);
        hr = V_BSTR(&vValue) || !text || SysStringLen(text) == 0
            ? vfg_dispatch_put(V_DISPATCH(&vField), L"Value", &vValue)
            : E_OUTOFMEMORY;
        VariantClear(&vValue);
        if (SUCCEEDED(hr)) hr = vfg_dispatch_call(obj->recordset, L"Update");
    }
    VariantClear(&vField);
    VariantClear(&vFields);
    if (saved_pos >= 1) {
        (void)vfg_dispatch_put_i4(obj->recordset, L"AbsolutePosition", (int32_t)saved_pos);
    }
    return hr;
}

static HRESULT vfg_bound_move_recordset_to_row(VolvoxGridObject *obj, int32_t row) {
    int32_t pos;
    if (!obj || !obj->recordset || row < VFG_BOUND_HEADER_ROWS) return S_FALSE;
    pos = row - VFG_BOUND_HEADER_ROWS + 1;
    if (pos < 1) return S_FALSE;
    return vfg_dispatch_put_i4(obj->recordset, L"AbsolutePosition", pos);
}

static HRESULT vfg_bound_fetch_window(VolvoxGridObject *obj, int32_t start_row, int32_t row_count) {
    VARIANT vFields, vEOF, vField, vValue;
    HRESULT hr;
    long fieldCount = 0;
    long saved_pos = -1;
    int32_t rows;
    int32_t end_row;
    int32_t dataColOffset;
    int64_t gid;

    if (!obj || !obj->recordset || !obj->bound_virtual_active) return S_OK;
    if (row_count <= 0) return S_OK;
    gid = obj->grid_id;
    rows = volvox_grid_get_rows(gid);
    if (rows <= VFG_BOUND_HEADER_ROWS) return S_OK;
    if (start_row < VFG_BOUND_HEADER_ROWS) start_row = VFG_BOUND_HEADER_ROWS;
    if (start_row >= rows) start_row = rows - 1;
    end_row = start_row + row_count;
    if (end_row < start_row) end_row = rows;
    if (end_row > rows) end_row = rows;
    if (obj->bound_record_count >= 0) {
        int32_t max_row = VFG_BOUND_HEADER_ROWS + obj->bound_record_count;
        if (end_row > max_row) end_row = max_row;
    }
    if (end_row <= start_row) return S_OK;
    if (obj->bound_window_start <= start_row && obj->bound_window_end >= end_row) {
        return S_OK;
    }

    hr = vfg_recordset_get_field_count(obj->recordset, &fieldCount);
    if (FAILED(hr)) return hr;
    if (fieldCount <= 0) return S_OK;
    dataColOffset = obj->bound_data_col_offset;
    (void)vfg_recordset_get_absolute_position(obj->recordset, &saved_pos);

    VariantInit(&vFields);
    hr = vfg_dispatch_get(obj->recordset, L"Fields", &vFields);
    if (FAILED(hr) || V_VT(&vFields) != VT_DISPATCH || !V_DISPATCH(&vFields)) {
        VariantClear(&vFields);
        return FAILED(hr) ? hr : E_FAIL;
    }

    volvox_grid_set_redraw(gid, 0);
    for (int32_t row = start_row; row < end_row; ++row) {
        int32_t pos = row - VFG_BOUND_HEADER_ROWS + 1;
        hr = vfg_dispatch_put_i4(obj->recordset, L"AbsolutePosition", pos);
        if (FAILED(hr)) break;

        VariantInit(&vEOF);
        hr = vfg_dispatch_get(obj->recordset, L"EOF", &vEOF);
        if (FAILED(hr)) {
            VariantClear(&vEOF);
            break;
        }
        if (vfg_variant_is_true(&vEOF)) {
            VariantClear(&vEOF);
            break;
        }
        VariantClear(&vEOF);

        for (int32_t clearCol = 0; clearCol < dataColOffset; ++clearCol) {
            volvox_grid_set_text_matrix(gid, row, clearCol, (const uint8_t *)"", 0);
        }
        for (long col = 0; col < fieldCount; ++col) {
            int32_t gridCol = dataColOffset + (int32_t)col;
            int32_t dataType = vfg_get_cached_col_data_type(obj, gridCol);
            VariantInit(&vField);
            hr = vfg_dispatch_get_indexed(V_DISPATCH(&vFields), L"Item", col, &vField);
            if (SUCCEEDED(hr) && V_VT(&vField) == VT_DISPATCH && V_DISPATCH(&vField)) {
                BSTR cell = NULL;
                VariantInit(&vValue);
                hr = vfg_dispatch_get(V_DISPATCH(&vField), L"Value", &vValue);
                if (SUCCEEDED(hr)) {
                    if (dataType == 3) {
                        int32_t checkedState = 0;
                        if (V_VT(&vValue) != VT_EMPTY && V_VT(&vValue) != VT_NULL) {
                            checkedState = vfg_variant_is_true(&vValue) ? 1 : 3;
                        }
                        volvox_grid_set_cell_checked(gid, row, gridCol, checkedState);
                        volvox_grid_set_text_matrix(gid, row, gridCol, (const uint8_t *)"", 0);
                    } else if (SUCCEEDED(vfg_variant_to_display_bstr(&vValue, &cell))) {
                        volvox_grid_set_cell_checked(gid, row, gridCol, 0);
                        vfg_set_text_matrix_bstr(gid, row, gridCol, cell);
                    }
                }
                if (cell) SysFreeString(cell);
                VariantClear(&vValue);
            }
            VariantClear(&vField);
            if (FAILED(hr)) break;
        }
        if (FAILED(hr)) break;
    }

    if (saved_pos >= 1) {
        (void)vfg_dispatch_put_i4(obj->recordset, L"AbsolutePosition", (int32_t)saved_pos);
    } else {
        (void)vfg_dispatch_put_i4(
            obj->recordset,
            L"AbsolutePosition",
            start_row - VFG_BOUND_HEADER_ROWS + 1);
    }
    VariantClear(&vFields);
    if (SUCCEEDED(hr)) {
        obj->bound_window_start = start_row;
        obj->bound_window_end = end_row;
        volvox_grid_refresh(gid);
    }
    volvox_grid_set_redraw(gid, 1);
    return hr;
}

static HRESULT vfg_bound_fetch_visible_window(VolvoxGridObject *obj) {
    int32_t out_len = 0;
    int32_t top;
    int32_t bottom;
    if (!obj || !obj->bound_virtual_active) return S_OK;
    top = volvox_grid_get_top_row(obj->grid_id);
    if (top < VFG_BOUND_HEADER_ROWS) top = VFG_BOUND_HEADER_ROWS;
    bottom = vfg_take_i32_response(
        volvox_grid_get_bottom_row(obj->grid_id, &out_len),
        out_len,
        top + 50);
    if (bottom < top) bottom = top;
    return vfg_bound_fetch_window(obj, top, bottom - top + 1);
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

    {
        int32_t ignore_len = 0;
        uint8_t *ignore = vfg_native_set_row(obj->grid_id, row, &ignore_len);
        if (ignore) volvox_grid_free(ignore, ignore_len);
        ignore = vfg_native_set_col(obj->grid_id, prop_col, &ignore_len);
        if (ignore) volvox_grid_free(ignore, ignore_len);
        ignore = vfg_native_set_row_sel(obj->grid_id, row_sel, &ignore_len);
        if (ignore) volvox_grid_free(ignore, ignore_len);
        ignore = vfg_native_set_col_sel(obj->grid_id, prop_col_sel, &ignore_len);
        if (ignore) volvox_grid_free(ignore, ignore_len);
        ignore = vfg_native_set_top_row(obj->grid_id, top_row, &ignore_len);
        if (ignore) volvox_grid_free(ignore, ignore_len);
        ignore = vfg_native_set_left_col(obj->grid_id, left_engine_col, &ignore_len);
        if (ignore) volvox_grid_free(ignore, ignore_len);
    }
    obj->row_sel_cached = row_sel;
    obj->col_sel_cached = prop_col_sel;
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
    target_prop_col = vfg_get_col_cached(obj->grid_id);
    if (target_prop_col < 0) target_prop_col = 0;

    {
        int32_t ignore_len = 0;
        uint8_t *ignore = vfg_native_set_row(obj->grid_id, target_row, &ignore_len);
        if (ignore) volvox_grid_free(ignore, ignore_len);
        ignore = vfg_native_set_col(obj->grid_id, target_prop_col, &ignore_len);
        if (ignore) volvox_grid_free(ignore, ignore_len);
        ignore = vfg_native_set_row_sel(obj->grid_id, target_row, &ignore_len);
        if (ignore) volvox_grid_free(ignore, ignore_len);
        ignore = vfg_native_set_col_sel(obj->grid_id, target_prop_col, &ignore_len);
        if (ignore) volvox_grid_free(ignore, ignore_len);
    }
    obj->row_sel_cached = target_row;
    obj->col_sel_cached = target_prop_col;
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

static int32_t vfg_variant_to_bool_i32(const VARIANT *pv) {
    VARIANT tmp;
    if (!pv) return 0;
    VariantInit(&tmp);
    if (SUCCEEDED(VariantChangeType(&tmp, (VARIANT *)pv, 0, VT_BOOL))) {
        int32_t value = V_BOOL(&tmp) != VARIANT_FALSE ? 1 : 0;
        VariantClear(&tmp);
        return value;
    }
    VariantClear(&tmp);
    return vfg_variant_is_true(pv) ? 1 : 0;
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

static HRESULT vfg_utf8_bytes_to_variant_bstr(VARIANT *pVarResult, uint8_t *utf8, int32_t out_len) {
    if (!pVarResult) return E_POINTER;
    V_VT(pVarResult) = VT_BSTR;
    if (utf8 && out_len > 0) {
        V_BSTR(pVarResult) = utf8_to_bstr((const char *)utf8, out_len);
        volvox_grid_free(utf8, out_len);
    } else {
        V_BSTR(pVarResult) = SysAllocString(L"");
        if (utf8) volvox_grid_free(utf8, out_len);
    }
    return V_BSTR(pVarResult) || (!utf8 || out_len == 0) ? S_OK : E_OUTOFMEMORY;
}

static HRESULT vfg_utf8_clip_to_variant_bstr(VARIANT *pVarResult, uint8_t *utf8, int32_t out_len) {
    BSTR bstr;
    if (!pVarResult) return E_POINTER;
    V_VT(pVarResult) = VT_BSTR;
    if (!utf8 || out_len <= 0) {
        V_BSTR(pVarResult) = SysAllocString(L"");
        if (utf8) volvox_grid_free(utf8, out_len);
        return V_BSTR(pVarResult) ? S_OK : E_OUTOFMEMORY;
    }
    {
        int wlen = MultiByteToWideChar(CP_UTF8, 0, (const char *)utf8, out_len, NULL, 0);
        bstr = SysAllocStringLen(NULL, wlen);
        if (!bstr) {
            volvox_grid_free(utf8, out_len);
            return E_OUTOFMEMORY;
        }
        MultiByteToWideChar(CP_UTF8, 0, (const char *)utf8, out_len, bstr, wlen);
        for (int i = 0; i < wlen; ++i) {
            if (bstr[i] == L'\n') bstr[i] = L'\r';
        }
    }
    volvox_grid_free(utf8, out_len);
    V_BSTR(pVarResult) = bstr;
    return S_OK;
}

static int32_t vfg_first_number_in_utf8(const uint8_t *utf8, int32_t len) {
    int32_t i = 0;
    while (i < len) {
        while (i < len && (utf8[i] < '0' || utf8[i] > '9')) i++;
        if (i >= len) return 0;
        if (i > 0 && utf8[i - 1] == '-') {
            while (i < len && utf8[i] >= '0' && utf8[i] <= '9') i++;
            continue;
        }
        int32_t value = 0;
        while (i < len && utf8[i] >= '0' && utf8[i] <= '9') {
            value = value * 10 + (int32_t)(utf8[i] - '0');
            i++;
        }
        return value;
    }
    return 0;
}

static HRESULT vfg_set_utf8_payload_status(
    uint8_t *(*fn)(int64_t, const uint8_t*, int32_t, int32_t*),
    int64_t gid,
    BSTR value)
{
    int32_t out_len = 0;
    int utf8len = 0;
    char *utf8 = bstr_to_utf8(value, &utf8len);
    uint8_t *out = fn(
        gid,
        (const uint8_t *)(utf8 ? utf8 : ""),
        utf8 ? utf8len : 0,
        &out_len);
    if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
    return vfg_take_status_response(out) == 0 ? S_OK : E_FAIL;
}

static HRESULT vfg_set_utf8_indexed_payload_status(
    uint8_t *(*fn)(int64_t, int32_t, const uint8_t*, int32_t, int32_t*),
    int64_t gid,
    int32_t index,
    BSTR value)
{
    int32_t out_len = 0;
    int utf8len = 0;
    char *utf8 = bstr_to_utf8(value, &utf8len);
    uint8_t *out = fn(
        gid,
        index,
        (const uint8_t *)(utf8 ? utf8 : ""),
        utf8 ? utf8len : 0,
        &out_len);
    if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
    return vfg_take_status_response(out) == 0 ? S_OK : E_FAIL;
}

static uint8_t *vfg_extract_bytes_field(
    const uint8_t *buf, int32_t len, uint32_t target_field, int32_t *out_len)
{
    int32_t pos = 0;
    if (out_len) *out_len = 0;
    if (!buf || len <= 0) return NULL;
    while (pos < len) {
        uint64_t key = 0;
        uint64_t size = 0;
        uint32_t field_no;
        uint32_t wire_type;
        uint8_t *copy;
        if (!vfg_read_varint(buf, len, &pos, &key)) return NULL;
        field_no = (uint32_t)(key >> 3);
        wire_type = (uint32_t)(key & 0x7);
        if (field_no == target_field && wire_type == 2) {
            if (!vfg_read_varint(buf, len, &pos, &size)) return NULL;
            if (size > (uint64_t)(len - pos)) return NULL;
            copy = (uint8_t *)HeapAlloc(GetProcessHeap(), 0, (SIZE_T)size);
            if (!copy) return NULL;
            memcpy(copy, buf + pos, (size_t)size);
            if (out_len) *out_len = (int32_t)size;
            return copy;
        }
        if (!vfg_skip_wire(buf, len, &pos, wire_type)) return NULL;
    }
    return NULL;
}

static HRESULT vfg_write_blob_to_path(BSTR path, const uint8_t *data, int32_t len) {
    FILE *fp;
    int utf8_len = 0;
    char *utf8_path;
    if (!path) return E_INVALIDARG;
    utf8_path = bstr_to_utf8(path, &utf8_len);
    if (!utf8_path) return E_OUTOFMEMORY;
    fp = fopen(utf8_path, "wb");
    HeapFree(GetProcessHeap(), 0, utf8_path);
    if (!fp) return E_FAIL;
    if (len > 0 && fwrite(data, 1, (size_t)len, fp) != (size_t)len) {
        fclose(fp);
        return E_FAIL;
    }
    fclose(fp);
    return S_OK;
}

static uint8_t *vfg_read_blob_from_path(BSTR path, int32_t *out_len) {
    FILE *fp;
    long size = 0;
    uint8_t *data = NULL;
    int utf8_len = 0;
    char *utf8_path;
    if (out_len) *out_len = 0;
    if (!path) return NULL;
    utf8_path = bstr_to_utf8(path, &utf8_len);
    if (!utf8_path) return NULL;
    fp = fopen(utf8_path, "rb");
    HeapFree(GetProcessHeap(), 0, utf8_path);
    if (!fp) return NULL;
    if (fseek(fp, 0, SEEK_END) != 0) {
        fclose(fp);
        return NULL;
    }
    size = ftell(fp);
    if (size < 0) {
        fclose(fp);
        return NULL;
    }
    if (fseek(fp, 0, SEEK_SET) != 0) {
        fclose(fp);
        return NULL;
    }
    data = size > 0 ? (uint8_t *)HeapAlloc(GetProcessHeap(), 0, (SIZE_T)size) : NULL;
    if (size > 0 && !data) {
        fclose(fp);
        return NULL;
    }
    if (size > 0 && fread(data, 1, (size_t)size, fp) != (size_t)size) {
        fclose(fp);
        HeapFree(GetProcessHeap(), 0, data);
        return NULL;
    }
    fclose(fp);
    if (out_len) *out_len = (int32_t)size;
    return data;
}

static int vfg_picture_bytes_are_png(const uint8_t *data, int32_t len) {
    static const uint8_t png_sig[8] = { 0x89, 'P', 'N', 'G', '\r', '\n', 0x1a, '\n' };
    return data && len >= (int32_t)sizeof(png_sig) && memcmp(data, png_sig, sizeof(png_sig)) == 0;
}

static HRESULT vfg_copy_bytes_heap(
    const uint8_t *src,
    int32_t len,
    uint8_t **out_data,
    int32_t *out_len)
{
    uint8_t *copy = NULL;
    if (!out_data || !out_len) return E_POINTER;
    *out_data = NULL;
    *out_len = 0;
    if (!src || len <= 0) return S_OK;
    copy = (uint8_t *)HeapAlloc(GetProcessHeap(), 0, (SIZE_T)len);
    if (!copy) return E_OUTOFMEMORY;
    memcpy(copy, src, (size_t)len);
    *out_data = copy;
    *out_len = len;
    return S_OK;
}

static int vfg_wide_starts_with_ci(const WCHAR *value, const WCHAR *prefix) {
    size_t i = 0;
    if (!value || !prefix) return 0;
    while (prefix[i]) {
        if (!value[i] || towlower((wint_t)value[i]) != towlower((wint_t)prefix[i])) {
            return 0;
        }
        i++;
    }
    return 1;
}

static int vfg_picture_source_looks_like_url(BSTR source) {
    if (!source || SysStringLen(source) == 0) return 0;
    return vfg_wide_starts_with_ci(source, L"http://")
        || vfg_wide_starts_with_ci(source, L"https://")
        || vfg_wide_starts_with_ci(source, L"ftp://")
        || vfg_wide_starts_with_ci(source, L"file://");
}

static HRESULT vfg_gdip_find_encoder_clsid(const WCHAR *mime_type, CLSID *out_clsid) {
    ImageCodecInfo *encoders = NULL;
    UINT count = 0;
    UINT size = 0;
    UINT i;
    GpStatus status;
    HRESULT hr = E_FAIL;
    if (!mime_type || !out_clsid) return E_POINTER;
    status = GdipGetImageEncodersSize(&count, &size);
    if (status != Ok || count == 0 || size == 0) return E_FAIL;
    encoders = (ImageCodecInfo *)HeapAlloc(GetProcessHeap(), 0, (SIZE_T)size);
    if (!encoders) return E_OUTOFMEMORY;
    status = GdipGetImageEncoders(count, size, encoders);
    if (status == Ok) {
        for (i = 0; i < count; i++) {
            if (encoders[i].MimeType && lstrcmpiW(encoders[i].MimeType, mime_type) == 0) {
                *out_clsid = encoders[i].Clsid;
                hr = S_OK;
                break;
            }
        }
    }
    HeapFree(GetProcessHeap(), 0, encoders);
    return hr;
}

static HRESULT vfg_copy_hglobal_stream_bytes(IStream *stream, uint8_t **out_data, int32_t *out_len) {
    STATSTG stat;
    HGLOBAL hglobal = NULL;
    const void *src = NULL;
    ULONG size = 0;
    uint8_t *copy = NULL;
    HRESULT hr;
    if (!stream || !out_data || !out_len) return E_POINTER;
    *out_data = NULL;
    *out_len = 0;
    memset(&stat, 0, sizeof(stat));
    hr = IStream_Stat(stream, &stat, STATFLAG_NONAME);
    if (FAILED(hr)) return hr;
    if (stat.cbSize.HighPart != 0 || stat.cbSize.LowPart > 0x7fffffffUL) return E_FAIL;
    size = stat.cbSize.LowPart;
    if (size == 0) return S_OK;
    hr = GetHGlobalFromStream(stream, &hglobal);
    if (FAILED(hr) || !hglobal) return E_FAIL;
    src = GlobalLock(hglobal);
    if (!src) return E_FAIL;
    copy = (uint8_t *)HeapAlloc(GetProcessHeap(), 0, (SIZE_T)size);
    if (!copy) {
        GlobalUnlock(hglobal);
        return E_OUTOFMEMORY;
    }
    memcpy(copy, src, size);
    GlobalUnlock(hglobal);
    *out_data = copy;
    *out_len = (int32_t)size;
    return S_OK;
}

static HRESULT vfg_gdip_load_image_from_stream(IStream *stream, GpImage **out_image) {
    GpImage *image = NULL;
    GpStatus status;
    if (!stream || !out_image) return E_POINTER;
    *out_image = NULL;
    status = GdipLoadImageFromStream(stream, &image);
    if (status != Ok || !image) return E_FAIL;
    status = GdipImageForceValidation(image);
    if (status != Ok) {
        GdipDisposeImage(image);
        return E_FAIL;
    }
    *out_image = image;
    return S_OK;
}

static HRESULT vfg_gdip_load_image_from_bytes(const uint8_t *data, int32_t len, GpImage **out_image) {
    HGLOBAL hglobal = NULL;
    void *dst = NULL;
    IStream *stream = NULL;
    HRESULT hr;
    if (!out_image) return E_POINTER;
    *out_image = NULL;
    if (!data || len <= 0) return E_INVALIDARG;
    hglobal = GlobalAlloc(GMEM_MOVEABLE, (SIZE_T)len);
    if (!hglobal) return E_OUTOFMEMORY;
    dst = GlobalLock(hglobal);
    if (!dst) {
        GlobalFree(hglobal);
        return E_FAIL;
    }
    memcpy(dst, data, (size_t)len);
    GlobalUnlock(hglobal);
    hr = CreateStreamOnHGlobal(hglobal, TRUE, &stream);
    if (FAILED(hr) || !stream) {
        GlobalFree(hglobal);
        return FAILED(hr) ? hr : E_FAIL;
    }
    hr = vfg_gdip_load_image_from_stream(stream, out_image);
    IStream_Release(stream);
    return hr;
}

static HRESULT vfg_gdip_load_image_from_source(BSTR source, GpImage **out_image) {
    GpImage *image = NULL;
    GpStatus status;
    HRESULT hr;
    IStream *stream = NULL;
    if (!source || !out_image) return E_POINTER;
    *out_image = NULL;
    if (SysStringLen(source) == 0) return S_OK;
    if (vfg_picture_source_looks_like_url(source)) {
        hr = URLOpenBlockingStreamW(NULL, source, &stream, 0, NULL);
        if (FAILED(hr) || !stream) return FAILED(hr) ? hr : E_FAIL;
        hr = vfg_gdip_load_image_from_stream(stream, &image);
        IStream_Release(stream);
        if (FAILED(hr)) return hr;
    } else {
        status = GdipLoadImageFromFile(source, &image);
        if (status != Ok || !image) return E_FAIL;
        status = GdipImageForceValidation(image);
        if (status != Ok) {
            GdipDisposeImage(image);
            return E_FAIL;
        }
    }
    *out_image = image;
    return S_OK;
}

static HRESULT vfg_gdip_encode_image_as_png(GpImage *image, uint8_t **out_data, int32_t *out_len) {
    CLSID png_encoder;
    IStream *stream = NULL;
    HRESULT hr;
    GpStatus status;
    if (!image || !out_data || !out_len) return E_POINTER;
    *out_data = NULL;
    *out_len = 0;
    hr = vfg_gdip_find_encoder_clsid(L"image/png", &png_encoder);
    if (FAILED(hr)) return hr;
    hr = CreateStreamOnHGlobal(NULL, TRUE, &stream);
    if (FAILED(hr) || !stream) return FAILED(hr) ? hr : E_FAIL;
    status = GdipSaveImageToStream(image, stream, &png_encoder, NULL);
    if (status != Ok) {
        IStream_Release(stream);
        return E_FAIL;
    }
    hr = vfg_copy_hglobal_stream_bytes(stream, out_data, out_len);
    IStream_Release(stream);
    return hr;
}

static HRESULT vfg_normalize_picture_source_to_png(BSTR source, uint8_t **out_data, int32_t *out_len) {
    GdiplusStartupInput startup_input;
    ULONG_PTR gdip_token = 0;
    GpImage *image = NULL;
    GpStatus status;
    HRESULT hr;
    if (!out_data || !out_len) return E_POINTER;
    *out_data = NULL;
    *out_len = 0;
    if (!source || SysStringLen(source) == 0) return S_OK;
    memset(&startup_input, 0, sizeof(startup_input));
    startup_input.GdiplusVersion = 1;
    status = GdiplusStartup(&gdip_token, &startup_input, NULL);
    if (status != Ok) return E_FAIL;
    hr = vfg_gdip_load_image_from_source(source, &image);
    if (SUCCEEDED(hr) && image) {
        hr = vfg_gdip_encode_image_as_png(image, out_data, out_len);
        GdipDisposeImage(image);
    }
    GdiplusShutdown(gdip_token);
    return hr;
}

static HRESULT vfg_normalize_picture_bytes_to_png(
    const uint8_t *data,
    int32_t len,
    uint8_t **out_data,
    int32_t *out_len)
{
    GdiplusStartupInput startup_input;
    ULONG_PTR gdip_token = 0;
    GpImage *image = NULL;
    GpStatus status;
    HRESULT hr;
    if (!out_data || !out_len) return E_POINTER;
    *out_data = NULL;
    *out_len = 0;
    if (!data || len <= 0) return S_OK;
    if (vfg_picture_bytes_are_png(data, len)) {
        return vfg_copy_bytes_heap(data, len, out_data, out_len);
    }
    memset(&startup_input, 0, sizeof(startup_input));
    startup_input.GdiplusVersion = 1;
    status = GdiplusStartup(&gdip_token, &startup_input, NULL);
    if (status != Ok) return E_FAIL;
    hr = vfg_gdip_load_image_from_bytes(data, len, &image);
    if (SUCCEEDED(hr) && image) {
        hr = vfg_gdip_encode_image_as_png(image, out_data, out_len);
        GdipDisposeImage(image);
    }
    GdiplusShutdown(gdip_token);
    return hr;
}

static HRESULT vfg_copy_variant_ui1_array(
    const VARIANT *value,
    uint8_t **out_data,
    int32_t *out_len)
{
    SAFEARRAY *array;
    LONG lower = 0;
    LONG upper = -1;
    LONG count = 0;
    void *src = NULL;
    HRESULT hr;
    if (!out_data || !out_len) return E_POINTER;
    *out_data = NULL;
    *out_len = 0;
    if (!value || V_VT(value) != (VT_ARRAY | VT_UI1) || !V_ARRAY(value)) {
        return DISP_E_TYPEMISMATCH;
    }
    array = V_ARRAY(value);
    if (SafeArrayGetDim(array) != 1) return DISP_E_TYPEMISMATCH;
    hr = SafeArrayGetLBound(array, 1, &lower);
    if (FAILED(hr)) return hr;
    hr = SafeArrayGetUBound(array, 1, &upper);
    if (FAILED(hr)) return hr;
    count = upper - lower + 1;
    if (count <= 0) return S_OK;
    hr = SafeArrayAccessData(array, &src);
    if (FAILED(hr)) return hr;
    hr = vfg_copy_bytes_heap((const uint8_t *)src, (int32_t)count, out_data, out_len);
    SafeArrayUnaccessData(array);
    return hr;
}

static HRESULT vfg_variant_from_ui1_bytes(VARIANT *out, const uint8_t *data, int32_t len) {
    SAFEARRAYBOUND bound;
    SAFEARRAY *array = NULL;
    void *dst = NULL;
    HRESULT hr;
    if (!out) return E_POINTER;
    VariantInit(out);
    if (!data || len <= 0) return S_OK;
    bound.lLbound = 0;
    bound.cElements = (ULONG)len;
    array = SafeArrayCreate(VT_UI1, 1, &bound);
    if (!array) return E_OUTOFMEMORY;
    hr = SafeArrayAccessData(array, &dst);
    if (FAILED(hr)) {
        SafeArrayDestroy(array);
        return hr;
    }
    memcpy(dst, data, (size_t)len);
    SafeArrayUnaccessData(array);
    V_VT(out) = VT_ARRAY | VT_UI1;
    V_ARRAY(out) = array;
    return S_OK;
}

static HRESULT vfg_variant_to_png_picture_bytes(
    VARIANT *value,
    uint8_t **out_data,
    int32_t *out_len)
{
    HRESULT hr;
    uint8_t *raw = NULL;
    int32_t raw_len = 0;
    VARIANT vtmp;
    BSTR source = NULL;
    if (!out_data || !out_len) return E_POINTER;
    *out_data = NULL;
    *out_len = 0;
    if (!value || V_VT(value) == VT_EMPTY || V_VT(value) == VT_NULL) return S_OK;
    if (V_VT(value) == (VT_ARRAY | VT_UI1)) {
        hr = vfg_copy_variant_ui1_array(value, &raw, &raw_len);
        if (FAILED(hr)) return hr;
        hr = vfg_normalize_picture_bytes_to_png(raw, raw_len, out_data, out_len);
        if (raw) HeapFree(GetProcessHeap(), 0, raw);
        return hr;
    }
    VariantInit(&vtmp);
    source = variant_to_bstr(value, &vtmp);
    hr = source ? vfg_normalize_picture_source_to_png(source, out_data, out_len) : DISP_E_TYPEMISMATCH;
    VariantClear(&vtmp);
    return hr;
}

static HRESULT vfg_set_cell_picture_range_compat(
    int64_t gid,
    int32_t row1,
    int32_t col1,
    int32_t row2,
    int32_t col2,
    const uint8_t *picture,
    int32_t picture_len)
{
    int32_t out_len = 0;
    uint8_t *resp = volvox_grid_set_cell_picture_range_native(
        gid,
        row1,
        col1,
        row2,
        col2,
        picture,
        picture_len,
        &out_len);
    return vfg_take_status_response(resp) == 0 ? S_OK : E_FAIL;
}

static HRESULT vfg_set_cell_picture_alignment_range_compat(
    int64_t gid,
    int32_t row1,
    int32_t col1,
    int32_t row2,
    int32_t col2,
    int32_t alignment)
{
    int32_t out_len = 0;
    uint8_t *resp = volvox_grid_set_cell_picture_alignment_range_native(
        gid,
        row1,
        col1,
        row2,
        col2,
        alignment,
        &out_len);
    return vfg_take_status_response(resp) == 0 ? S_OK : E_FAIL;
}

static HRESULT vfg_set_cell_button_picture_range_compat(
    int64_t gid,
    int32_t row1,
    int32_t col1,
    int32_t row2,
    int32_t col2,
    const uint8_t *picture,
    int32_t picture_len)
{
    int32_t out_len = 0;
    uint8_t *resp = volvox_grid_set_cell_button_picture_range_native(
        gid,
        row1,
        col1,
        row2,
        col2,
        picture,
        picture_len,
        &out_len);
    return vfg_take_status_response(resp) == 0 ? S_OK : E_FAIL;
}

static HRESULT vfg_set_native_picture_compat(
    uint8_t *(*set_fn)(int64_t, const uint8_t*, int32_t, int32_t*),
    int64_t gid,
    const uint8_t *picture,
    int32_t picture_len)
{
    int32_t out_len = 0;
    uint8_t *resp;
    if (!set_fn) return E_POINTER;
    resp = set_fn(gid, picture, picture_len, &out_len);
    return vfg_take_status_response(resp) == 0 ? S_OK : E_FAIL;
}

static BSTR *vfg_split_field_list(BSTR list, int32_t *pCount) {
    BSTR *items = NULL;
    int32_t count = 0;
    const WCHAR *src;
    const WCHAR *start;
    const WCHAR *end;
    if (pCount) *pCount = 0;
    if (!list) return NULL;
    src = list;
    while (*src) {
        while (*src == L' ' || *src == L'\t' || *src == L',') src++;
        if (!*src) break;
        start = src;
        while (*src && *src != L',') src++;
        end = src;
        while (end > start && (end[-1] == L' ' || end[-1] == L'\t')) end--;
        if (end > start) {
            BSTR *updated = items
                ? HeapReAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, items, (SIZE_T)(count + 1) * sizeof(BSTR))
                : HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(BSTR));
            if (!updated) {
                vfg_free_bstr_cache(items, count);
                return NULL;
            }
            items = updated;
            items[count] = SysAllocStringLen(start, (UINT)(end - start));
            if (!items[count]) {
                vfg_free_bstr_cache(items, count);
                return NULL;
            }
            count++;
        }
    }
    if (pCount) *pCount = count;
    return items;
}

static HRESULT vfg_recordset_get_field_value_by_name(
    IDispatch *pRS,
    BSTR fieldName,
    BSTR *pValue)
{
    VARIANT vFields;
    VARIANT vArg;
    VARIANT vField;
    VARIANT vValue;
    HRESULT hr;
    if (!pValue) return E_POINTER;
    *pValue = NULL;
    if (!pRS || !fieldName) return E_POINTER;

    VariantInit(&vFields);
    hr = vfg_dispatch_get(pRS, L"Fields", &vFields);
    if (FAILED(hr) || V_VT(&vFields) != VT_DISPATCH || !V_DISPATCH(&vFields)) {
        VariantClear(&vFields);
        return FAILED(hr) ? hr : E_FAIL;
    }

    VariantInit(&vArg);
    V_VT(&vArg) = VT_BSTR;
    V_BSTR(&vArg) = fieldName;
    VariantInit(&vField);
    hr = vfg_dispatch_get_with_arg(V_DISPATCH(&vFields), L"Item", &vArg, &vField);
    if (FAILED(hr) || V_VT(&vField) != VT_DISPATCH || !V_DISPATCH(&vField)) {
        VariantClear(&vField);
        VariantClear(&vFields);
        return FAILED(hr) ? hr : E_FAIL;
    }

    VariantInit(&vValue);
    hr = vfg_dispatch_get(V_DISPATCH(&vField), L"Value", &vValue);
    if (SUCCEEDED(hr)) hr = vfg_variant_to_display_bstr(&vValue, pValue);
    VariantClear(&vValue);
    VariantClear(&vField);
    VariantClear(&vFields);
    return hr;
}

static HRESULT vfg_build_combo_list_from_recordset(
    IDispatch *pRS,
    BSTR fieldList,
    BSTR keyField,
    BSTR *pResult)
{
    BSTR *fields = NULL;
    int32_t fieldCount = 0;
    long savedPos = -1;
    char *buf = NULL;
    int len = 0;
    int cap = 0;
    HRESULT hr = S_OK;
    VARIANT vEOF;
    if (!pResult) return E_POINTER;
    *pResult = SysAllocString(L"");
    if (!*pResult) return E_OUTOFMEMORY;
    if (!pRS) return S_OK;

    fields = vfg_split_field_list(fieldList, &fieldCount);
    if (!fields && fieldList && SysStringLen(fieldList) > 0) return E_OUTOFMEMORY;
    if (fieldCount <= 0 && keyField && SysStringLen(keyField) > 0) {
        fields = (BSTR *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(BSTR));
        if (!fields) return E_OUTOFMEMORY;
        fields[0] = SysAllocStringLen(keyField, SysStringLen(keyField));
        if (!fields[0]) {
            HeapFree(GetProcessHeap(), 0, fields);
            return E_OUTOFMEMORY;
        }
        fieldCount = 1;
    }

    (void)vfg_recordset_get_absolute_position(pRS, &savedPos);
    (void)vfg_dispatch_call(pRS, L"MoveFirst");

    while (1) {
        VariantInit(&vEOF);
        hr = vfg_dispatch_get(pRS, L"EOF", &vEOF);
        if (FAILED(hr) || vfg_variant_is_true(&vEOF)) {
            VariantClear(&vEOF);
            break;
        }
        VariantClear(&vEOF);

        if (len > 0 && !utf8_append_bytes(&buf, &len, &cap, "|", 1)) {
            hr = E_OUTOFMEMORY;
            break;
        }

        if (keyField && SysStringLen(keyField) > 0) {
            BSTR keyValue = NULL;
            int keyUtf8Len = 0;
            char *keyUtf8;
            hr = vfg_recordset_get_field_value_by_name(pRS, keyField, &keyValue);
            if (FAILED(hr)) break;
            keyUtf8 = bstr_to_utf8(keyValue, &keyUtf8Len);
            if (!utf8_append_bytes(&buf, &len, &cap, "#", 1) ||
                (keyUtf8Len > 0 && keyUtf8 && !utf8_append_bytes(&buf, &len, &cap, keyUtf8, keyUtf8Len)) ||
                !utf8_append_bytes(&buf, &len, &cap, ";", 1)) {
                if (keyUtf8) HeapFree(GetProcessHeap(), 0, keyUtf8);
                if (keyValue) SysFreeString(keyValue);
                hr = E_OUTOFMEMORY;
                break;
            }
            if (keyUtf8) HeapFree(GetProcessHeap(), 0, keyUtf8);
            if (keyValue) SysFreeString(keyValue);
        }

        for (int32_t i = 0; i < fieldCount; ++i) {
            BSTR value = NULL;
            int valueUtf8Len = 0;
            char *valueUtf8;
            hr = vfg_recordset_get_field_value_by_name(pRS, fields[i], &value);
            if (FAILED(hr)) break;
            valueUtf8 = bstr_to_utf8(value, &valueUtf8Len);
            if ((i > 0 && !utf8_append_bytes(&buf, &len, &cap, "\t", 1)) ||
                (valueUtf8Len > 0 && valueUtf8 && !utf8_append_bytes(&buf, &len, &cap, valueUtf8, valueUtf8Len))) {
                if (valueUtf8) HeapFree(GetProcessHeap(), 0, valueUtf8);
                if (value) SysFreeString(value);
                hr = E_OUTOFMEMORY;
                break;
            }
            if (valueUtf8) HeapFree(GetProcessHeap(), 0, valueUtf8);
            if (value) SysFreeString(value);
        }
        if (FAILED(hr)) break;
        hr = vfg_dispatch_call(pRS, L"MoveNext");
        if (FAILED(hr)) break;
    }

    if (savedPos >= 1) {
        (void)vfg_dispatch_put_i4(pRS, L"AbsolutePosition", (int32_t)savedPos);
    }
    if (fields) vfg_free_bstr_cache(fields, fieldCount);
    if (SUCCEEDED(hr)) {
        SysFreeString(*pResult);
        *pResult = utf8_to_bstr(buf ? buf : "", len);
        hr = *pResult ? S_OK : E_OUTOFMEMORY;
    }
    if (buf) HeapFree(GetProcessHeap(), 0, buf);
    return hr;
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
        if (obj->col_key_cache) {
            for (int32_t col = 0; col < obj->col_key_cache_len; ++col) {
                if (obj->col_key_cache[col] &&
                    _wcsicmp(obj->col_key_cache[col], key) == 0) {
                    *pIndex = col;
                    return S_OK;
                }
            }
        }
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
    obj->bound_virtual_active = 0;
    obj->bound_record_count = -1;
    obj->bound_window_start = 0;
    obj->bound_window_end = 0;
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
    int32_t priorRows = 0;
    int32_t priorDataColOffset = 0;
    int32_t preserve_visible_state = 0;
    int32_t saved_row = 0;
    int32_t saved_col = 0;
    int32_t saved_row_sel = 0;
    int32_t saved_col_sel = 0;
    int32_t saved_top_row = 0;
    int32_t saved_left_col = 0;
    long saved_record_pos = -1;
    int32_t use_virtual_bind = 0;
    int32_t *preservedWidths = NULL;
    int32_t *preservedRowHeights = NULL;
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
        obj->bound_virtual_active = 0;
        obj->bound_record_count = -1;
        obj->bound_window_start = 0;
        obj->bound_window_end = 0;
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

    priorRows = volvox_grid_get_rows(gid);
    priorCols = volvox_grid_get_cols(gid);
    if (priorRows > VFG_BOUND_HEADER_ROWS) {
        preservedRowHeights = vfg_capture_row_heights(gid, priorRows);
    }

    if (obj->has_bound_layout) {
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

    VariantInit(&vCount);
    hr = vfg_dispatch_get(pRS, L"RecordCount", &vCount);
    if (SUCCEEDED(hr)) {
        if (V_VT(&vCount) == VT_I4) recordCount = V_I4(&vCount);
        else if (V_VT(&vCount) == VT_I2) recordCount = V_I2(&vCount);
        else variant_to_i4(&vCount, (int32_t *)&recordCount);
    }
    VariantClear(&vCount);
    use_virtual_bind = obj->virtual_data || obj->data_mode == 2 ||
        recordCount > VFG_BOUND_VIRTUAL_RECORD_THRESHOLD;
    if (recordCount > 0) {
        int32_t targetRows = recordCount > 2147483646L
            ? 2147483647
            : (int32_t)recordCount + VFG_BOUND_HEADER_ROWS;
        volvox_grid_set_rows(gid, targetRows);
    } else if (use_virtual_bind && recordCount < 0) {
        volvox_grid_set_rows(gid, VFG_BOUND_HEADER_ROWS + 50);
    }

    if (!use_virtual_bind) {
        (void)vfg_dispatch_call(pRS, L"MoveFirst");
    }

    if (preservedRowHeights) {
        int32_t currentRows = volvox_grid_get_rows(gid);
        int32_t last = priorRows < currentRows ? priorRows : currentRows;
        for (int32_t restoreRow = VFG_BOUND_HEADER_ROWS; restoreRow < last; ++restoreRow) {
            int32_t ignore_len = 0;
            uint8_t *ignore = vfg_native_set_row_height(
                gid,
                restoreRow,
                preservedRowHeights[restoreRow],
                &ignore_len);
            if (ignore) volvox_grid_free(ignore, ignore_len);
        }
    }

    while (!use_virtual_bind) {
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

    if (!use_virtual_bind && recordCount > 0 && row != recordCount + VFG_BOUND_HEADER_ROWS) {
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
    if (((!preservedWidths) ||
         (obj->data_mode == 0 && vfg_engine_auto_resize_enabled(gid, obj->auto_resize))) &&
        totalCols > dataColOffset) {
        volvox_grid_auto_size(gid, dataColOffset, totalCols - 1, 0, 0);
        vfg_apply_bound_autosize_compat_widths(gid, dataColOffset, 0, totalCols - 1);
    }

    if (preservedWidths) {
        HeapFree(GetProcessHeap(), 0, preservedWidths);
        preservedWidths = NULL;
    }
    if (preservedRowHeights) {
        HeapFree(GetProcessHeap(), 0, preservedRowHeights);
        preservedRowHeights = NULL;
    }
    obj->has_bound_layout = 1;
    obj->bound_fixed_cols = fixedCols;
    obj->bound_data_col_offset = dataColOffset;
    obj->bound_virtual_active = use_virtual_bind ? 1 : 0;
    obj->bound_record_count = recordCount > 0 ? (int32_t)recordCount : -1;
    obj->bound_window_start = 0;
    obj->bound_window_end = 0;
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
    if (use_virtual_bind) {
        hr = vfg_bound_fetch_visible_window(obj);
        if (FAILED(hr)) {
            volvox_grid_set_redraw(gid, 1);
            VariantClear(&vFields);
            return hr;
        }
    }
    if (obj->data_mode != 0 && !use_virtual_bind) {
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
        obj->bound_virtual_active = 0;
        obj->bound_record_count = -1;
        obj->bound_window_start = 0;
        obj->bound_window_end = 0;
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
    if (FAILED(hr)) {
        vfg_release_dispatch(&obj->recordset);
        obj->has_bound_layout = 0;
        obj->bound_fixed_cols = 0;
        obj->bound_data_col_offset = 0;
        obj->bound_col_width_uses_data_offset = 0;
        obj->bound_virtual_active = 0;
        obj->bound_record_count = -1;
        obj->bound_window_start = 0;
        obj->bound_window_end = 0;
        obj->suppress_bound_cursor_sync = 0;
        obj->suppress_bound_text_writes = 0;
        vfg_sync_selection_cache_from_cursor(obj);
    }
    return hr;
}

int32_t volvox_grid_ado_attach_native(int64_t id, void *dispatch) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(id);
    IDispatch *source = (IDispatch *)dispatch;
    HRESULT hr;
    if (!obj) return E_INVALIDARG;
    if (source) {
        hr = vfg_require_datasource_iface(source);
        if (FAILED(hr)) return hr;
        IDispatch_AddRef(source);
    }
    vfg_release_dispatch(&obj->data_source);
    obj->data_source = source;
    return vfg_rebind_ado_source(obj);
}

int32_t volvox_grid_ado_detach_native(int64_t id) {
    return volvox_grid_ado_attach_native(id, NULL);
}

int32_t volvox_grid_ado_pump_row_native(int64_t id, int32_t row) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(id);
    if (!obj) return E_INVALIDARG;
    return vfg_bound_fetch_window(obj, row, 1);
}

int32_t volvox_grid_ado_fetch_window_native(int64_t id, int32_t start, int32_t count) {
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(id);
    if (!obj) return E_INVALIDARG;
    return vfg_bound_fetch_window(obj, start, count);
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
    HRESULT hr = S_OK;

    if (obj && gid >= 0) {
        vfg_pump_engine_events(obj);
    }
    if (obj && (wFlags & (DISPATCH_METHOD | DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF))) {
        obj->dirty = 1;
    }

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

    case DISPID_VG_COLDATA_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t col = 0;
            int32_t out_len = 0;
            uint8_t *utf8;
            if (!pVarResult) return E_POINTER;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &col);
            utf8 = volvox_grid_get_col_data(gid, col, &out_len);
            if ((!utf8 || out_len <= 0) &&
                obj->col_data_cache && col >= 0 && col < obj->col_data_cache_len &&
                obj->col_data_cache[col]) {
                V_VT(pVarResult) = VT_BSTR;
                V_BSTR(pVarResult) = SysAllocStringLen(
                    obj->col_data_cache[col],
                    SysStringLen(obj->col_data_cache[col]));
                return V_BSTR(pVarResult) ? S_OK : E_OUTOFMEMORY;
            }
            return vfg_utf8_bytes_to_variant_bstr(pVarResult, utf8, out_len);
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t col = 0;
            VARIANT vtmp;
            BSTR value = NULL;
            VariantInit(&vtmp);
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(ARG(0), &col);
                value = variant_to_bstr(ARG(1), &vtmp);
            }
            vfg_set_cached_indexed_bstr(&obj->col_data_cache, &obj->col_data_cache_len, col, value);
            hr = vfg_set_utf8_indexed_payload_status(volvox_grid_set_col_data, gid, col, value);
            VariantClear(&vtmp);
            return hr;
        }
        break;

    case DISPID_VG_COLKEY_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t col = 0;
            if (!pVarResult) return E_POINTER;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &col);
            V_VT(pVarResult) = VT_BSTR;
            V_BSTR(pVarResult) = vfg_copy_cached_indexed_bstr(obj->col_key_cache, obj->col_key_cache_len, col);
            if (V_BSTR(pVarResult)) return S_OK;
            if (obj->recordset) {
                VARIANT vFields, vField, vName;
                int32_t fieldCol = col - vfg_bound_physical_col_offset(obj);
                VariantInit(&vFields);
                hr = vfg_dispatch_get(obj->recordset, L"Fields", &vFields);
                if (SUCCEEDED(hr) && V_VT(&vFields) == VT_DISPATCH && V_DISPATCH(&vFields) &&
                    fieldCol >= 0) {
                    VariantInit(&vField);
                    hr = vfg_dispatch_get_indexed(V_DISPATCH(&vFields), L"Item", fieldCol, &vField);
                    if (SUCCEEDED(hr) && V_VT(&vField) == VT_DISPATCH && V_DISPATCH(&vField)) {
                        VariantInit(&vName);
                        hr = vfg_dispatch_get(V_DISPATCH(&vField), L"Name", &vName);
                        if (SUCCEEDED(hr) && V_VT(&vName) == VT_BSTR && V_BSTR(&vName)) {
                            V_BSTR(pVarResult) = SysAllocStringLen(V_BSTR(&vName), SysStringLen(V_BSTR(&vName)));
                        }
                        VariantClear(&vName);
                    }
                    VariantClear(&vField);
                }
                VariantClear(&vFields);
            }
            if (!V_BSTR(pVarResult)) {
                V_BSTR(pVarResult) = SysAllocString(L"");
            }
            return V_BSTR(pVarResult) ? S_OK : E_OUTOFMEMORY;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t col = 0;
            VARIANT vtmp;
            BSTR value = NULL;
            VariantInit(&vtmp);
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(ARG(0), &col);
                value = variant_to_bstr(ARG(1), &vtmp);
            }
            vfg_set_cached_indexed_bstr(&obj->col_key_cache, &obj->col_key_cache_len, col, value);
            hr = vfg_set_utf8_indexed_payload_status(volvox_grid_set_col_key, gid, col, value);
            VariantClear(&vtmp);
            return hr;
        }
        break;

    case DISPID_VG_COLFORMAT_COMPAT:
    case DISPID_VG_COLEDITMASK_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t col = 0;
            BSTR *cache = dispIdMember == DISPID_VG_COLFORMAT_COMPAT
                ? obj->col_format_cache
                : obj->col_edit_mask_cache;
            int32_t cache_len = dispIdMember == DISPID_VG_COLFORMAT_COMPAT
                ? obj->col_format_cache_len
                : obj->col_edit_mask_cache_len;
            if (!pVarResult) return E_POINTER;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &col);
            V_VT(pVarResult) = VT_BSTR;
            V_BSTR(pVarResult) = vfg_copy_cached_indexed_bstr(cache, cache_len, col);
            return V_BSTR(pVarResult) ? S_OK : E_OUTOFMEMORY;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t col = 0;
            VARIANT vtmp;
            BSTR value = NULL;
            VariantInit(&vtmp);
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(ARG(0), &col);
                value = variant_to_bstr(ARG(1), &vtmp);
            }
            if (dispIdMember == DISPID_VG_COLFORMAT_COMPAT) {
                vfg_set_cached_indexed_bstr(&obj->col_format_cache, &obj->col_format_cache_len, col, value);
                hr = vfg_set_utf8_indexed_payload_status(volvox_grid_set_col_format, gid, col, value);
            } else {
                vfg_set_cached_indexed_bstr(&obj->col_edit_mask_cache, &obj->col_edit_mask_cache_len, col, value);
                hr = vfg_set_utf8_indexed_payload_status(volvox_grid_set_col_edit_mask, gid, col, value);
            }
            VariantClear(&vtmp);
            return hr;
        }
        break;

    case DISPID_VG_FORMATSTRING_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t out_len = 0;
            uint8_t *utf8 = volvox_grid_get_format_string_native(gid, &out_len);
            if (!pVarResult) return E_POINTER;
            return vfg_utf8_bytes_to_variant_bstr(pVarResult, utf8, out_len);
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            VARIANT vtmp;
            BSTR value = NULL;
            VariantInit(&vtmp);
            if (pDispParams->cArgs >= 1) value = variant_to_bstr(ARG(0), &vtmp);
            hr = vfg_set_utf8_payload_status(volvox_grid_set_format_string, gid, value);
            VariantClear(&vtmp);
            return hr;
        }
        break;

    case DISPID_VG_EDITTEXT_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t out_len = 0;
            uint8_t *utf8 = volvox_grid_get_edit_text(gid, &out_len);
            return vfg_utf8_bytes_to_variant_bstr(pVarResult, utf8, out_len);
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            VARIANT vtmp;
            BSTR value = NULL;
            VariantInit(&vtmp);
            if (pDispParams->cArgs >= 1) value = variant_to_bstr(ARG(0), &vtmp);
            hr = vfg_set_utf8_payload_status(volvox_grid_set_edit_text, gid, value);
            VariantClear(&vtmp);
            return hr;
        }
        break;

    case DISPID_VG_EDITMAXLENGTH_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t value;
            if (!pVarResult) return E_POINTER;
            if (obj->edit_max_length_empty) {
                V_VT(pVarResult) = VT_EMPTY;
                return S_OK;
            }
            value = volvox_grid_get_edit_max_length(gid);
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = value >= 0 ? value : 0;
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t value = 0;
            if (pDispParams->cArgs >= 1) {
                VARIANT *arg = ARG(0);
                VARTYPE vt = V_VT(arg);
                if (vt == VT_I8 || vt == VT_UI8 ||
                    vt == (VT_BYREF | VT_I8) || vt == (VT_BYREF | VT_UI8)) {
                    obj->edit_max_length_empty = 1;
                    return S_OK;
                }
                obj->edit_max_length_empty = 0;
                variant_to_i4(arg, &value);
            } else {
                obj->edit_max_length_empty = 0;
            }
            return volvox_grid_set_edit_max_length(gid, value) == 0 ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_COMBOLIST_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t out_len = 0;
            uint8_t *utf8 = volvox_grid_get_combo_list_native(gid, &out_len);
            if (!pVarResult) return E_POINTER;
            return vfg_utf8_bytes_to_variant_bstr(pVarResult, utf8, out_len);
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            VARIANT vtmp;
            BSTR value = NULL;
            int utf8len = 0;
            char *utf8 = NULL;
            VariantInit(&vtmp);
            if (pDispParams->cArgs >= 1) value = variant_to_bstr(ARG(0), &vtmp);
            utf8 = bstr_to_utf8(value, &utf8len);
            hr = volvox_grid_set_combo_list(
                    gid,
                    (const uint8_t *)(utf8 ? utf8 : ""),
                    utf8 ? utf8len : 0) == 0
                ? S_OK
                : E_FAIL;
            if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
            if (!obj->show_combo_button_explicit) {
                volvox_grid_set_show_combo_button(gid, 0);
            }
            VariantClear(&vtmp);
            return hr;
        }
        break;

    case DISPID_VG_COMBOCOUNT_COMPAT:
        if (wFlags & (DISPATCH_PROPERTYGET | DISPATCH_METHOD)) {
            int32_t count;
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            count = volvox_grid_get_combo_count_compat(gid);
            V_I4(pVarResult) = count > 0 ? count : -1;
            return S_OK;
        }
        break;

    case DISPID_VG_COMBOINDEX_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = volvox_grid_get_combo_index_compat(gid);
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t value = -1;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &value);
            return volvox_grid_set_combo_index_compat(gid, value) == 0 ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_COMBOITEM_COMPAT:
    case DISPID_VG_COMBODATA_COMPAT:
        if (wFlags & (DISPATCH_PROPERTYGET | DISPATCH_METHOD)) {
            int32_t index = volvox_grid_get_combo_index_compat(gid);
            int32_t out_len = 0;
            uint8_t *utf8;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &index);
            utf8 = dispIdMember == DISPID_VG_COMBOITEM_COMPAT
                ? volvox_grid_get_combo_item(gid, index, &out_len)
                : volvox_grid_get_combo_data(gid, index, &out_len);
            return vfg_utf8_bytes_to_variant_bstr(pVarResult, utf8, out_len);
        }
        break;

    case DISPID_VG_VERSION_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t out_len = 0;
            uint8_t *utf8 = volvox_grid_get_version(gid, &out_len);
            return vfg_utf8_bytes_to_variant_bstr(pVarResult, utf8, out_len);
        }
        break;

    case DISPID_VG_CLIENTWIDTH_COMPAT:
    case DISPID_VG_CLIENTHEIGHT_COMPAT:
    case DISPID_VG_BOTTOMROW_COMPAT:
    case DISPID_VG_RIGHTCOL_COMPAT:
    case DISPID_VG_SELECTEDROWS_COMPAT:
    case DISPID_VG_ISSEARCHING_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t value = 0;
            int32_t out_len = 0;
            uint8_t *resp = NULL;
            if (!pVarResult) return E_POINTER;
            if (dispIdMember == DISPID_VG_CLIENTWIDTH_COMPAT) {
                resp = volvox_grid_get_client_width(gid, &out_len);
            } else if (dispIdMember == DISPID_VG_CLIENTHEIGHT_COMPAT) {
                resp = volvox_grid_get_client_height(gid, &out_len);
            } else if (dispIdMember == DISPID_VG_BOTTOMROW_COMPAT) {
                resp = volvox_grid_get_bottom_row(gid, &out_len);
            } else if (dispIdMember == DISPID_VG_RIGHTCOL_COMPAT) {
                resp = volvox_grid_get_right_col(gid, &out_len);
            } else if (dispIdMember == DISPID_VG_SELECTEDROWS_COMPAT) {
                resp = volvox_grid_get_selected_rows(gid, &out_len);
            } else {
                resp = volvox_grid_get_is_searching(gid, &out_len);
            }
            value = vfg_take_i32_response(resp, out_len, 0);
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = value;
            return S_OK;
        }
        break;

    case DISPID_VG_HEIGHT_COMPAT:
    case DISPID_VG_WIDTH_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            VARIANT *cached = dispIdMember == DISPID_VG_HEIGHT_COMPAT
                ? &obj->height_cached
                : &obj->width_cached;
            if (!pVarResult) return E_POINTER;
            if (V_VT(cached) != VT_EMPTY) {
                return VariantCopy(pVarResult, cached);
            }
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = dispIdMember == DISPID_VG_HEIGHT_COMPAT
                ? obj->pos_rect.bottom - obj->pos_rect.top
                : obj->pos_rect.right - obj->pos_rect.left;
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            VARIANT *cached = dispIdMember == DISPID_VG_HEIGHT_COMPAT
                ? &obj->height_cached
                : &obj->width_cached;
            VariantClear(cached);
            if (!pDispParams || pDispParams->cArgs < 1) return DISP_E_PARAMNOTOPTIONAL;
            return VariantCopy(cached, NAMED_ARG(0));
        }
        break;

    case DISPID_VG_SELECTEDROW_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t index = 0;
            int32_t out_len = 0;
            if (!pVarResult) return E_POINTER;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &index);
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = vfg_take_i32_response(
                volvox_grid_get_selected_row(gid, index, &out_len), out_len, -1);
            return S_OK;
        }
        break;

    case DISPID_VG_CLIP_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t out_len = 0;
            uint8_t *utf8 = volvox_grid_get_clip(gid, &out_len);
            return vfg_utf8_clip_to_variant_bstr(pVarResult, utf8, out_len);
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            VARIANT vtmp;
            BSTR value = NULL;
            VariantInit(&vtmp);
            if (pDispParams->cArgs >= 1) value = variant_to_bstr(ARG(0), &vtmp);
            hr = vfg_set_utf8_payload_status(volvox_grid_set_clip, gid, value);
            VariantClear(&vtmp);
            return hr;
        }
        break;

    case DISPID_VG_MOUSEROW_COMPAT:
    case DISPID_VG_MOUSECOL_COMPAT:
        if (wFlags & (DISPATCH_PROPERTYGET | DISPATCH_METHOD)) {
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = dispIdMember == DISPID_VG_MOUSEROW_COMPAT
                ? volvox_grid_get_mouse_row_compat(gid)
                : volvox_grid_get_mouse_col_compat(gid);
            return S_OK;
        }
        break;

    case DISPID_VG_ROWISVISIBLE_COMPAT:
    case DISPID_VG_COLISVISIBLE_COMPAT:
    case DISPID_VG_ROWPOS_COMPAT:
    case DISPID_VG_COLPOS_COMPAT:
    case DISPID_VG_ISSELECTED_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t index = 0;
            int32_t out_len = 0;
            if (!pVarResult) return E_POINTER;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &index);
            V_VT(pVarResult) = VT_I4;
            if (dispIdMember == DISPID_VG_ROWISVISIBLE_COMPAT) {
                V_I4(pVarResult) = volvox_grid_get_row_is_visible(gid, index) ? -1 : 0;
            } else if (dispIdMember == DISPID_VG_COLISVISIBLE_COMPAT) {
                V_I4(pVarResult) = volvox_grid_get_col_is_visible(gid, index) ? -1 : 0;
            } else if (dispIdMember == DISPID_VG_ROWPOS_COMPAT) {
                V_I4(pVarResult) = vfg_take_i32_response(volvox_grid_get_row_pos(gid, index, &out_len), out_len, 0);
            } else if (dispIdMember == DISPID_VG_COLPOS_COMPAT) {
                V_I4(pVarResult) = vfg_take_i32_response(volvox_grid_get_col_pos(gid, index, &out_len), out_len, 0);
            } else {
                V_I4(pVarResult) = vfg_take_i32_response(volvox_grid_get_is_selected(gid, index, &out_len), out_len, 0);
            }
            return S_OK;
        }
        break;

    case DISPID_VG_FOCUS_COMPAT:
        if (wFlags & (DISPATCH_METHOD | DISPATCH_PROPERTYGET)) {
            if (pVarResult) VariantInit(pVarResult);
            return S_OK;
        }
        break;

    case DISPID_VG_MOUSEPOINTER_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            VariantInit(pVarResult);
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = obj->mouse_pointer_cached;
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &obj->mouse_pointer_cached);
            vfg_update_host_cursor(obj);
            return S_OK;
        }
        break;

    case DISPID_VG_APPEARANCE_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            VariantInit(pVarResult);
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = volvox_grid_get_appearance_native(gid);
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t value = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &value);
            if (volvox_grid_set_appearance_native(gid, value) != 0) return E_FAIL;
            return S_OK;
        }
        break;

    case DISPID_VG_SHEETBORDER_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            VariantInit(pVarResult);
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = (int32_t)argb_to_olecolor(
                volvox_grid_get_sheet_border_native(gid));
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            uint32_t value = 0;
            HRESULT hr_color = variant_to_u32(ARG(0), &value);
            if (FAILED(hr_color)) return hr_color;
            if (volvox_grid_set_sheet_border_native(gid, olecolor_to_argb(value)) != 0) {
                return E_FAIL;
            }
            return S_OK;
        }
        break;

    case DISPID_VG_FONTBOLD_COMPAT:
    case DISPID_VG_FONTITALIC_COMPAT:
    case DISPID_VG_FONTSTRIKETHRU_COMPAT:
    case DISPID_VG_FONTUNDERLINE_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t enabled = 0;
            if (!pVarResult) return E_POINTER;
            if (dispIdMember == DISPID_VG_FONTBOLD_COMPAT) {
                enabled = volvox_grid_get_font_bold_native(gid);
            } else if (dispIdMember == DISPID_VG_FONTITALIC_COMPAT) {
                enabled = volvox_grid_get_font_italic_native(gid);
            } else if (dispIdMember == DISPID_VG_FONTSTRIKETHRU_COMPAT) {
                enabled = volvox_grid_get_font_strikethrough_native(gid);
            } else {
                enabled = volvox_grid_get_font_underline_native(gid);
            }
            VariantInit(pVarResult);
            V_VT(pVarResult) = VT_BOOL;
            V_BOOL(pVarResult) = enabled ? VARIANT_TRUE : VARIANT_FALSE;
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t enabled = pDispParams->cArgs >= 1 ? vfg_variant_to_bool_i32(ARG(0)) : 0;
            int32_t rc = 0;
            if (dispIdMember == DISPID_VG_FONTBOLD_COMPAT) {
                rc = volvox_grid_set_font_bold_native(gid, enabled);
            } else if (dispIdMember == DISPID_VG_FONTITALIC_COMPAT) {
                rc = volvox_grid_set_font_italic_native(gid, enabled);
            } else if (dispIdMember == DISPID_VG_FONTSTRIKETHRU_COMPAT) {
                rc = volvox_grid_set_font_strikethrough_native(gid, enabled);
            } else {
                rc = volvox_grid_set_font_underline_native(gid, enabled);
            }
            return rc == 0 ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_FONTWIDTH_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            VariantInit(pVarResult);
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = volvox_grid_get_font_width_native(gid);
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t value = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &value);
            if (volvox_grid_set_font_width_native(gid, value) != 0) return E_FAIL;
            return S_OK;
        }
        break;

    case DISPID_VG_ALLOWUSERFREEZING_COMPAT:
    case DISPID_VG_EXPLORERBAR_COMPAT:
    case DISPID_VG_TABBEHAVIOR_COMPAT:
    case DISPID_VG_COLWIDTHMIN_COMPAT:
    case DISPID_VG_ROWHEIGHTMIN_COMPAT:
    case DISPID_VG_GRIDLINEWIDTH_COMPAT:
        {
            int32_t current = 0;
            if (dispIdMember == DISPID_VG_ALLOWUSERFREEZING_COMPAT) {
                current = volvox_grid_get_allow_user_freezing_native(gid);
            } else if (dispIdMember == DISPID_VG_EXPLORERBAR_COMPAT) {
                current = volvox_grid_get_explorer_bar_native(gid);
            } else if (dispIdMember == DISPID_VG_TABBEHAVIOR_COMPAT) {
                current = volvox_grid_get_tab_behavior_native(gid);
            } else if (dispIdMember == DISPID_VG_COLWIDTHMIN_COMPAT) {
                current = obj ? obj->col_width_min_twips
                              : vfg_px_to_twips_x(volvox_grid_get_col_width_min_default_native(gid));
            } else if (dispIdMember == DISPID_VG_ROWHEIGHTMIN_COMPAT) {
                current = obj ? obj->row_height_min_twips
                              : vfg_px_to_twips_y(volvox_grid_get_row_height_min_native(gid));
            } else if (dispIdMember == DISPID_VG_GRIDLINEWIDTH_COMPAT) {
                current = volvox_grid_get_grid_line_width_native(gid);
            }
            if (wFlags & DISPATCH_PROPERTYGET) {
                if (!pVarResult) return E_POINTER;
                VariantInit(pVarResult);
                V_VT(pVarResult) = VT_I4;
                V_I4(pVarResult) = current;
                return S_OK;
            }
            if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
                int32_t value = current;
                if (pDispParams->cArgs >= 1) {
                    hr = variant_to_i4(ARG(0), &value);
                    if (FAILED(hr)) return hr;
                }
                if (dispIdMember == DISPID_VG_EXPLORERBAR_COMPAT) {
                    if (volvox_grid_set_explorer_bar_native(gid, value) != 0) return E_FAIL;
                    return S_OK;
                }
                if (dispIdMember == DISPID_VG_TABBEHAVIOR_COMPAT) {
                    if (volvox_grid_set_tab_behavior_native(gid, value) != 0) return E_FAIL;
                    return S_OK;
                }
                if (dispIdMember == DISPID_VG_ALLOWUSERFREEZING_COMPAT) {
                    if (volvox_grid_set_allow_user_freezing_native(
                            gid, value) != 0) {
                        return E_FAIL;
                    }
                    return S_OK;
                }
                if (dispIdMember == DISPID_VG_COLWIDTHMIN_COMPAT) {
                    if (obj) obj->col_width_min_twips = value;
                    if (volvox_grid_set_col_width_min_default_native(
                            gid, vfg_twips_to_px_x(value)) != 0) {
                        return E_FAIL;
                    }
                    return S_OK;
                }
                if (dispIdMember == DISPID_VG_ROWHEIGHTMIN_COMPAT) {
                    if (obj) obj->row_height_min_twips = value;
                    if (volvox_grid_set_row_height_min_native(
                            gid, vfg_twips_to_px_y(value)) != 0) {
                        return E_FAIL;
                    }
                    return S_OK;
                }
                if (dispIdMember == DISPID_VG_GRIDLINEWIDTH_COMPAT) {
                    if (volvox_grid_set_grid_line_width_native(
                            gid,
                            value) != 0) {
                        return E_FAIL;
                    }
                    return S_OK;
                }
                return S_OK;
            }
        }
        break;

    case DISPID_VG_SCROLLTIPTEXT_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t out_len = 0;
            uint8_t *utf8 = volvox_grid_get_scroll_tip_text(gid, &out_len);
            return vfg_utf8_bytes_to_variant_bstr(pVarResult, utf8, out_len);
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            VARIANT vtmp;
            BSTR value = NULL;
            VariantInit(&vtmp);
            if (pDispParams->cArgs >= 1) value = variant_to_bstr(ARG(0), &vtmp);
            hr = vfg_set_utf8_payload_status(volvox_grid_set_scroll_tip_text, gid, value);
            VariantClear(&vtmp);
            return hr;
        }
        break;

    case DISPID_VG_CLIPSEPARATORS_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t out_len = 0;
            uint8_t *utf8 = volvox_grid_get_clip_separators_native(gid, &out_len);
            if (!pVarResult) return E_POINTER;
            return vfg_utf8_bytes_to_variant_bstr(pVarResult, utf8, out_len);
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            VARIANT vtmp;
            BSTR value = NULL;
            VariantInit(&vtmp);
            if (pDispParams->cArgs >= 1) value = variant_to_bstr(ARG(0), &vtmp);
            hr = vfg_set_utf8_payload_status(
                volvox_grid_set_clip_separators_compat_native,
                gid,
                value);
            VariantClear(&vtmp);
            return hr;
        }
        break;

    case DISPID_VG_PICTURETYPE_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t value = volvox_grid_get_picture_type_compat(gid);
            if (!pVarResult) return E_POINTER;
            VariantInit(pVarResult);
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = value;
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t value = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &value);
            if (volvox_grid_set_picture_type_compat(gid, value) != 0) return E_FAIL;
            return S_OK;
        }
        break;

    case DISPID_VG_SCROLLTIPS_COMPAT:
    case DISPID_VG_COMBOSEARCH_COMPAT:
    case DISPID_VG_OWNERDRAW_COMPAT:
    case DISPID_VG_MERGECELLSFIXED_COMPAT:
    case DISPID_VG_GROUPCOMPARE_COMPAT:
        {
            int32_t current = 0;
            VARTYPE vt = VT_I4;
            if (dispIdMember == DISPID_VG_SCROLLTIPS_COMPAT) {
                current = volvox_grid_get_scroll_tips_compat(gid);
                vt = VT_BOOL;
            } else if (dispIdMember == DISPID_VG_COMBOSEARCH_COMPAT) {
                current = volvox_grid_get_combo_search_compat(gid);
                vt = VT_I4;
            } else if (dispIdMember == DISPID_VG_OWNERDRAW_COMPAT) {
                current = volvox_grid_get_owner_draw_compat(gid);
            } else if (dispIdMember == DISPID_VG_MERGECELLSFIXED_COMPAT) {
                current = volvox_grid_get_merge_cells_fixed_native(gid);
            } else if (dispIdMember == DISPID_VG_GROUPCOMPARE_COMPAT) {
                current = volvox_grid_get_group_compare_compat(gid);
            }
            if (wFlags & DISPATCH_PROPERTYGET) {
                if (!pVarResult) return E_POINTER;
                VariantInit(pVarResult);
                V_VT(pVarResult) = vt;
                if (vt == VT_BOOL) {
                    V_BOOL(pVarResult) = current ? VARIANT_TRUE : VARIANT_FALSE;
                } else {
                    V_I4(pVarResult) = current;
                }
                return S_OK;
            }
            if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
                int32_t value = 0;
                if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &value);
                if (dispIdMember == DISPID_VG_SCROLLTIPS_COMPAT) {
                    if (volvox_grid_set_scroll_tips_compat(gid, value) != 0) return E_FAIL;
                }
                if (dispIdMember == DISPID_VG_COMBOSEARCH_COMPAT) {
                    if (volvox_grid_set_combo_search_compat(gid, value) != 0) return E_FAIL;
                }
                if (dispIdMember == DISPID_VG_OWNERDRAW_COMPAT) {
                    if (volvox_grid_set_owner_draw_compat(gid, value) != 0) return E_FAIL;
                }
                if (dispIdMember == DISPID_VG_MERGECELLSFIXED_COMPAT) {
                    if (volvox_grid_set_merge_cells_fixed_compat(gid, value) != 0) return E_FAIL;
                }
                if (dispIdMember == DISPID_VG_GROUPCOMPARE_COMPAT) {
                    if (volvox_grid_set_group_compare_compat(gid, value) != 0) return E_FAIL;
                }
                return S_OK;
            }
        }
        break;

    case DISPID_VG_COLIMAGELIST_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t col = 0;
            int32_t value = 0;
            if (!pVarResult) return E_POINTER;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &col);
            value = volvox_grid_get_col_image_list_native(gid, col);
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = value;
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t col = 0;
            int32_t value = 0;
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(ARG(0), &col);
                variant_to_i4(ARG(1), &value);
            }
            if (volvox_grid_set_col_image_list_native(gid, col, value) != 0) return E_FAIL;
            return S_OK;
        }
        break;

    case DISPID_VG_COLINDENT_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t col = 0;
            int32_t value = 0;
            if (!pVarResult) return E_POINTER;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &col);
            value = volvox_grid_get_col_indent_native(gid, col);
            vfg_set_cached_indexed_i32(&obj->col_indent_cache, &obj->col_indent_cache_len, col, value);
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = value;
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t col = 0;
            int32_t value = 0;
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(ARG(0), &col);
                variant_to_i4(ARG(1), &value);
            }
            if (volvox_grid_set_col_indent_native(gid, col, value) != 0) return E_FAIL;
            vfg_set_cached_indexed_i32(&obj->col_indent_cache, &obj->col_indent_cache_len, col, value);
            return S_OK;
        }
        break;

    case DISPID_VG_ROWPOSITION_COMPAT:
    case DISPID_VG_COLPOSITION_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t index = 0;
            if (!pVarResult) return E_POINTER;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &index);
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = dispIdMember == DISPID_VG_ROWPOSITION_COMPAT
                ? volvox_grid_get_row_display_position(gid, index)
                : volvox_grid_get_col_display_position(gid, index);
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t index = 0;
            int32_t position = 0;
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(ARG(0), &index);
                variant_to_i4(ARG(1), &position);
                if (dispIdMember == DISPID_VG_ROWPOSITION_COMPAT) {
                    if (volvox_grid_set_row_position(gid, index, position) != 0) return E_FAIL;
                    return SUCCEEDED(vfg_pump_engine_events(obj)) ? S_OK : E_FAIL;
                }
                if (volvox_grid_set_col_position(gid, index, position) != 0) return E_FAIL;
                return SUCCEEDED(vfg_pump_engine_events(obj)) ? S_OK : E_FAIL;
            }
            return S_OK;
        }
        break;

    case DISPID_VG_TEXT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            int32_t engine_row = vfg_row_engine_from_display_property(gid, row);
            int32_t engine_col = vfg_col_engine_from_display_property(obj, col);
            int32_t out_len = 0;
            uint8_t *utf8;
            if (!pVarResult) return E_POINTER;
            utf8 = volvox_grid_get_text_matrix(gid, engine_row, engine_col, &out_len);
            return vfg_utf8_bytes_to_variant_bstr(pVarResult, utf8, out_len);
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            int32_t engine_row = vfg_row_engine_from_display_property(gid, row);
            int32_t engine_col = vfg_col_engine_from_display_property(obj, col);
            VARIANT vtmp;
            BSTR value = NULL;
            VariantInit(&vtmp);
            if (pDispParams->cArgs >= 1) {
                value = variant_to_bstr(ARG(0), &vtmp);
            }
            hr = vfg_set_text_matrix_bstr(gid, engine_row, engine_col, value);
            VariantClear(&vtmp);
            return hr;
        }
        break;

    case DISPID_VG_VALUE_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            int32_t out_len = 0;
            uint8_t *utf8;
            BSTR text;
            VARIANT src;
            if (!pVarResult) return E_POINTER;
            utf8 = volvox_grid_get_text_matrix(gid, row, col, &out_len);
            text = utf8 && out_len > 0 ? utf8_to_bstr((const char *)utf8, out_len) : SysAllocString(L"0");
            if (utf8) volvox_grid_free(utf8, out_len);
            VariantInit(&src);
            V_VT(&src) = VT_BSTR;
            V_BSTR(&src) = text;
            VariantInit(pVarResult);
            hr = VariantChangeType(pVarResult, &src, 0, VT_R8);
            VariantClear(&src);
            return SUCCEEDED(hr) ? S_OK : hr;
        }
        break;

    case DISPID_VG_FLAGS_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t out_len = 0;
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = vfg_take_i32_response(volvox_grid_get_flags(gid, &out_len), out_len, 0);
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t flags = 0;
            int32_t out_len = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &flags);
            return vfg_take_status_response(volvox_grid_set_flags(gid, flags, &out_len)) == 0 ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_BACKCOLORBKG_COMPAT:
    case DISPID_VG_BACKCOLORFROZEN_COMPAT:
    case DISPID_VG_FLOODCOLOR_COMPAT:
    case DISPID_VG_FORECOLORFROZEN_COMPAT:
    case DISPID_VG_GRIDCOLORFIXED_COMPAT:
        {
            uint32_t current = 0;
            if (dispIdMember == DISPID_VG_BACKCOLORBKG_COMPAT) {
                current = volvox_grid_get_back_color_bkg_native(gid);
            } else if (dispIdMember == DISPID_VG_BACKCOLORFROZEN_COMPAT) {
                current = volvox_grid_get_back_color_frozen_native(gid);
            } else if (dispIdMember == DISPID_VG_FLOODCOLOR_COMPAT) {
                current = volvox_grid_get_flood_color_native(gid);
            } else if (dispIdMember == DISPID_VG_FORECOLORFROZEN_COMPAT) {
                current = volvox_grid_get_fore_color_frozen_native(gid);
            } else if (dispIdMember == DISPID_VG_GRIDCOLORFIXED_COMPAT) {
                current = volvox_grid_get_grid_color_fixed(gid);
            }
            if (wFlags & DISPATCH_PROPERTYGET) {
                if (!pVarResult) return E_POINTER;
                V_VT(pVarResult) = VT_I4;
                V_I4(pVarResult) = (LONG)argb_to_olecolor(current);
                return S_OK;
            }
            if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
                uint32_t value = 0;
                uint32_t engine_value = 0;
                if (pDispParams->cArgs >= 1) {
                    hr = variant_to_u32(ARG(0), &value);
                    if (FAILED(hr)) return hr;
                }
                engine_value = olecolor_to_argb(value);
                if (dispIdMember == DISPID_VG_BACKCOLORBKG_COMPAT) {
                    if (volvox_grid_set_back_color_bkg_native(gid, engine_value) != 0) return E_FAIL;
                } else if (dispIdMember == DISPID_VG_BACKCOLORFROZEN_COMPAT) {
                    if (volvox_grid_set_back_color_frozen_native(gid, engine_value) != 0) return E_FAIL;
                } else if (dispIdMember == DISPID_VG_FLOODCOLOR_COMPAT) {
                    if (volvox_grid_set_flood_color_native(gid, engine_value) != 0) return E_FAIL;
                } else if (dispIdMember == DISPID_VG_FORECOLORFROZEN_COMPAT) {
                    if (volvox_grid_set_fore_color_frozen_native(gid, engine_value) != 0) return E_FAIL;
                } else if (dispIdMember == DISPID_VG_GRIDCOLORFIXED_COMPAT) {
                    if (volvox_grid_set_grid_color_fixed(gid, engine_value) != 0) return E_FAIL;
                }
                return S_OK;
            }
        }
        break;

    case DISPID_VG_SHOWCELL_COMPAT:
        if (wFlags & DISPATCH_METHOD) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &row);
            if (pDispParams->cArgs >= 2) variant_to_i4(ARG(1), &col);
            {
                int32_t ignore_len = 0;
                uint8_t *ignore = vfg_native_set_row(gid, row, &ignore_len);
                if (ignore) volvox_grid_free(ignore, ignore_len);
                ignore = vfg_native_set_col(gid, col, &ignore_len);
                if (ignore) volvox_grid_free(ignore, ignore_len);
                ignore = vfg_native_set_row_sel(gid, row, &ignore_len);
                if (ignore) volvox_grid_free(ignore, ignore_len);
                ignore = vfg_native_set_col_sel(gid, col, &ignore_len);
                if (ignore) volvox_grid_free(ignore, ignore_len);
            }
            return volvox_grid_show_cell_compat(gid, row, col) == 0 ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_TEXTARRAY:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t index = 0;
            int32_t row = 0;
            int32_t col = 0;
            int32_t cols = volvox_grid_get_cols(gid);
            int32_t out_len = 0;
            uint8_t *utf8;
            if (!pVarResult) return E_POINTER;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &index);
            if (cols > 0) {
                row = index / cols;
                col = index % cols;
            }
            utf8 = volvox_grid_get_text_matrix(gid, row, col, &out_len);
            return vfg_utf8_bytes_to_variant_bstr(pVarResult, utf8, out_len);
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t index = 0;
            int32_t row = 0;
            int32_t col = 0;
            int32_t cols = volvox_grid_get_cols(gid);
            VARIANT vtmp;
            BSTR value = NULL;
            VariantInit(&vtmp);
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(ARG(0), &index);
                value = variant_to_bstr(ARG(1), &vtmp);
            }
            if (cols > 0) {
                row = index / cols;
                col = index % cols;
            }
            hr = vfg_set_text_matrix_bstr(gid, row, col, value);
            VariantClear(&vtmp);
            return hr;
        }
        break;

    case DISPID_VG_VALUEMATRIX_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t row = 0;
            int32_t col = 0;
            int32_t engine_row = 0;
            int32_t engine_col = 0;
            int32_t out_len = 0;
            uint8_t *value_utf8;
            if (!pVarResult) return E_POINTER;
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(ARG(0), &row);
                variant_to_i4(ARG(1), &col);
            }
            engine_row = vfg_row_engine_from_display_property(gid, row);
            engine_col = vfg_col_engine_from_display_property(obj, col);
            value_utf8 = volvox_grid_get_value_matrix_compat_text(gid, engine_row, engine_col, &out_len);
            if (value_utf8 && out_len > 0) {
                HRESULT ret = vfg_utf8_bytes_to_variant_bstr(pVarResult, value_utf8, out_len);
                return ret;
            }
            if (value_utf8) volvox_grid_free(value_utf8, out_len);
            {
                int32_t text_len = 0;
                uint8_t *text = volvox_grid_get_text_matrix(gid, engine_row, engine_col, &text_len);
                V_VT(pVarResult) = VT_I4;
                V_I4(pVarResult) = text && text_len > 0
                    ? vfg_first_number_in_utf8(text, text_len)
                    : 0;
                if (text) volvox_grid_free(text, text_len);
            }
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t row = 0;
            int32_t col = 0;
            int32_t engine_row = 0;
            int32_t engine_col = 0;
            int32_t out_len = 0;
            VARIANT vtmp;
            BSTR value = NULL;
            int utf8len = 0;
            char *utf8;
            uint8_t *out;
            VariantInit(&vtmp);
            if (pDispParams->cArgs >= 3) {
                variant_to_i4(ARG(0), &row);
                variant_to_i4(ARG(1), &col);
                value = variant_to_bstr(ARG(2), &vtmp);
            }
            engine_row = vfg_row_engine_from_display_property(gid, row);
            engine_col = vfg_col_engine_from_display_property(obj, col);
            utf8 = bstr_to_utf8(value, &utf8len);
            out = volvox_grid_set_value_matrix(
                gid,
                engine_row,
                engine_col,
                (const uint8_t *)(utf8 ? utf8 : ""),
                utf8 ? utf8len : 0,
                &out_len);
            if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
            VariantClear(&vtmp);
            return vfg_take_status_response(out) == 0 ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_BUILDCOMBOLIST_COMPAT:
        if (wFlags & (DISPATCH_METHOD | DISPATCH_PROPERTYGET)) {
            VARIANT vFields;
            VARIANT vKey;
            IDispatch *rs = NULL;
            BSTR fieldList = NULL;
            BSTR keyField = NULL;
            BSTR result = NULL;
            if (!pVarResult) return E_POINTER;
            VariantInit(&vFields);
            VariantInit(&vKey);
            if (pDispParams->cArgs >= 1) {
                if (V_VT(ARG(0)) == VT_DISPATCH) {
                    rs = V_DISPATCH(ARG(0));
                } else if (V_VT(ARG(0)) == VT_UNKNOWN && V_UNKNOWN(ARG(0))) {
                    if (FAILED(IUnknown_QueryInterface(V_UNKNOWN(ARG(0)), &IID_IDispatch, (void **)&rs))) {
                        rs = NULL;
                    }
                }
            }
            if (pDispParams->cArgs >= 2) fieldList = variant_to_bstr(ARG(1), &vFields);
            if (pDispParams->cArgs >= 3) keyField = variant_to_bstr(ARG(2), &vKey);
            hr = vfg_build_combo_list_from_recordset(rs, fieldList, keyField, &result);
            VariantClear(&vKey);
            VariantClear(&vFields);
            if (rs && rs != V_DISPATCH(ARG(0))) IDispatch_Release(rs);
            if (FAILED(hr)) return hr;
            V_VT(pVarResult) = VT_BSTR;
            V_BSTR(pVarResult) = result ? result : SysAllocString(L"");
            return V_BSTR(pVarResult) ? S_OK : E_OUTOFMEMORY;
        }
        break;

    case DISPID_VG_DATASOURCE_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            VariantInit(pVarResult);
            V_VT(pVarResult) = VT_UNKNOWN;
            V_UNKNOWN(pVarResult) = (IUnknown *)obj->data_source;
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
            if (obj->data_mode != 0) {
                VARIANT_BOOL cancel = VARIANT_FALSE;
                vfg_fire_before_data_refresh_event(obj, &cancel);
                if (cancel != VARIANT_FALSE) {
                    vfg_release_dispatch(&obj->data_source);
                    obj->data_source = newSource;
                    return S_OK;
                }
            }
            hr = (HRESULT)volvox_grid_ado_attach_native(obj->grid_id, newSource);
            if (newSource) IDispatch_Release(newSource);
            if (SUCCEEDED(hr) && obj->data_mode != 0) {
                vfg_fire_simple_event(obj, DISPID_VFG_EVT_AFTERDATAREFRESH);
            } else if (FAILED(hr) && obj->data_mode != 0) {
                vfg_fire_ado_data_error_event(obj, hr);
            }
            return FAILED(hr) ? hr : S_OK;
        }
        break;

    case DISPID_VG_OLEDRAGMODE_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = obj->ole_drag_mode_cached;
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t mode = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(NAMED_ARG(0), &mode);
            if (mode < 0) mode = 0;
            obj->ole_drag_mode_cached = mode;
            return S_OK;
        }
        break;

    case DISPID_VG_OLEDROPMODE_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = obj->ole_drop_mode_cached;
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t mode = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(NAMED_ARG(0), &mode);
            if (mode < 0) mode = 0;
            obj->ole_drop_mode_cached = mode;
            return S_OK;
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
                if (obj->data_mode != 0) {
                    VARIANT_BOOL cancel = VARIANT_FALSE;
                    vfg_fire_before_data_refresh_event(obj, &cancel);
                    if (cancel != VARIANT_FALSE) return S_OK;
                }
                HRESULT hr = vfg_rebind_ado_source(obj);
                if (SUCCEEDED(hr) && obj->data_mode != 0) {
                    vfg_fire_simple_event(obj, DISPID_VFG_EVT_AFTERDATAREFRESH);
                }
                if (FAILED(hr) && obj->data_mode != 0) {
                    vfg_fire_ado_data_error_event(obj, hr);
                }
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
                if (FAILED(hr) && obj->data_mode != 0) {
                    vfg_fire_ado_data_error_event(obj, hr);
                }
                if (FAILED(hr)) return hr;
            }
            return S_OK;
        }
        break;

    case DISPID_VG_DATAREFRESH_COMPAT:
        if (wFlags & DISPATCH_METHOD) {
            HRESULT hr = S_OK;
            if (obj->data_source && obj->data_mode != 0) {
                VARIANT_BOOL cancel = VARIANT_FALSE;
                vfg_fire_before_data_refresh_event(obj, &cancel);
                if (cancel != VARIANT_FALSE) return S_OK;
            }
            hr = obj->data_source ? vfg_rebind_ado_source(obj) : S_OK;
            if (SUCCEEDED(hr) && obj->data_source && obj->data_mode != 0) {
                vfg_fire_simple_event(obj, DISPID_VFG_EVT_AFTERDATAREFRESH);
            } else if (FAILED(hr) && obj->data_source && obj->data_mode != 0) {
                vfg_fire_ado_data_error_event(obj, hr);
            }
            return FAILED(hr) ? hr : S_OK;
        }
        break;

    case DISPID_VG_OLEDRAG_COMPAT:
        if (wFlags & DISPATCH_METHOD) {
            LONG allowed = DROPEFFECT_COPY | DROPEFFECT_MOVE;
            int32_t effect = DROPEFFECT_NONE;
            HRESULT ole_hr;
            if (pDispParams->cArgs >= 1) {
                int32_t requested = 0;
                if (SUCCEEDED(variant_to_i4(ARG(0), &requested)) && requested != 0) {
                    allowed = requested;
                }
            }
            ole_hr = (HRESULT)volvox_grid_ole_begin_drag_native(gid, allowed, &effect);
            if (FAILED(ole_hr)) return ole_hr;
            if (pVarResult) {
                V_VT(pVarResult) = VT_I4;
                V_I4(pVarResult) = (LONG)effect;
            }
            return S_OK;
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
            int32_t old_val = volvox_grid_get_frozen_rows_cached(gid);
            int32_t val = 0;
            variant_to_i4(NAMED_ARG(0), &val);
            if (volvox_grid_set_frozen_rows(gid, val) != 0) return E_FAIL;
            if (val != old_val) {
                vfg_fire_simple_event(obj, DISPID_VFG_EVT_AFTERUSERFREEZE);
            }
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
            int32_t old_val = volvox_grid_get_frozen_cols_cached(gid);
            int32_t val = 0;
            variant_to_i4(NAMED_ARG(0), &val);
            if (volvox_grid_set_frozen_cols(gid, val) != 0) return E_FAIL;
            if (val != old_val) {
                vfg_fire_simple_event(obj, DISPID_VFG_EVT_AFTERUSERFREEZE);
            }
            return S_OK;
        }
        break;

    case DISPID_VG_EDITABLE:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = volvox_grid_get_editable_native(gid);
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
            int32_t engine_row = 0, engine_col = 0;
            BSTR text = NULL;
            VARIANT vtmp; VariantInit(&vtmp);
            if (pDispParams->cArgs >= 3) {
                variant_to_i4(&pDispParams->rgvarg[2], &row);
                variant_to_i4(&pDispParams->rgvarg[1], &col);
                text = variant_to_bstr(&pDispParams->rgvarg[0], &vtmp);
            }
            engine_row = vfg_row_engine_from_display_property(gid, row);
            engine_col = vfg_col_engine_from_display_property(obj, col);
            if (text) {
                if (vfg_should_preserve_blank_bound_header(obj, row, col, text)) {
                    VariantClear(&vtmp);
                    return S_OK;
                }
                if (obj->data_source &&
                    obj->suppress_bound_text_writes &&
                    row >= obj->fixed_rows_cached &&
                    col >= obj->bound_data_col_offset) {
                    VariantClear(&vtmp);
                    return S_OK;
                }
                if (obj->data_source &&
                    obj->recordset &&
                    obj->data_mode != 0 &&
                    row >= obj->fixed_rows_cached &&
                    col >= obj->bound_data_col_offset) {
                    HRESULT hr_put = vfg_bound_put_cell_value(obj, row, col, text);
                    if (FAILED(hr_put)) {
                        VariantClear(&vtmp);
                        return hr_put;
                    }
                }
                int utf8len = 0;
                char *utf8 = bstr_to_utf8(text, &utf8len);
                if (utf8) {
                    volvox_grid_set_text_matrix(gid, engine_row, engine_col,
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
            int32_t engine_row = 0, engine_col = 0;
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(&pDispParams->rgvarg[1], &row);
                variant_to_i4(&pDispParams->rgvarg[0], &col);
            }
            engine_row = vfg_row_engine_from_display_property(gid, row);
            engine_col = vfg_col_engine_from_display_property(obj, col);
            if (obj->bound_virtual_active &&
                row >= VFG_BOUND_HEADER_ROWS &&
                (row < obj->bound_window_start || row >= obj->bound_window_end)) {
                hr = vfg_bound_fetch_window(obj, row, 1);
                if (FAILED(hr)) {
                    vfg_fire_ado_data_error_event(obj, hr);
                    return hr;
                }
            }
            int32_t out_len = 0;
            uint8_t *utf8 = volvox_grid_get_text_matrix(gid, engine_row, engine_col, &out_len);
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
                int32_t checked = volvox_grid_get_cell_checked(gid, engine_row, engine_col);
                int32_t data_type = vfg_get_cached_col_data_type(obj, engine_col);
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
            idx = vfg_row_engine_from_display_property(gid, idx);
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
            idx = vfg_row_engine_from_display_property(gid, idx);
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
            idx = vfg_col_engine_from_display_property(obj, idx);
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
            idx = vfg_col_engine_from_display_property(obj, idx);
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
            float px = pt * (float)vfg_get_screen_dpi_y() / 72.0f;
            if (px > 0.0f) px = (float)((int)(px + 0.5f));
            volvox_grid_set_font_size(gid, px);
            if (px > 0.0f) {
                int32_t out_len = 0;
                int32_t row_height = vfg_compat_default_row_height_px(px);
                uint8_t *out = volvox_grid_set_default_row_height_native(
                    gid,
                    row_height,
                    &out_len);
                vfg_take_status_response(out);
            }
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
            int32_t col = 0;
            if (!pVarResult) return E_POINTER;
            if (pDispParams->cArgs >= 1) {
                variant_to_i4(&pDispParams->rgvarg[0], &col);
            }
            V_VT(pVarResult) = VT_BSTR;
            V_BSTR(pVarResult) = vfg_copy_cached_indexed_bstr(
                obj->col_combo_list_cache,
                obj->col_combo_list_cache_len,
                col);
            return V_BSTR(pVarResult) ? S_OK : E_OUTOFMEMORY;
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
            vfg_set_cached_indexed_bstr(
                &obj->col_combo_list_cache,
                &obj->col_combo_list_cache_len,
                col,
                list);
            VariantClear(&vtmp);
            return S_OK;
        }
        break;

    case 45: /* CellBackColor */
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = (int32_t)argb_to_olecolor(
                volvox_grid_get_cell_back_color(gid, row, col));
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            uint32_t color = 0;
            variant_to_u32(NAMED_ARG(0), &color);
            return volvox_grid_set_cell_back_color_range(
                gid, row, col, row, col, olecolor_to_argb(color)) == 0 ? S_OK : E_FAIL;
        }
        break;

    case 46: /* CellForeColor */
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = (int32_t)argb_to_olecolor(
                volvox_grid_get_cell_fore_color_native(gid, row, col));
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            uint32_t color = 0;
            int32_t out_len = 0;
            uint8_t *resp;
            variant_to_u32(NAMED_ARG(0), &color);
            resp = volvox_grid_set_cell_fore_color_range_native(
                gid, row, col, row, col, olecolor_to_argb(color), &out_len);
            return vfg_take_status_response(resp) == 0 ? S_OK : E_FAIL;
        }
        break;

    case 47: /* CellAlignment */
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = volvox_grid_get_cell_alignment_native(gid, row, col);
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            int32_t alignment = 0;
            int32_t out_len = 0;
            uint8_t *resp;
            variant_to_i4(NAMED_ARG(0), &alignment);
            resp = volvox_grid_set_cell_alignment_range_native(
                gid, row, col, row, col, alignment, &out_len);
            return vfg_take_status_response(resp) == 0 ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_CELLPICTURE_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            int32_t picture_len = 0;
            uint8_t *picture;
            HRESULT hrPic;
            if (!pVarResult) return E_POINTER;
            picture = volvox_grid_get_cell_picture_native(gid, row, col, &picture_len);
            hrPic = vfg_variant_from_ui1_bytes(pVarResult, picture, picture_len);
            if (picture) volvox_grid_free(picture, picture_len);
            return hrPic;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            uint8_t *picture = NULL;
            int32_t picture_len = 0;
            HRESULT hrPic = vfg_variant_to_png_picture_bytes(NAMED_ARG(0), &picture, &picture_len);
            if (FAILED(hrPic)) return hrPic;
            hr = vfg_set_cell_picture_range_compat(gid, row, col, row, col, picture, picture_len);
            if (picture) HeapFree(GetProcessHeap(), 0, picture);
            return hr;
        }
        break;

    case DISPID_VG_CELLPICTUREALIGNMENT_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = volvox_grid_get_cell_picture_alignment_native(gid, row, col);
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            int32_t alignment = 0;
            if (SUCCEEDED(variant_to_i4(NAMED_ARG(0), &alignment))) {
                return vfg_set_cell_picture_alignment_range_compat(
                    gid, row, col, row, col, alignment);
            }
            return DISP_E_TYPEMISMATCH;
        }
        break;

    case DISPID_VG_CELLBUTTONPICTURE_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            int32_t picture_len = 0;
            uint8_t *picture;
            HRESULT hrPic;
            if (!pVarResult) return E_POINTER;
            picture = volvox_grid_get_cell_button_picture_native(gid, row, col, &picture_len);
            hrPic = vfg_variant_from_ui1_bytes(pVarResult, picture, picture_len);
            if (picture) volvox_grid_free(picture, picture_len);
            return hrPic;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            uint8_t *picture = NULL;
            int32_t picture_len = 0;
            HRESULT hrPic = vfg_variant_to_png_picture_bytes(NAMED_ARG(0), &picture, &picture_len);
            if (FAILED(hrPic)) return hrPic;
            hr = vfg_set_cell_button_picture_range_compat(
                gid, row, col, row, col, picture, picture_len);
            if (picture) HeapFree(GetProcessHeap(), 0, picture);
            return hr;
        }
        break;

    case DISPID_VG_NODEOPENPICTURE_COMPAT:
    case DISPID_VG_NODECLOSEDPICTURE_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t picture_len = 0;
            uint8_t *picture;
            HRESULT hrPic;
            if (!pVarResult) return E_POINTER;
            picture = dispIdMember == DISPID_VG_NODEOPENPICTURE_COMPAT
                ? volvox_grid_get_node_open_picture_native(gid, &picture_len)
                : volvox_grid_get_node_closed_picture_native(gid, &picture_len);
            hrPic = vfg_variant_from_ui1_bytes(pVarResult, picture, picture_len);
            if (picture) volvox_grid_free(picture, picture_len);
            return hrPic;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            uint8_t *picture = NULL;
            int32_t picture_len = 0;
            HRESULT hrPic = vfg_variant_to_png_picture_bytes(NAMED_ARG(0), &picture, &picture_len);
            if (FAILED(hrPic)) return hrPic;
            hr = vfg_set_native_picture_compat(
                dispIdMember == DISPID_VG_NODEOPENPICTURE_COMPAT
                    ? volvox_grid_set_node_open_picture_native
                    : volvox_grid_set_node_closed_picture_native,
                gid,
                picture,
                picture_len);
            if (picture) HeapFree(GetProcessHeap(), 0, picture);
            return hr;
        }
        break;

    case DISPID_VG_SORTASCENDINGPICTURE_COMPAT:
    case DISPID_VG_SORTDESCENDINGPICTURE_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t picture_len = 0;
            uint8_t *picture;
            HRESULT hrPic;
            if (!pVarResult) return E_POINTER;
            picture = dispIdMember == DISPID_VG_SORTASCENDINGPICTURE_COMPAT
                ? volvox_grid_get_sort_ascending_picture_native(gid, &picture_len)
                : volvox_grid_get_sort_descending_picture_native(gid, &picture_len);
            hrPic = vfg_variant_from_ui1_bytes(pVarResult, picture, picture_len);
            if (picture) volvox_grid_free(picture, picture_len);
            return hrPic;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            uint8_t *picture = NULL;
            int32_t picture_len = 0;
            HRESULT hrPic = vfg_variant_to_png_picture_bytes(NAMED_ARG(0), &picture, &picture_len);
            if (FAILED(hrPic)) return hrPic;
            hr = vfg_set_native_picture_compat(
                dispIdMember == DISPID_VG_SORTASCENDINGPICTURE_COMPAT
                    ? volvox_grid_set_sort_ascending_picture_native
                    : volvox_grid_set_sort_descending_picture_native,
                gid,
                picture,
                picture_len);
            if (picture) HeapFree(GetProcessHeap(), 0, picture);
            return hr;
        }
        break;

    case DISPID_VG_PICTURESOVER_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t enabled;
            if (!pVarResult) return E_POINTER;
            enabled = volvox_grid_get_pictures_over_native(gid);
            V_VT(pVarResult) = VT_BOOL;
            V_BOOL(pVarResult) = enabled ? VARIANT_TRUE : VARIANT_FALSE;
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t enabled = vfg_variant_is_true(NAMED_ARG(0)) ? 1 : 0;
            return volvox_grid_set_pictures_over_native(gid, enabled) == 0 ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_WALLPAPER_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t picture_len = 0;
            uint8_t *picture;
            HRESULT hrPic;
            if (!pVarResult) return E_POINTER;
            picture = volvox_grid_get_wallpaper_native(gid, &picture_len);
            hrPic = vfg_variant_from_ui1_bytes(pVarResult, picture, picture_len);
            if (picture) volvox_grid_free(picture, picture_len);
            return hrPic;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            uint8_t *picture = NULL;
            int32_t picture_len = 0;
            HRESULT hrPic = vfg_variant_to_png_picture_bytes(NAMED_ARG(0), &picture, &picture_len);
            if (FAILED(hrPic)) return hrPic;
            hr = vfg_set_native_picture_compat(
                volvox_grid_set_wallpaper_native,
                gid,
                picture,
                picture_len);
            if (picture) HeapFree(GetProcessHeap(), 0, picture);
            return hr;
        }
        break;

    case DISPID_VG_WALLPAPERALIGNMENT_COMPAT:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = volvox_grid_get_wallpaper_alignment_native(gid);
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t alignment = 0;
            if (SUCCEEDED(variant_to_i4(NAMED_ARG(0), &alignment))) {
                return volvox_grid_set_wallpaper_alignment_native(gid, alignment) == 0
                    ? S_OK
                    : E_FAIL;
            }
            return DISP_E_TYPEMISMATCH;
        }
        break;

    case 53: /* CellFontBold */
        if (wFlags & DISPATCH_PROPERTYGET) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_BOOL;
            V_BOOL(pVarResult) =
                volvox_grid_get_cell_font_bold(gid, row, col) ? VARIANT_TRUE : VARIANT_FALSE;
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            int32_t bold = vfg_variant_is_true(NAMED_ARG(0)) ? 1 : 0;
            return volvox_grid_set_cell_font_bold_range(
                gid, row, col, row, col, bold) == 0 ? S_OK : E_FAIL;
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
            V_VT(pVarResult) = VT_BOOL;
            V_BOOL(pVarResult) =
                volvox_grid_get_is_subtotal(gid, row) ? VARIANT_TRUE : VARIANT_FALSE;
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
            if (obj && row >= 0 && row < obj->is_collapsed_cache_len) {
                V_I4(pVarResult) = obj->is_collapsed_cache[row];
            } else {
                V_I4(pVarResult) = engine_collapsed_to_activex_outline_state(
                    volvox_grid_get_is_collapsed(gid, row));
            }
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t row = 0, state = 0;
            int32_t requested_row = 0;
            if (pDispParams->cArgs >= 2) {
                variant_to_i4(&pDispParams->rgvarg[1], &row);
                variant_to_i4(&pDispParams->rgvarg[0], &state);
            }
            requested_row = row;
            row = vfg_resolve_outline_node_row(gid, row);
            if (obj) {
                vfg_set_cached_indexed_i32(
                    &obj->is_collapsed_cache,
                    &obj->is_collapsed_cache_len,
                    row,
                    state);
                vfg_set_cached_indexed_i32(
                    &obj->is_collapsed_cache,
                    &obj->is_collapsed_cache_len,
                    requested_row,
                    state);
                if (requested_row > 0) {
                    vfg_set_cached_indexed_i32(
                        &obj->is_collapsed_cache,
                        &obj->is_collapsed_cache_len,
                        requested_row - 1,
                        state);
                }
            }
            volvox_grid_set_is_collapsed(
                gid,
                row,
                activex_outline_state_to_engine_collapsed(state));
            return SUCCEEDED(vfg_pump_engine_events(obj)) ? S_OK : E_FAIL;
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

            if (prop == 3) {
                int32_t picture_len = 0;
                uint8_t *picture = volvox_grid_get_cell_picture_native(gid, row1, col1, &picture_len);
                HRESULT hrPic = vfg_variant_from_ui1_bytes(pVarResult, picture, picture_len);
                if (picture) volvox_grid_free(picture, picture_len);
                return hrPic;
            }

            if (prop == 4) {
                V_VT(pVarResult) = VT_I4;
                V_I4(pVarResult) = volvox_grid_get_cell_picture_alignment_native(gid, row1, col1);
                return S_OK;
            }

            if (prop == 6) {
                V_VT(pVarResult) = VT_I4;
                V_I4(pVarResult) =
                    (int32_t)argb_to_olecolor(volvox_grid_get_cell_back_color(gid, row1, col1));
                return S_OK;
            }

            if (prop == 13) {
                V_VT(pVarResult) = VT_BOOL;
                V_BOOL(pVarResult) =
                    volvox_grid_get_cell_font_bold(gid, row1, col1) ? VARIANT_TRUE : VARIANT_FALSE;
                return S_OK;
            }

            if (prop == 19) {
                int32_t out_len = 0;
                uint8_t *utf8 = volvox_grid_get_text_matrix(gid, row1, col1, &out_len);
                return vfg_utf8_bytes_to_variant_bstr(pVarResult, utf8, out_len);
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
            VariantInit(&vtmp);

            if (pDispParams->cArgs >= 2) variant_to_i4(&pDispParams->rgvarg[pDispParams->cArgs - 1], &prop);
            if (pDispParams->cArgs >= 3) variant_to_i4(&pDispParams->rgvarg[pDispParams->cArgs - 2], &row1);
            if (pDispParams->cArgs >= 4) variant_to_i4(&pDispParams->rgvarg[pDispParams->cArgs - 3], &col1);
            if (pDispParams->cArgs >= 5) variant_to_i4(&pDispParams->rgvarg[pDispParams->cArgs - 4], &row2);
            if (pDispParams->cArgs >= 6) variant_to_i4(&pDispParams->rgvarg[pDispParams->cArgs - 5], &col2);

            if (pDispParams->cArgs < 5) row2 = row1;
            if (pDispParams->cArgs < 6) col2 = col1;
            vfg_normalize_cell_rect(gid, &row1, &col1, &row2, &col2);

            if (prop == 0) {
                BSTR text = variant_to_bstr(&pDispParams->rgvarg[0], &vtmp);
                int utf8len = 0;
                char *utf8 = bstr_to_utf8(text, &utf8len);
                vfg_set_cell_text_range(gid, row1, col1, row2, col2, utf8, utf8len);
                if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
            } else if (prop == 3) {
                uint8_t *picture = NULL;
                int32_t picture_len = 0;
                HRESULT hrPic = vfg_variant_to_png_picture_bytes(&pDispParams->rgvarg[0], &picture, &picture_len);
                if (FAILED(hrPic)) {
                    VariantClear(&vtmp);
                    return hrPic;
                }
                hr = vfg_set_cell_picture_range_compat(gid, row1, col1, row2, col2, picture, picture_len);
                if (picture) HeapFree(GetProcessHeap(), 0, picture);
                VariantClear(&vtmp);
                return hr;
            } else if (prop == 4) {
                int32_t alignment = 0;
                if (SUCCEEDED(variant_to_i4(&pDispParams->rgvarg[0], &alignment))) {
                    hr = vfg_set_cell_picture_alignment_range_compat(
                        gid, row1, col1, row2, col2, alignment);
                    VariantClear(&vtmp);
                    return hr;
                }
            } else if (prop == 6) {
                uint32_t color = 0;
                if (SUCCEEDED(variant_to_u32(&pDispParams->rgvarg[0], &color))) {
                    volvox_grid_set_cell_back_color_range(
                        gid, row1, col1, row2, col2, olecolor_to_argb(color));
                }
            } else if (prop == 13) {
                volvox_grid_set_cell_font_bold_range(
                    gid, row1, col1, row2, col2, vfg_variant_is_true(&pDispParams->rgvarg[0]) ? 1 : 0);
            }

            VariantClear(&vtmp);
            return S_OK;
        }
        break;

    /* ── CellChecked(row, col) — 2-index property ────────────── */
    case DISPID_VG_CELLCHECKED:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            if (pDispParams->cArgs > 0) {
                return vfg_raise_vb_error(
                    pExcepInfo,
                    451,
                    L"Property let procedure not defined and property get procedure did not return an object.");
            }
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = engine_checked_to_activex(volvox_grid_get_cell_checked(gid, row, col));
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            int32_t state = 0;
            if (pDispParams->cArgs >= 3) {
                return vfg_raise_vb_error(
                    pExcepInfo,
                    451,
                    L"Property let procedure not defined and property get procedure did not return an object.");
            }
            if (pDispParams->cArgs >= 1) {
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
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            float percent;
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            percent = volvox_grid_get_cell_flood_percent_native(gid, row, col);
            V_I4(pVarResult) = (int32_t)(percent * 100.0f + (percent >= 0.0f ? 0.5f : -0.5f));
            return S_OK;
        }
        break;

    /* ══════════════════════════════════════════════════════════ */
    /* Methods (DISPATCH_METHOD)                                   */
    /* ══════════════════════════════════════════════════════════ */

    case DISPID_VG_OUTLINE_COMPAT:
        if (wFlags & DISPATCH_METHOD) {
            int32_t level = -1;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &level);
            if (volvox_grid_outline(gid, level) != 0) return E_FAIL;
            return vfg_invalidate_control(obj);
        }
        break;

    case DISPID_VG_PRINTGRID_COMPAT:
        if (wFlags & DISPATCH_METHOD) {
            return vfg_print_grid(obj);
        }
        break;

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
            short order_short;
            variant_to_i4(NAMED_ARG(0), &order);
            order_short = (short)order;
            vfg_fire_before_sort_event(obj, sort_col, &order_short);
            order = (int32_t)order_short;
            obj->sort_order_cached = order;
            if (obj->data_source && obj->recordset && sort_col >= 0 &&
                sort_col < vfg_bound_physical_col_offset(obj)) {
                return S_OK;
            }
            volvox_grid_sort(gid, order, sort_col);
            vfg_fire_after_sort_event(obj, sort_col, order);
            return SUCCEEDED(vfg_pump_engine_events(obj)) ? S_OK : E_FAIL;
        }
        if (wFlags & DISPATCH_METHOD) {
            int32_t order = 0, col = 0;
            short order_short;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &order);
            if (pDispParams->cArgs >= 2) variant_to_i4(ARG(1), &col);
            order_short = (short)order;
            vfg_fire_before_sort_event(obj, col, &order_short);
            order = (int32_t)order_short;
            obj->sort_order_cached = order;
            if (obj->data_source && obj->recordset && col >= 0 &&
                col < vfg_bound_physical_col_offset(obj)) {
                return S_OK;
            }
            volvox_grid_sort(gid, order, col);
            vfg_fire_after_sort_event(obj, col, order);
            return SUCCEEDED(vfg_pump_engine_events(obj)) ? S_OK : E_FAIL;
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
            int32_t preserved_cols = 0;
            int32_t *preserved_col_widths = NULL;
            int32_t compat_subtotal_height = 0;
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

            preserved_cols = volvox_grid_get_cols(gid);
            if (preserved_cols > 0) {
                preserved_col_widths = (int32_t *)HeapAlloc(
                    GetProcessHeap(),
                    HEAP_ZERO_MEMORY,
                    sizeof(int32_t) * preserved_cols);
                if (preserved_col_widths) {
                    for (int32_t col = 0; col < preserved_cols; ++col) {
                        preserved_col_widths[col] = volvox_grid_get_col_width(gid, col);
                    }
                }
            }
            compat_subtotal_height =
                vfg_compat_default_row_height_px(volvox_grid_get_font_size(gid));

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
            if (preserved_col_widths) {
                int32_t cols_after = volvox_grid_get_cols(gid);
                int32_t restore_cols = cols_after < preserved_cols ? cols_after : preserved_cols;
                for (int32_t col = 0; col < restore_cols; ++col) {
                    if (preserved_col_widths[col] > 0 &&
                        volvox_grid_get_col_width(gid, col) != preserved_col_widths[col]) {
                        int32_t ignore_len = 0;
                        uint8_t *ignore = vfg_native_set_col_width(
                            gid,
                            col,
                            preserved_col_widths[col],
                            &ignore_len);
                        if (ignore) volvox_grid_free(ignore, ignore_len);
                    }
                }
                HeapFree(GetProcessHeap(), 0, preserved_col_widths);
            }
            if (compat_subtotal_height > 0) {
                int32_t rows = volvox_grid_get_rows(gid);
                for (int32_t subtotal_row = obj ? obj->fixed_rows_cached : 0;
                     subtotal_row < rows;
                     ++subtotal_row) {
                    if (!volvox_grid_get_is_subtotal(gid, subtotal_row)) continue;
                    if (volvox_grid_get_row_height(gid, subtotal_row) != compat_subtotal_height) {
                        int32_t ignore_len = 0;
                        uint8_t *ignore = vfg_native_set_row_height(
                            gid,
                            subtotal_row,
                            compat_subtotal_height,
                            &ignore_len);
                        if (ignore) volvox_grid_free(ignore, ignore_len);
                    }
                    break;
                }
            }
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
            {
                int32_t total_cols = volvox_grid_get_cols(gid);
                if (total_cols > 0) {
                    vfg_apply_unbound_autosize_compat_widths(gid, from, to, equal, max_w);
                }
            }
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
            if (scope == 0) {
                vfg_clear_flood_color_cache(obj);
                vfg_clear_is_collapsed_cache(obj);
            }
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
            vfg_pump_engine_events(obj);
            return S_OK;
        }
        break;

    case DISPID_VG_FINISHEDITING_COMPAT:
        if (wFlags & DISPATCH_METHOD) {
            int32_t out_len = 0;
            if (vfg_take_status_response(volvox_grid_finish_editing(gid, &out_len)) != 0) {
                return E_FAIL;
            }
            return SUCCEEDED(vfg_pump_engine_events(obj))
                ? S_OK
                : E_FAIL;
        }
        break;

    case DISPID_VG_SAVEGRID_COMPAT:
        if (wFlags & DISPATCH_METHOD) {
            VARIANT vpath, vfmt;
            BSTR path = NULL;
            int32_t fmt = 0;
            int32_t out_len = 0;
            uint8_t *resp;
            uint8_t *data;
            int32_t data_len = 0;
            HRESULT hrWrite;
            VariantInit(&vpath);
            VariantInit(&vfmt);
            if (pDispParams->cArgs >= 1) path = variant_to_bstr(ARG(0), &vpath);
            if (pDispParams->cArgs >= 2) variant_to_i4(ARG(1), &fmt);
            resp = volvox_grid_save_grid(gid, fmt, 0, &out_len);
            data = vfg_extract_bytes_field(resp, out_len, 1, &data_len);
            volvox_grid_free(resp, out_len);
            if (!data && out_len > 0) {
                VariantClear(&vfmt);
                VariantClear(&vpath);
                return E_FAIL;
            }
            hrWrite = vfg_write_blob_to_path(path, data, data_len);
            if (data) HeapFree(GetProcessHeap(), 0, data);
            VariantClear(&vfmt);
            VariantClear(&vpath);
            return hrWrite;
        }
        break;

    case DISPID_VG_LOADGRID_COMPAT:
        if (wFlags & DISPATCH_METHOD) {
            VARIANT vpath, vfmt;
            BSTR path = NULL;
            int32_t fmt = 0;
            int32_t data_len = 0;
            uint8_t *data = NULL;
            int32_t out_len = 0;
            VariantInit(&vpath);
            VariantInit(&vfmt);
            if (pDispParams->cArgs >= 1) path = variant_to_bstr(ARG(0), &vpath);
            if (pDispParams->cArgs >= 2) variant_to_i4(ARG(1), &fmt);
            data = vfg_read_blob_from_path(path, &data_len);
            if (!data && path) {
                VariantClear(&vfmt);
                VariantClear(&vpath);
                return E_FAIL;
            }
            hr = vfg_take_status_response(volvox_grid_load_grid(gid, data, data_len, fmt, 0, &out_len)) == 0
                ? S_OK
                : E_FAIL;
            if (data) HeapFree(GetProcessHeap(), 0, data);
            VariantClear(&vfmt);
            VariantClear(&vpath);
            return hr;
        }
        break;

    case DISPID_VG_LOADGRIDURL_COMPAT:
        if (wFlags & DISPATCH_METHOD) {
            VARIANT vurl, vfmt;
            BSTR url = NULL;
            int32_t fmt = 0;
            int utf8len = 0;
            char *utf8 = NULL;
            int32_t out_len = 0;
            VariantInit(&vurl);
            VariantInit(&vfmt);
            if (pDispParams->cArgs >= 1) url = variant_to_bstr(ARG(0), &vurl);
            if (pDispParams->cArgs >= 2) variant_to_i4(ARG(1), &fmt);
            utf8 = bstr_to_utf8(url, &utf8len);
            hr = vfg_take_status_response(volvox_grid_load_grid_url(
                gid,
                (const uint8_t *)(utf8 ? utf8 : ""),
                utf8 ? utf8len : 0,
                NULL,
                0,
                fmt,
                0,
                &out_len)) == 0 ? S_OK : E_FAIL;
            if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
            VariantClear(&vfmt);
            VariantClear(&vurl);
            return hr;
        }
        break;

    case DISPID_VG_EDITCELL:
        if (wFlags & DISPATCH_METHOD) {
            int32_t row = volvox_grid_get_row(gid);
            int32_t col = volvox_grid_get_col(gid);
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &row);
            if (pDispParams->cArgs >= 2) variant_to_i4(ARG(1), &col);
            return volvox_grid_edit_cell(gid, row, col) == 0 && SUCCEEDED(vfg_pump_engine_events(obj))
                ? S_OK
                : E_FAIL;
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
            return SUCCEEDED(vfg_handle_pointer_down(obj, x, y, button, modifier, dbl_click))
                ? S_OK : E_FAIL;
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
            return SUCCEEDED(vfg_handle_pointer_move(obj, x, y, button, modifier)) ? S_OK : E_FAIL;
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
            return SUCCEEDED(vfg_handle_pointer_up(obj, x, y, button, modifier)) ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_SCROLL:
        if (wFlags & DISPATCH_METHOD) {
            float delta_x = 0.0f, delta_y = 0.0f;
            if (pDispParams->cArgs >= 1) variant_to_float(ARG(0), &delta_x);
            if (pDispParams->cArgs >= 2) variant_to_float(ARG(1), &delta_y);
            if (volvox_grid_scroll_native(gid, delta_x, delta_y) != 0) return E_FAIL;
            return SUCCEEDED(vfg_pump_engine_events(obj)) ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_KEYDOWN:
        if (wFlags & DISPATCH_METHOD) {
            int32_t key_code = 0, modifier = 0;
            int32_t status = 0;
            int editing_active = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &key_code);
            if (pDispParams->cArgs >= 2) variant_to_i4(ARG(1), &modifier);
            if ((modifier & 2) && !(modifier & 4)) {
                editing_active = vfg_query_edit_active(gid);
                switch (key_code) {
                case 67:
                    status = editing_active
                        ? vfg_copy_or_cut_active_edit(gid, FALSE)
                        : vfg_copy_or_cut_grid_selection(gid, FALSE);
                    return status == 0 ? S_OK : E_FAIL;
                case 88:
                    status = editing_active
                        ? vfg_copy_or_cut_active_edit(gid, TRUE)
                        : vfg_copy_or_cut_grid_selection(gid, TRUE);
                    return status == 0 ? S_OK : E_FAIL;
                case 86:
                    status = editing_active
                        ? vfg_paste_active_edit_from_clipboard(gid)
                        : vfg_paste_grid_selection_from_clipboard(gid);
                    return status == 0 ? S_OK : E_FAIL;
                default:
                    break;
                }
            }
            return SUCCEEDED(vfg_handle_key_down(obj, key_code, modifier)) ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_CUT_COMPAT:
    case DISPID_VG_COPY_COMPAT:
    case DISPID_VG_PASTE_COMPAT:
    case DISPID_VG_DELETE_COMPAT:
        if (wFlags & DISPATCH_METHOD) {
            int32_t status = 0;
            int editing_active = vfg_query_edit_active(gid);
            if (dispIdMember == DISPID_VG_COPY_COMPAT) {
                status = editing_active
                    ? vfg_copy_or_cut_active_edit(gid, FALSE)
                    : vfg_copy_or_cut_grid_selection(gid, FALSE);
            } else if (dispIdMember == DISPID_VG_CUT_COMPAT) {
                status = editing_active
                    ? vfg_copy_or_cut_active_edit(gid, TRUE)
                    : vfg_copy_or_cut_grid_selection(gid, TRUE);
            } else if (dispIdMember == DISPID_VG_PASTE_COMPAT) {
                status = editing_active
                    ? vfg_paste_active_edit_from_clipboard(gid)
                    : vfg_paste_grid_selection_from_clipboard(gid);
            } else {
                int32_t out_len = 0;
                status = vfg_take_status_response(volvox_grid_delete(gid, &out_len));
            }
            return status == 0 ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_KEYPRESS:
        if (wFlags & DISPATCH_METHOD) {
            int32_t char_code = 0;
            if (pDispParams->cArgs >= 1) variant_to_i4(ARG(0), &char_code);
            return SUCCEEDED(vfg_handle_key_press(obj, (uint32_t)char_code)) ? S_OK : E_FAIL;
        }
        break;

    case DISPID_VG_IMECOMPOSITION:
        if (wFlags & DISPATCH_METHOD) {
            BSTR text = NULL;
            VARIANT vtext;
            int32_t cursor = 0;
            int32_t commit = 0;
            int32_t status;
            int utf8len = 0;
            char *utf8;

            VariantInit(&vtext);
            if (pDispParams->cArgs >= 1) text = variant_to_bstr(ARG(0), &vtext);
            if (pDispParams->cArgs >= 2) variant_to_i4(ARG(1), &cursor);
            if (pDispParams->cArgs >= 3) variant_to_i4(ARG(2), &commit);

            if (!commit && text && SysStringLen(text) > 0 && !vfg_query_edit_active(gid)) {
                int32_t row = volvox_grid_get_row(gid);
                int32_t col = volvox_grid_get_col(gid);
                status = volvox_grid_edit_cell(gid, row, col);
                if (status != 0) {
                    VariantClear(&vtext);
                    return E_FAIL;
                }
            }

            utf8 = bstr_to_utf8(text, &utf8len);
            status = vfg_set_preedit_compat(gid, utf8, utf8len, cursor, commit);
            if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
            VariantClear(&vtext);
            return status == 0 ? S_OK : E_FAIL;
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

    hr = vfg_try_public_dispatch_fallback(obj, dispIdMember, wFlags, pDispParams, pVarResult);
    if (hr != DISP_E_MEMBERNOTFOUND) {
        return hr;
    }

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
    return volvox_grid_paint_to_hdc_native(
        OBJ_FROM_VIEWOBJECT(This)->grid_id,
        hdcDraw,
        lprcBounds->left,
        lprcBounds->top,
        lprcBounds->right - lprcBounds->left,
        lprcBounds->bottom - lprcBounds->top,
        (int32_t)dwDrawAspect);
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

static HRESULT STDMETHODCALLTYPE VFG_VO2_QueryInterface(
    IViewObject2 *This, REFIID riid, void **ppv)
{
    VolvoxGridObject *obj = OBJ_FROM_VIEWOBJECT2(This);
    return VFG_QueryInterface((IDispatch *)obj, riid, ppv);
}

static ULONG STDMETHODCALLTYPE VFG_VO2_AddRef(IViewObject2 *This) {
    VolvoxGridObject *obj = OBJ_FROM_VIEWOBJECT2(This);
    return InterlockedIncrement(&obj->cRef);
}

static ULONG STDMETHODCALLTYPE VFG_VO2_Release(IViewObject2 *This) {
    VolvoxGridObject *obj = OBJ_FROM_VIEWOBJECT2(This);
    return VFG_Release((IDispatch *)obj);
}

static HRESULT STDMETHODCALLTYPE VFG_VO2_Draw(
    IViewObject2 *This,
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
    return volvox_grid_paint_to_hdc_native(
        OBJ_FROM_VIEWOBJECT2(This)->grid_id,
        hdcDraw,
        lprcBounds->left,
        lprcBounds->top,
        lprcBounds->right - lprcBounds->left,
        lprcBounds->bottom - lprcBounds->top,
        (int32_t)dwDrawAspect);
}

static HRESULT STDMETHODCALLTYPE VFG_VO2_GetColorSet(
    IViewObject2 *This, DWORD a, LONG b, void *c, DVTARGETDEVICE *d,
    HDC e, LOGPALETTE **f)
{
    (void)This;(void)a;(void)b;(void)c;(void)d;(void)e;(void)f;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE VFG_VO2_Freeze(
    IViewObject2 *This, DWORD a, LONG b, void *c, DWORD *d)
{
    (void)This;(void)a;(void)b;(void)c;(void)d;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE VFG_VO2_Unfreeze(
    IViewObject2 *This, DWORD a)
{
    (void)This;(void)a;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE VFG_VO2_SetAdvise(
    IViewObject2 *This, DWORD a, DWORD b, IAdviseSink *c)
{
    (void)This;(void)a;(void)b;(void)c;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE VFG_VO2_GetAdvise(
    IViewObject2 *This, DWORD *a, DWORD *b, IAdviseSink **c)
{
    (void)This;(void)a;(void)b;(void)c;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE VFG_VO2_GetExtent(
    IViewObject2 *This,
    DWORD dwDrawAspect,
    LONG lindex,
    DVTARGETDEVICE *ptd,
    LPSIZEL lpsizel)
{
    VolvoxGridObject *obj = OBJ_FROM_VIEWOBJECT2(This);
    int32_t cx = 0;
    int32_t cy = 0;
    (void)lindex; (void)ptd;
    if (!lpsizel) return E_POINTER;
    if (dwDrawAspect != DVASPECT_CONTENT) return DV_E_DVASPECT;
    if (volvox_grid_get_extent_himetric_native(obj->grid_id, &cx, &cy) == S_OK) {
        lpsizel->cx = cx;
        lpsizel->cy = cy;
    } else {
        *lpsizel = obj->extent_himetric;
    }
    return S_OK;
}

/* ── IOleObject / In-Place / Control / Persist ──────────────── */

static HRESULT STDMETHODCALLTYPE VFG_OO_QueryInterface(
    IOleObject *This, REFIID riid, void **ppv)
{
    return VFG_QueryInterface((IDispatch *)OBJ_FROM_OLEOBJECT(This), riid, ppv);
}

static ULONG STDMETHODCALLTYPE VFG_OO_AddRef(IOleObject *This) {
    return VFG_AddRef((IDispatch *)OBJ_FROM_OLEOBJECT(This));
}

static ULONG STDMETHODCALLTYPE VFG_OO_Release(IOleObject *This) {
    return VFG_Release((IDispatch *)OBJ_FROM_OLEOBJECT(This));
}

static HRESULT STDMETHODCALLTYPE VFG_OO_SetClientSite(IOleObject *This, IOleClientSite *pClientSite) {
    VolvoxGridObject *obj = OBJ_FROM_OLEOBJECT(This);
    if (obj->client_site) {
        IOleClientSite_Release(obj->client_site);
        obj->client_site = NULL;
    }
    if (obj->inplace_site) {
        IOleInPlaceSite_Release(obj->inplace_site);
        obj->inplace_site = NULL;
    }
    if (pClientSite) {
        IOleClientSite_AddRef(pClientSite);
        obj->client_site = pClientSite;
    }
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_OO_GetClientSite(IOleObject *This, IOleClientSite **ppClientSite) {
    VolvoxGridObject *obj = OBJ_FROM_OLEOBJECT(This);
    if (!ppClientSite) return E_POINTER;
    *ppClientSite = obj->client_site;
    if (*ppClientSite) IOleClientSite_AddRef(*ppClientSite);
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_OO_SetHostNames(
    IOleObject *This, LPCOLESTR szContainerApp, LPCOLESTR szContainerObj)
{
    VolvoxGridObject *obj = OBJ_FROM_OLEOBJECT(This);
    vfg_set_olestr_copy(&obj->host_app_name, szContainerApp);
    vfg_set_olestr_copy(&obj->host_obj_name, szContainerObj);
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_OO_Close(IOleObject *This, DWORD dwSaveOption) {
    (void)dwSaveOption;
    return vfg_deactivate_in_place(OBJ_FROM_OLEOBJECT(This));
}

static HRESULT STDMETHODCALLTYPE VFG_OO_SetMoniker(
    IOleObject *This, DWORD dwWhichMoniker, IMoniker *pmk)
{
    (void)This; (void)dwWhichMoniker; (void)pmk;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE VFG_OO_GetMoniker(
    IOleObject *This, DWORD dwAssign, DWORD dwWhichMoniker, IMoniker **ppmk)
{
    (void)This; (void)dwAssign; (void)dwWhichMoniker;
    if (ppmk) *ppmk = NULL;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE VFG_OO_InitFromData(
    IOleObject *This, IDataObject *pDataObject, BOOL fCreation, DWORD dwReserved)
{
    (void)fCreation; (void)dwReserved;
    return vfg_paste_unicode_data_object(OBJ_FROM_OLEOBJECT(This), pDataObject);
}

static HRESULT STDMETHODCALLTYPE VFG_OO_GetClipboardData(
    IOleObject *This, DWORD dwReserved, IDataObject **ppDataObject)
{
    VolvoxGridObject *obj = OBJ_FROM_OLEOBJECT(This);
    (void)dwReserved;
    if (!ppDataObject) return E_POINTER;
    *ppDataObject = (IDataObject *)&obj->lpVtblDataObject;
    VFG_AddRef((IDispatch *)obj);
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_OO_DoVerb(
    IOleObject *This,
    LONG iVerb,
    LPMSG lpmsg,
    IOleClientSite *pActiveSite,
    LONG lindex,
    HWND hwndParent,
    LPCRECT lprcPosRect)
{
    (void)lpmsg; (void)lindex;
    if (pActiveSite) {
        VFG_OO_SetClientSite(This, pActiveSite);
    }
    switch (iVerb) {
    case OLEIVERB_SHOW:
    case OLEIVERB_PRIMARY:
    case OLEIVERB_INPLACEACTIVATE:
        return vfg_activate_in_place(OBJ_FROM_OLEOBJECT(This), hwndParent, lprcPosRect, FALSE);
    case OLEIVERB_UIACTIVATE:
        return vfg_activate_in_place(OBJ_FROM_OLEOBJECT(This), hwndParent, lprcPosRect, TRUE);
    case OLEIVERB_HIDE:
        return vfg_deactivate_in_place(OBJ_FROM_OLEOBJECT(This));
    default:
        return OLEOBJ_S_INVALIDVERB;
    }
}

static HRESULT STDMETHODCALLTYPE VFG_OO_EnumVerbs(IOleObject *This, IEnumOLEVERB **ppEnumOleVerb) {
    (void)This;
    if (ppEnumOleVerb) *ppEnumOleVerb = NULL;
    return OLE_S_USEREG;
}

static HRESULT STDMETHODCALLTYPE VFG_OO_Update(IOleObject *This) {
    (void)This;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_OO_IsUpToDate(IOleObject *This) {
    (void)This;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_OO_GetUserClassID(IOleObject *This, CLSID *pClsid) {
    (void)This;
    if (!pClsid) return E_POINTER;
    *pClsid = CLSID_VolvoxGrid;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_OO_GetUserType(
    IOleObject *This, DWORD dwFormOfType, LPOLESTR *pszUserType)
{
    (void)This; (void)dwFormOfType;
    if (!pszUserType) return E_POINTER;
    *pszUserType = (LPOLESTR)CoTaskMemAlloc(32 * sizeof(WCHAR));
    if (!*pszUserType) return E_OUTOFMEMORY;
    lstrcpyW(*pszUserType, L"VolvoxGrid Control");
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_OO_SetExtent(
    IOleObject *This, DWORD dwDrawAspect, SIZEL *psizel)
{
    VolvoxGridObject *obj = OBJ_FROM_OLEOBJECT(This);
    (void)dwDrawAspect;
    if (!psizel) return E_POINTER;
    obj->extent_himetric = *psizel;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_OO_GetExtent(
    IOleObject *This, DWORD dwDrawAspect, SIZEL *psizel)
{
    VolvoxGridObject *obj = OBJ_FROM_OLEOBJECT(This);
    (void)dwDrawAspect;
    if (!psizel) return E_POINTER;
    *psizel = obj->extent_himetric;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_OO_Advise(
    IOleObject *This, IAdviseSink *pAdvSink, DWORD *pdwConnection)
{
    (void)This; (void)pAdvSink;
    if (pdwConnection) *pdwConnection = 0;
    return OLE_E_ADVISENOTSUPPORTED;
}

static HRESULT STDMETHODCALLTYPE VFG_OO_Unadvise(IOleObject *This, DWORD dwConnection) {
    (void)This; (void)dwConnection;
    return OLE_E_ADVISENOTSUPPORTED;
}

static HRESULT STDMETHODCALLTYPE VFG_OO_EnumAdvise(IOleObject *This, IEnumSTATDATA **ppenumAdvise) {
    (void)This;
    if (ppenumAdvise) *ppenumAdvise = NULL;
    return OLE_E_ADVISENOTSUPPORTED;
}

static HRESULT STDMETHODCALLTYPE VFG_OO_GetMiscStatus(
    IOleObject *This, DWORD dwAspect, DWORD *pdwStatus)
{
    (void)This; (void)dwAspect;
    if (!pdwStatus) return E_POINTER;
    *pdwStatus = OLEMISC_RECOMPOSEONRESIZE | OLEMISC_INSIDEOUT |
        OLEMISC_ACTIVATEWHENVISIBLE | OLEMISC_SETCLIENTSITEFIRST |
        OLEMISC_CANTLINKINSIDE;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_OO_SetColorScheme(IOleObject *This, LOGPALETTE *pLogpal) {
    (void)This; (void)pLogpal;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_IPO_QueryInterface(
    IOleInPlaceObject *This, REFIID riid, void **ppv)
{
    return VFG_QueryInterface((IDispatch *)OBJ_FROM_INPLACEOBJECT(This), riid, ppv);
}

static ULONG STDMETHODCALLTYPE VFG_IPO_AddRef(IOleInPlaceObject *This) {
    return VFG_AddRef((IDispatch *)OBJ_FROM_INPLACEOBJECT(This));
}

static ULONG STDMETHODCALLTYPE VFG_IPO_Release(IOleInPlaceObject *This) {
    return VFG_Release((IDispatch *)OBJ_FROM_INPLACEOBJECT(This));
}

static HRESULT STDMETHODCALLTYPE VFG_IPO_GetWindow(IOleInPlaceObject *This, HWND *phwnd) {
    VolvoxGridObject *obj = OBJ_FROM_INPLACEOBJECT(This);
    if (!phwnd) return E_POINTER;
    *phwnd = obj->hwnd_ctrl;
    return obj->hwnd_ctrl ? S_OK : E_FAIL;
}

static HRESULT STDMETHODCALLTYPE VFG_IPO_ContextSensitiveHelp(IOleInPlaceObject *This, BOOL fEnterMode) {
    (void)This; (void)fEnterMode;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_IPO_InPlaceDeactivate(IOleInPlaceObject *This) {
    return vfg_deactivate_in_place(OBJ_FROM_INPLACEOBJECT(This));
}

static HRESULT STDMETHODCALLTYPE VFG_IPO_UIDeactivate(IOleInPlaceObject *This) {
    VolvoxGridObject *obj = OBJ_FROM_INPLACEOBJECT(This);
    if (obj->ui_active && obj->inplace_site) {
        IOleInPlaceSite_OnUIDeactivate(obj->inplace_site, FALSE);
        obj->ui_active = 0;
    }
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_IPO_SetObjectRects(
    IOleInPlaceObject *This, LPCRECT lprcPosRect, LPCRECT lprcClipRect)
{
    VolvoxGridObject *obj = OBJ_FROM_INPLACEOBJECT(This);
    if (lprcPosRect) obj->pos_rect = *lprcPosRect;
    if (lprcClipRect) obj->clip_rect = *lprcClipRect;
    return vfg_resize_control_window(obj);
}

static HRESULT STDMETHODCALLTYPE VFG_IPO_ReactivateAndUndo(IOleInPlaceObject *This) {
    (void)This;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE VFG_IPAO_QueryInterface(
    IOleInPlaceActiveObject *This, REFIID riid, void **ppv)
{
    return VFG_QueryInterface((IDispatch *)OBJ_FROM_INPLACEACTIVEOBJECT(This), riid, ppv);
}

static ULONG STDMETHODCALLTYPE VFG_IPAO_AddRef(IOleInPlaceActiveObject *This) {
    return VFG_AddRef((IDispatch *)OBJ_FROM_INPLACEACTIVEOBJECT(This));
}

static ULONG STDMETHODCALLTYPE VFG_IPAO_Release(IOleInPlaceActiveObject *This) {
    return VFG_Release((IDispatch *)OBJ_FROM_INPLACEACTIVEOBJECT(This));
}

static HRESULT STDMETHODCALLTYPE VFG_IPAO_GetWindow(IOleInPlaceActiveObject *This, HWND *phwnd) {
    VolvoxGridObject *obj = OBJ_FROM_INPLACEACTIVEOBJECT(This);
    if (!phwnd) return E_POINTER;
    *phwnd = obj->hwnd_ctrl;
    return obj->hwnd_ctrl ? S_OK : E_FAIL;
}

static HRESULT STDMETHODCALLTYPE VFG_IPAO_ContextSensitiveHelp(IOleInPlaceActiveObject *This, BOOL fEnterMode) {
    (void)This; (void)fEnterMode;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_IPAO_TranslateAccelerator(IOleInPlaceActiveObject *This, LPMSG lpmsg) {
    VolvoxGridObject *obj = OBJ_FROM_INPLACEACTIVEOBJECT(This);
    UINT msg;
    if (!obj || !lpmsg || !obj->hwnd_ctrl) return S_FALSE;
    msg = lpmsg->message;
    if ((msg == WM_KEYDOWN || msg == WM_SYSKEYDOWN) &&
        lpmsg->wParam == VK_TAB &&
        volvox_grid_get_tab_behavior_native(obj->grid_id) == 1) {
        SendMessageW(obj->hwnd_ctrl, WM_KEYDOWN, lpmsg->wParam, lpmsg->lParam);
        return S_OK;
    }
    return S_FALSE;
}

static HRESULT STDMETHODCALLTYPE VFG_IPAO_OnFrameWindowActivate(IOleInPlaceActiveObject *This, BOOL fActivate) {
    (void)This; (void)fActivate;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_IPAO_OnDocWindowActivate(IOleInPlaceActiveObject *This, BOOL fActivate) {
    (void)This; (void)fActivate;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_IPAO_ResizeBorder(
    IOleInPlaceActiveObject *This, LPCRECT prcBorder, IOleInPlaceUIWindow *pUIWindow, BOOL fFrameWindow)
{
    (void)This; (void)prcBorder; (void)pUIWindow; (void)fFrameWindow;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_IPAO_EnableModeless(IOleInPlaceActiveObject *This, BOOL fEnable) {
    (void)This; (void)fEnable;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_OC_QueryInterface(
    IOleControl *This, REFIID riid, void **ppv)
{
    return VFG_QueryInterface((IDispatch *)OBJ_FROM_OLECONTROL(This), riid, ppv);
}

static ULONG STDMETHODCALLTYPE VFG_OC_AddRef(IOleControl *This) {
    return VFG_AddRef((IDispatch *)OBJ_FROM_OLECONTROL(This));
}

static ULONG STDMETHODCALLTYPE VFG_OC_Release(IOleControl *This) {
    return VFG_Release((IDispatch *)OBJ_FROM_OLECONTROL(This));
}

static HRESULT STDMETHODCALLTYPE VFG_OC_GetControlInfo(IOleControl *This, CONTROLINFO *pCI) {
    (void)This;
    if (!pCI) return E_POINTER;
    memset(pCI, 0, sizeof(*pCI));
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_OC_OnMnemonic(IOleControl *This, LPMSG pMsg) {
    (void)This; (void)pMsg;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_OC_OnAmbientPropertyChange(IOleControl *This, DISPID dispID) {
    (void)This; (void)dispID;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_OC_FreezeEvents(IOleControl *This, BOOL bFreeze) {
    VolvoxGridObject *obj = OBJ_FROM_OLECONTROL(This);
    obj->frozen_events = bFreeze ? 1 : 0;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_PSI_QueryInterface(
    IPersistStreamInit *This, REFIID riid, void **ppv)
{
    return VFG_QueryInterface((IDispatch *)OBJ_FROM_PERSISTSTREAMINIT(This), riid, ppv);
}

static ULONG STDMETHODCALLTYPE VFG_PSI_AddRef(IPersistStreamInit *This) {
    return VFG_AddRef((IDispatch *)OBJ_FROM_PERSISTSTREAMINIT(This));
}

static ULONG STDMETHODCALLTYPE VFG_PSI_Release(IPersistStreamInit *This) {
    return VFG_Release((IDispatch *)OBJ_FROM_PERSISTSTREAMINIT(This));
}

static HRESULT STDMETHODCALLTYPE VFG_PSI_GetClassID(IPersistStreamInit *This, CLSID *pClassID) {
    (void)This;
    if (!pClassID) return E_POINTER;
    *pClassID = CLSID_VolvoxGrid;
    return S_OK;
}

static HRESULT vfg_stream_write_exact(IStream *stream, const void *data, ULONG len) {
    ULONG written = 0;
    HRESULT hr;
    if (!stream) return E_POINTER;
    hr = IStream_Write(stream, data, len, &written);
    if (FAILED(hr)) return hr;
    return written == len ? S_OK : STG_E_WRITEFAULT;
}

static HRESULT vfg_stream_read_exact(IStream *stream, void *data, ULONG len) {
    ULONG read = 0;
    HRESULT hr;
    if (!stream) return E_POINTER;
    hr = IStream_Read(stream, data, len, &read);
    if (FAILED(hr)) return hr;
    return read == len ? S_OK : STG_E_READFAULT;
}

static HRESULT vfg_stream_write_u32(IStream *stream, uint32_t value) {
    return vfg_stream_write_exact(stream, &value, sizeof(value));
}

static HRESULT vfg_stream_read_u32(IStream *stream, uint32_t *value) {
    if (!value) return E_POINTER;
    return vfg_stream_read_exact(stream, value, sizeof(*value));
}

static HRESULT vfg_stream_write_i32(IStream *stream, int32_t value) {
    return vfg_stream_write_exact(stream, &value, sizeof(value));
}

static HRESULT vfg_stream_read_i32(IStream *stream, int32_t *value) {
    if (!value) return E_POINTER;
    return vfg_stream_read_exact(stream, value, sizeof(*value));
}

static HRESULT vfg_persist_write_text_cell(
    VolvoxGridObject *obj, IStream *stream, int32_t row, int32_t col)
{
    int32_t len = 0;
    uint8_t *utf8 = volvox_grid_get_text_matrix(obj->grid_id, row, col, &len);
    uint32_t ulen = (utf8 && len > 0) ? (uint32_t)len : 0;
    HRESULT hr = vfg_stream_write_u32(stream, ulen);
    if (SUCCEEDED(hr) && ulen > 0) {
        hr = vfg_stream_write_exact(stream, utf8, ulen);
    }
    if (utf8) volvox_grid_free(utf8, len);
    return hr;
}

static HRESULT vfg_persist_save(VolvoxGridObject *obj, IStream *stream) {
    static const char magic[4] = { 'V', 'F', 'G', '1' };
    int32_t rows;
    int32_t cols;
    uint32_t cell_count;
    HRESULT hr;

    if (!obj || !stream) return E_POINTER;
    rows = volvox_grid_get_rows(obj->grid_id);
    cols = volvox_grid_get_cols(obj->grid_id);
    if (rows < 0) rows = 0;
    if (cols < 0) cols = 0;
    cell_count = (uint32_t)((uint64_t)(uint32_t)rows * (uint64_t)(uint32_t)cols);

    hr = vfg_stream_write_exact(stream, magic, sizeof(magic));
    if (FAILED(hr)) return hr;
    if (FAILED(hr = vfg_stream_write_u32(stream, 1))) return hr;
    if (FAILED(hr = vfg_stream_write_i32(stream, rows))) return hr;
    if (FAILED(hr = vfg_stream_write_i32(stream, cols))) return hr;
    if (FAILED(hr = vfg_stream_write_i32(stream, obj->fixed_rows_cached))) return hr;
    if (FAILED(hr = vfg_stream_write_i32(stream, obj->fixed_cols_cached))) return hr;
    if (FAILED(hr = vfg_stream_write_i32(stream, obj->frozen_rows_cached))) return hr;
    if (FAILED(hr = vfg_stream_write_i32(stream, obj->frozen_cols_cached))) return hr;
    if (FAILED(hr = vfg_stream_write_i32(stream, volvox_grid_get_row(obj->grid_id)))) return hr;
    if (FAILED(hr = vfg_stream_write_i32(stream, vfg_get_col_cached(obj->grid_id)))) return hr;
    if (FAILED(hr = vfg_stream_write_i32(stream, obj->row_sel_cached))) return hr;
    if (FAILED(hr = vfg_stream_write_i32(stream, obj->col_sel_cached))) return hr;
    if (FAILED(hr = vfg_stream_write_i32(stream, volvox_grid_get_top_row(obj->grid_id)))) return hr;
    if (FAILED(hr = vfg_stream_write_i32(stream, vfg_get_left_col_cached(obj->grid_id)))) return hr;
    if (FAILED(hr = vfg_stream_write_u32(stream, cell_count))) return hr;

    for (int32_t r = 0; r < rows; ++r) {
        for (int32_t c = 0; c < cols; ++c) {
            hr = vfg_persist_write_text_cell(obj, stream, r, c);
            if (FAILED(hr)) return hr;
        }
    }
    return S_OK;
}

static HRESULT vfg_persist_load_text_cell(
    VolvoxGridObject *obj, IStream *stream, int32_t row, int32_t col)
{
    uint32_t len = 0;
    uint8_t *buf = NULL;
    HRESULT hr = vfg_stream_read_u32(stream, &len);
    if (FAILED(hr)) return hr;
    if (len > 16 * 1024 * 1024) return STG_E_INVALIDHEADER;
    if (len > 0) {
        buf = (uint8_t *)HeapAlloc(GetProcessHeap(), 0, len);
        if (!buf) return E_OUTOFMEMORY;
        hr = vfg_stream_read_exact(stream, buf, len);
        if (FAILED(hr)) {
            HeapFree(GetProcessHeap(), 0, buf);
            return hr;
        }
    }
    volvox_grid_set_text_matrix(
        obj->grid_id, row, col, buf ? buf : (const uint8_t *)"", (int32_t)len);
    if (buf) HeapFree(GetProcessHeap(), 0, buf);
    return S_OK;
}

static HRESULT vfg_persist_load(VolvoxGridObject *obj, IStream *stream) {
    char magic[4];
    uint32_t version = 0;
    uint32_t cell_count = 0;
    uint64_t expected_count;
    int32_t rows = 0;
    int32_t cols = 0;
    int32_t fixed_rows = 0;
    int32_t fixed_cols = 0;
    int32_t frozen_rows = 0;
    int32_t frozen_cols = 0;
    int32_t row = 0;
    int32_t col = 0;
    int32_t row_sel = 0;
    int32_t col_sel = 0;
    int32_t top_row = 0;
    int32_t left_col = 0;
    HRESULT hr;

    if (!obj || !stream) return E_POINTER;
    if (FAILED(hr = vfg_stream_read_exact(stream, magic, sizeof(magic)))) return hr;
    if (memcmp(magic, "VFG1", 4) != 0) return STG_E_INVALIDHEADER;
    if (FAILED(hr = vfg_stream_read_u32(stream, &version))) return hr;
    if (version != 1) return STG_E_INVALIDHEADER;
    if (FAILED(hr = vfg_stream_read_i32(stream, &rows))) return hr;
    if (FAILED(hr = vfg_stream_read_i32(stream, &cols))) return hr;
    if (rows < 0 || cols < 0 || rows > 1000000 || cols > 100000) return STG_E_INVALIDHEADER;
    expected_count = (uint64_t)(uint32_t)rows * (uint64_t)(uint32_t)cols;
    if (expected_count > 10000000ULL) return STG_E_INVALIDHEADER;

    if (FAILED(hr = vfg_stream_read_i32(stream, &fixed_rows))) return hr;
    if (FAILED(hr = vfg_stream_read_i32(stream, &fixed_cols))) return hr;
    if (FAILED(hr = vfg_stream_read_i32(stream, &frozen_rows))) return hr;
    if (FAILED(hr = vfg_stream_read_i32(stream, &frozen_cols))) return hr;
    if (FAILED(hr = vfg_stream_read_i32(stream, &row))) return hr;
    if (FAILED(hr = vfg_stream_read_i32(stream, &col))) return hr;
    if (FAILED(hr = vfg_stream_read_i32(stream, &row_sel))) return hr;
    if (FAILED(hr = vfg_stream_read_i32(stream, &col_sel))) return hr;
    if (FAILED(hr = vfg_stream_read_i32(stream, &top_row))) return hr;
    if (FAILED(hr = vfg_stream_read_i32(stream, &left_col))) return hr;
    if (FAILED(hr = vfg_stream_read_u32(stream, &cell_count))) return hr;
    if ((uint64_t)cell_count != expected_count) return STG_E_INVALIDHEADER;

    volvox_grid_set_rows(obj->grid_id, rows);
    volvox_grid_set_cols(obj->grid_id, cols);
    volvox_grid_set_fixed_rows(obj->grid_id, fixed_rows);
    volvox_grid_set_fixed_cols(obj->grid_id, fixed_cols);
    obj->fixed_rows_cached = fixed_rows;
    obj->fixed_cols_cached = fixed_cols;
    volvox_grid_set_frozen_rows(obj->grid_id, frozen_rows);
    volvox_grid_set_frozen_cols(obj->grid_id, frozen_cols);
    obj->frozen_rows_cached = frozen_rows;
    obj->frozen_cols_cached = frozen_cols;

    for (int32_t r = 0; r < rows; ++r) {
        for (int32_t c = 0; c < cols; ++c) {
            hr = vfg_persist_load_text_cell(obj, stream, r, c);
            if (FAILED(hr)) return hr;
        }
    }

    volvox_grid_set_row(obj->grid_id, row);
    volvox_grid_set_col(obj->grid_id, col);
    volvox_grid_set_row_sel(obj->grid_id, row_sel);
    volvox_grid_set_col_sel(obj->grid_id, col_sel);
    obj->row_sel_cached = row_sel;
    obj->col_sel_cached = col_sel;
    volvox_grid_set_top_row(obj->grid_id, top_row);
    volvox_grid_set_left_col(obj->grid_id, left_col);
    obj->dirty = 0;
    return S_OK;
}

int32_t volvox_grid_save_ole_stream_native(
    int64_t id,
    volvox_grid_stream_write_fn write_fn,
    void *ctx)
{
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(id);
    IStream *stream = NULL;
    HGLOBAL hglobal = NULL;
    STATSTG statstg;
    void *bytes = NULL;
    HRESULT hr;
    if (!obj || !write_fn) return E_POINTER;
    memset(&statstg, 0, sizeof(statstg));
    hr = CreateStreamOnHGlobal(NULL, TRUE, &stream);
    if (FAILED(hr)) return hr;
    hr = vfg_persist_save(obj, stream);
    if (FAILED(hr)) goto done;
    hr = IStream_Stat(stream, &statstg, STATFLAG_NONAME);
    if (FAILED(hr)) goto done;
    if (statstg.cbSize.HighPart != 0 || statstg.cbSize.LowPart > INT32_MAX) {
        hr = STG_E_MEDIUMFULL;
        goto done;
    }
    hr = GetHGlobalFromStream(stream, &hglobal);
    if (FAILED(hr)) goto done;
    if (statstg.cbSize.LowPart > 0) {
        bytes = GlobalLock(hglobal);
        if (!bytes) {
            hr = E_OUTOFMEMORY;
            goto done;
        }
        if (write_fn(ctx, (const uint8_t *)bytes, (int32_t)statstg.cbSize.LowPart) !=
            (int32_t)statstg.cbSize.LowPart) {
            hr = STG_E_WRITEFAULT;
        }
    }

done:
    if (bytes) GlobalUnlock(hglobal);
    if (stream) IStream_Release(stream);
    return hr;
}

int32_t volvox_grid_load_ole_stream_native(
    int64_t id,
    volvox_grid_stream_read_fn read_fn,
    void *ctx)
{
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(id);
    IStream *stream = NULL;
    LARGE_INTEGER zero;
    uint8_t buf[4096];
    HRESULT hr;
    if (!obj || !read_fn) return E_POINTER;
    memset(&zero, 0, sizeof(zero));
    hr = CreateStreamOnHGlobal(NULL, TRUE, &stream);
    if (FAILED(hr)) return hr;
    for (;;) {
        int32_t n = read_fn(ctx, buf, (int32_t)sizeof(buf));
        if (n < 0 || n > (int32_t)sizeof(buf)) {
            hr = STG_E_READFAULT;
            goto done;
        }
        if (n == 0) break;
        hr = vfg_stream_write_exact(stream, buf, (ULONG)n);
        if (FAILED(hr)) goto done;
    }
    hr = IStream_Seek(stream, zero, STREAM_SEEK_SET, NULL);
    if (FAILED(hr)) goto done;
    hr = vfg_persist_load(obj, stream);

done:
    if (stream) IStream_Release(stream);
    return hr;
}

static int32_t vfg_ole_stream_write_cb(void *ctx, const uint8_t *data, int32_t len) {
    IStream *stream = (IStream *)ctx;
    ULONG written = 0;
    HRESULT hr;
    if (!stream || len < 0) return -1;
    hr = IStream_Write(stream, data, (ULONG)len, &written);
    if (FAILED(hr)) return -1;
    return (int32_t)written;
}

static int32_t vfg_ole_stream_read_cb(void *ctx, uint8_t *data, int32_t cap) {
    IStream *stream = (IStream *)ctx;
    ULONG read = 0;
    HRESULT hr;
    if (!stream || !data || cap < 0) return -1;
    hr = IStream_Read(stream, data, (ULONG)cap, &read);
    if (FAILED(hr)) return -1;
    return (int32_t)read;
}

static HRESULT STDMETHODCALLTYPE VFG_PSI_IsDirty(IPersistStreamInit *This) {
    VolvoxGridObject *obj = OBJ_FROM_PERSISTSTREAMINIT(This);
    return obj->dirty ? S_OK : S_FALSE;
}

static HRESULT STDMETHODCALLTYPE VFG_PSI_Load(IPersistStreamInit *This, IStream *pStm) {
    VolvoxGridObject *obj = OBJ_FROM_PERSISTSTREAMINIT(This);
    return (HRESULT)volvox_grid_load_ole_stream_native(
        obj->grid_id,
        vfg_ole_stream_read_cb,
        pStm);
}

static HRESULT STDMETHODCALLTYPE VFG_PSI_Save(IPersistStreamInit *This, IStream *pStm, BOOL fClearDirty) {
    VolvoxGridObject *obj = OBJ_FROM_PERSISTSTREAMINIT(This);
    HRESULT hr = (HRESULT)volvox_grid_save_ole_stream_native(
        obj->grid_id,
        vfg_ole_stream_write_cb,
        pStm);
    if (SUCCEEDED(hr) && fClearDirty) obj->dirty = 0;
    return hr;
}

static HRESULT STDMETHODCALLTYPE VFG_PSI_GetSizeMax(IPersistStreamInit *This, ULARGE_INTEGER *pcbSize) {
    VolvoxGridObject *obj = OBJ_FROM_PERSISTSTREAMINIT(This);
    int32_t rows;
    int32_t cols;
    uint64_t size;
    if (!pcbSize) return E_POINTER;
    rows = obj ? volvox_grid_get_rows(obj->grid_id) : 0;
    cols = obj ? volvox_grid_get_cols(obj->grid_id) : 0;
    if (rows < 0) rows = 0;
    if (cols < 0) cols = 0;
    size = 4 + 4 + (uint64_t)12 * sizeof(int32_t) + sizeof(uint32_t);
    for (int32_t r = 0; r < rows; ++r) {
        for (int32_t c = 0; c < cols; ++c) {
            int32_t len = 0;
            uint8_t *utf8 = volvox_grid_get_text_matrix(obj->grid_id, r, c, &len);
            size += sizeof(uint32_t) + (utf8 && len > 0 ? (uint32_t)len : 0);
            if (utf8) volvox_grid_free(utf8, len);
        }
    }
    pcbSize->QuadPart = size;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_PSI_InitNew(IPersistStreamInit *This) {
    VolvoxGridObject *obj = OBJ_FROM_PERSISTSTREAMINIT(This);
    if (obj) obj->dirty = 0;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_CPC_QueryInterface(
    IConnectionPointContainer *This, REFIID riid, void **ppv)
{
    return VFG_QueryInterface((IDispatch *)OBJ_FROM_CPCONTAINER(This), riid, ppv);
}

static ULONG STDMETHODCALLTYPE VFG_CPC_AddRef(IConnectionPointContainer *This) {
    return VFG_AddRef((IDispatch *)OBJ_FROM_CPCONTAINER(This));
}

static ULONG STDMETHODCALLTYPE VFG_CPC_Release(IConnectionPointContainer *This) {
    return VFG_Release((IDispatch *)OBJ_FROM_CPCONTAINER(This));
}

static VFGConnectionPointsEnum *vfg_connection_points_enum_create(
    VolvoxGridObject *obj, ULONG index)
{
    VFGConnectionPointsEnum *en;
    if (!obj) return NULL;
    en = (VFGConnectionPointsEnum *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*en));
    if (!en) return NULL;
    en->lpVtbl = &g_VFGConnectionPointsEnumVtbl;
    en->ref = 1;
    en->obj = obj;
    en->index = index <= 1 ? index : 1;
    VFG_AddRef((IDispatch *)obj);
    return en;
}

static HRESULT STDMETHODCALLTYPE VFG_CPE_QueryInterface(
    IEnumConnectionPoints *This, REFIID riid, void **ppv)
{
    if (!ppv) return E_POINTER;
    if (IsEqualIID(riid, &IID_IUnknown) || IsEqualIID(riid, &IID_IEnumConnectionPoints)) {
        *ppv = This;
        IEnumConnectionPoints_AddRef(This);
        return S_OK;
    }
    *ppv = NULL;
    return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE VFG_CPE_AddRef(IEnumConnectionPoints *This) {
    VFGConnectionPointsEnum *en = (VFGConnectionPointsEnum *)This;
    return (ULONG)InterlockedIncrement(&en->ref);
}

static ULONG STDMETHODCALLTYPE VFG_CPE_Release(IEnumConnectionPoints *This) {
    VFGConnectionPointsEnum *en = (VFGConnectionPointsEnum *)This;
    LONG refs = InterlockedDecrement(&en->ref);
    if (refs == 0) {
        if (en->obj) VFG_Release((IDispatch *)en->obj);
        HeapFree(GetProcessHeap(), 0, en);
    }
    return (ULONG)refs;
}

static HRESULT STDMETHODCALLTYPE VFG_CPE_Next(
    IEnumConnectionPoints *This,
    ULONG celt,
    IConnectionPoint **rgelt,
    ULONG *pceltFetched)
{
    VFGConnectionPointsEnum *en = (VFGConnectionPointsEnum *)This;
    ULONG fetched = 0;
    if (!rgelt) return E_POINTER;
    if (celt > 1 && !pceltFetched) return E_POINTER;
    while (fetched < celt && en->index < 1) {
        rgelt[fetched] = (IConnectionPoint *)&en->obj->lpVtblConnectionPoint;
        VFG_AddRef((IDispatch *)en->obj);
        fetched++;
        en->index++;
    }
    if (pceltFetched) *pceltFetched = fetched;
    return fetched == celt ? S_OK : S_FALSE;
}

static HRESULT STDMETHODCALLTYPE VFG_CPE_Skip(IEnumConnectionPoints *This, ULONG celt) {
    VFGConnectionPointsEnum *en = (VFGConnectionPointsEnum *)This;
    ULONG remaining = en->index < 1 ? 1 - en->index : 0;
    if (celt > remaining) {
        en->index = 1;
        return S_FALSE;
    }
    en->index += celt;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_CPE_Reset(IEnumConnectionPoints *This) {
    VFGConnectionPointsEnum *en = (VFGConnectionPointsEnum *)This;
    en->index = 0;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_CPE_Clone(
    IEnumConnectionPoints *This, IEnumConnectionPoints **ppenum)
{
    VFGConnectionPointsEnum *en = (VFGConnectionPointsEnum *)This;
    VFGConnectionPointsEnum *clone;
    if (!ppenum) return E_POINTER;
    *ppenum = NULL;
    clone = vfg_connection_points_enum_create(en->obj, en->index);
    if (!clone) return E_OUTOFMEMORY;
    *ppenum = (IEnumConnectionPoints *)clone;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_CPC_EnumConnectionPoints(
    IConnectionPointContainer *This, IEnumConnectionPoints **ppEnum)
{
    VolvoxGridObject *obj = OBJ_FROM_CPCONTAINER(This);
    VFGConnectionPointsEnum *en;
    if (!ppEnum) return E_POINTER;
    *ppEnum = NULL;
    en = vfg_connection_points_enum_create(obj, 0);
    if (!en) return E_OUTOFMEMORY;
    *ppEnum = (IEnumConnectionPoints *)en;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_CPC_FindConnectionPoint(
    IConnectionPointContainer *This, REFIID riid, IConnectionPoint **ppCP)
{
    VolvoxGridObject *obj = OBJ_FROM_CPCONTAINER(This);
    if (!ppCP) return E_POINTER;
    *ppCP = NULL;
    if (!IsEqualIID(riid, &DIID__DVolvoxGridEvents)) return CONNECT_E_NOCONNECTION;
    *ppCP = (IConnectionPoint *)&obj->lpVtblConnectionPoint;
    VFG_AddRef((IDispatch *)obj);
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_CP_QueryInterface(
    IConnectionPoint *This, REFIID riid, void **ppv)
{
    if (IsEqualIID(riid, &IID_IUnknown) || IsEqualIID(riid, &IID_IConnectionPoint)) {
        *ppv = This;
        VFG_AddRef((IDispatch *)OBJ_FROM_CONNECTIONPOINT(This));
        return S_OK;
    }
    return VFG_QueryInterface((IDispatch *)OBJ_FROM_CONNECTIONPOINT(This), riid, ppv);
}

static ULONG STDMETHODCALLTYPE VFG_CP_AddRef(IConnectionPoint *This) {
    return VFG_AddRef((IDispatch *)OBJ_FROM_CONNECTIONPOINT(This));
}

static ULONG STDMETHODCALLTYPE VFG_CP_Release(IConnectionPoint *This) {
    return VFG_Release((IDispatch *)OBJ_FROM_CONNECTIONPOINT(This));
}

static HRESULT STDMETHODCALLTYPE VFG_CP_GetConnectionInterface(IConnectionPoint *This, IID *pIID) {
    (void)This;
    if (!pIID) return E_POINTER;
    *pIID = DIID__DVolvoxGridEvents;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_CP_GetConnectionPointContainer(
    IConnectionPoint *This, IConnectionPointContainer **ppCPC)
{
    VolvoxGridObject *obj = OBJ_FROM_CONNECTIONPOINT(This);
    if (!ppCPC) return E_POINTER;
    *ppCPC = (IConnectionPointContainer *)&obj->lpVtblConnectionPointContainer;
    VFG_AddRef((IDispatch *)obj);
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_CP_Advise(IConnectionPoint *This, IUnknown *pUnkSink, DWORD *pdwCookie) {
    VolvoxGridObject *obj = OBJ_FROM_CONNECTIONPOINT(This);
    IDispatch *disp = NULL;
    VFGSinkEntry *updated;
    if (!pUnkSink || !pdwCookie) return E_POINTER;
    if (FAILED(IUnknown_QueryInterface(pUnkSink, &IID_IDispatch, (void **)&disp)) || !disp) {
        return CONNECT_E_CANNOTCONNECT;
    }
    if (obj->sink_count == obj->sink_capacity) {
        UINT new_cap = obj->sink_capacity ? obj->sink_capacity * 2 : 4;
        updated = obj->sinks
            ? HeapReAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, obj->sinks, new_cap * sizeof(VFGSinkEntry))
            : HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, new_cap * sizeof(VFGSinkEntry));
        if (!updated) {
            IDispatch_Release(disp);
            return E_OUTOFMEMORY;
        }
        obj->sinks = updated;
        obj->sink_capacity = new_cap;
    }
    obj->next_sink_cookie++;
    if (obj->next_sink_cookie == 0) obj->next_sink_cookie = 1;
    obj->sinks[obj->sink_count].cookie = obj->next_sink_cookie;
    obj->sinks[obj->sink_count].dispatch = disp;
    obj->sink_count++;
    *pdwCookie = obj->next_sink_cookie;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_CP_Unadvise(IConnectionPoint *This, DWORD dwCookie) {
    VolvoxGridObject *obj = OBJ_FROM_CONNECTIONPOINT(This);
    UINT i;
    for (i = 0; i < obj->sink_count; ++i) {
        if (obj->sinks[i].cookie == dwCookie) {
            if (obj->sinks[i].dispatch) IDispatch_Release(obj->sinks[i].dispatch);
            if (i + 1 < obj->sink_count) {
                memmove(&obj->sinks[i], &obj->sinks[i + 1], (obj->sink_count - i - 1) * sizeof(VFGSinkEntry));
            }
            obj->sink_count--;
            return S_OK;
        }
    }
    return CONNECT_E_NOCONNECTION;
}

static void vfg_connections_enum_release_items(VFGConnectionsEnum *en) {
    ULONG i;
    if (!en || !en->items) return;
    for (i = 0; i < en->count; ++i) {
        if (en->items[i].pUnk) IUnknown_Release(en->items[i].pUnk);
    }
    HeapFree(GetProcessHeap(), 0, en->items);
    en->items = NULL;
    en->count = 0;
}

static VFGConnectionsEnum *vfg_connections_enum_create(VolvoxGridObject *obj, ULONG index) {
    VFGConnectionsEnum *en;
    UINT i;
    en = (VFGConnectionsEnum *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*en));
    if (!en) return NULL;
    en->lpVtbl = &g_VFGConnectionsEnumVtbl;
    en->ref = 1;
    if (obj && obj->sink_count > 0) {
        en->items = (CONNECTDATA *)HeapAlloc(
            GetProcessHeap(), HEAP_ZERO_MEMORY, obj->sink_count * sizeof(CONNECTDATA));
        if (!en->items) {
            HeapFree(GetProcessHeap(), 0, en);
            return NULL;
        }
        for (i = 0; i < obj->sink_count; ++i) {
            en->items[i].dwCookie = obj->sinks[i].cookie;
            en->items[i].pUnk = (IUnknown *)obj->sinks[i].dispatch;
            if (en->items[i].pUnk) IUnknown_AddRef(en->items[i].pUnk);
        }
        en->count = obj->sink_count;
    }
    en->index = index <= en->count ? index : en->count;
    return en;
}

static VFGConnectionsEnum *vfg_connections_enum_clone_from(VFGConnectionsEnum *src) {
    VFGConnectionsEnum *clone;
    ULONG i;
    clone = (VFGConnectionsEnum *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*clone));
    if (!clone) return NULL;
    clone->lpVtbl = &g_VFGConnectionsEnumVtbl;
    clone->ref = 1;
    clone->index = src->index;
    clone->count = src->count;
    if (src->count > 0) {
        clone->items = (CONNECTDATA *)HeapAlloc(
            GetProcessHeap(), HEAP_ZERO_MEMORY, src->count * sizeof(CONNECTDATA));
        if (!clone->items) {
            HeapFree(GetProcessHeap(), 0, clone);
            return NULL;
        }
        for (i = 0; i < src->count; ++i) {
            clone->items[i] = src->items[i];
            if (clone->items[i].pUnk) IUnknown_AddRef(clone->items[i].pUnk);
        }
    }
    return clone;
}

static HRESULT STDMETHODCALLTYPE VFG_CE_QueryInterface(
    IEnumConnections *This, REFIID riid, void **ppv)
{
    if (!ppv) return E_POINTER;
    if (IsEqualIID(riid, &IID_IUnknown) || IsEqualIID(riid, &IID_IEnumConnections)) {
        *ppv = This;
        IEnumConnections_AddRef(This);
        return S_OK;
    }
    *ppv = NULL;
    return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE VFG_CE_AddRef(IEnumConnections *This) {
    VFGConnectionsEnum *en = (VFGConnectionsEnum *)This;
    return (ULONG)InterlockedIncrement(&en->ref);
}

static ULONG STDMETHODCALLTYPE VFG_CE_Release(IEnumConnections *This) {
    VFGConnectionsEnum *en = (VFGConnectionsEnum *)This;
    LONG refs = InterlockedDecrement(&en->ref);
    if (refs == 0) {
        vfg_connections_enum_release_items(en);
        HeapFree(GetProcessHeap(), 0, en);
    }
    return (ULONG)refs;
}

static HRESULT STDMETHODCALLTYPE VFG_CE_Next(
    IEnumConnections *This, ULONG celt, CONNECTDATA *rgcd, ULONG *pceltFetched)
{
    VFGConnectionsEnum *en = (VFGConnectionsEnum *)This;
    ULONG fetched = 0;
    if (!rgcd) return E_POINTER;
    if (celt > 1 && !pceltFetched) return E_POINTER;
    while (fetched < celt && en->index < en->count) {
        rgcd[fetched] = en->items[en->index];
        if (rgcd[fetched].pUnk) IUnknown_AddRef(rgcd[fetched].pUnk);
        fetched++;
        en->index++;
    }
    if (pceltFetched) *pceltFetched = fetched;
    return fetched == celt ? S_OK : S_FALSE;
}

static HRESULT STDMETHODCALLTYPE VFG_CE_Skip(IEnumConnections *This, ULONG celt) {
    VFGConnectionsEnum *en = (VFGConnectionsEnum *)This;
    ULONG remaining = en->count > en->index ? en->count - en->index : 0;
    if (celt > remaining) {
        en->index = en->count;
        return S_FALSE;
    }
    en->index += celt;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_CE_Reset(IEnumConnections *This) {
    VFGConnectionsEnum *en = (VFGConnectionsEnum *)This;
    en->index = 0;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_CE_Clone(IEnumConnections *This, IEnumConnections **ppenum) {
    VFGConnectionsEnum *en = (VFGConnectionsEnum *)This;
    VFGConnectionsEnum *clone;
    if (!ppenum) return E_POINTER;
    *ppenum = NULL;
    clone = vfg_connections_enum_clone_from(en);
    if (!clone) return E_OUTOFMEMORY;
    *ppenum = (IEnumConnections *)clone;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_CP_EnumConnections(IConnectionPoint *This, IEnumConnections **ppEnum) {
    VolvoxGridObject *obj = OBJ_FROM_CONNECTIONPOINT(This);
    VFGConnectionsEnum *en;
    if (!ppEnum) return E_POINTER;
    *ppEnum = NULL;
    en = vfg_connections_enum_create(obj, 0);
    if (!en) return E_OUTOFMEMORY;
    *ppEnum = (IEnumConnections *)en;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_DO_QueryInterface(
    IDataObject *This, REFIID riid, void **ppv)
{
    if (!ppv) return E_POINTER;
    if (IsEqualIID(riid, &IID_IUnknown) || IsEqualIID(riid, &IID_IDataObject)) {
        *ppv = This;
        VFG_AddRef((IDispatch *)OBJ_FROM_DATAOBJECT(This));
        return S_OK;
    }
    return VFG_QueryInterface((IDispatch *)OBJ_FROM_DATAOBJECT(This), riid, ppv);
}

static ULONG STDMETHODCALLTYPE VFG_DO_AddRef(IDataObject *This) {
    return VFG_AddRef((IDispatch *)OBJ_FROM_DATAOBJECT(This));
}

static ULONG STDMETHODCALLTYPE VFG_DO_Release(IDataObject *This) {
    return VFG_Release((IDispatch *)OBJ_FROM_DATAOBJECT(This));
}

static CLIPFORMAT vfg_clip_format_html(void) {
    static CLIPFORMAT cf_html = 0;
    if (!cf_html) cf_html = (CLIPFORMAT)RegisterClipboardFormatA("HTML Format");
    return cf_html;
}

static CLIPFORMAT vfg_clip_format_cells(void) {
    static CLIPFORMAT cf_cells = 0;
    if (!cf_cells) cf_cells = (CLIPFORMAT)RegisterClipboardFormatA("CF_VFG_CELLS");
    return cf_cells;
}

static HGLOBAL vfg_hglobal_from_bytes(const void *data, SIZE_T len) {
    SIZE_T alloc_len = len < (SIZE_T)-1 ? len + 1 : len;
    HGLOBAL hmem = GlobalAlloc(GMEM_MOVEABLE | GMEM_ZEROINIT, alloc_len);
    void *dst = NULL;
    if (!hmem) return NULL;
    dst = GlobalLock(hmem);
    if (!dst) {
        GlobalFree(hmem);
        return NULL;
    }
    if (data && len > 0) memcpy(dst, data, len);
    GlobalUnlock(hmem);
    return hmem;
}

static void vfg_init_formatetc(FORMATETC *fmt, CLIPFORMAT cf) {
    memset(fmt, 0, sizeof(*fmt));
    fmt->cfFormat = cf;
    fmt->ptd = NULL;
    fmt->dwAspect = DVASPECT_CONTENT;
    fmt->lindex = -1;
    fmt->tymed = TYMED_HGLOBAL;
}

static VFGFormatEtcEnum *vfg_formatetc_enum_create(ULONG index) {
    VFGFormatEtcEnum *en =
        (VFGFormatEtcEnum *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*en));
    CLIPFORMAT cf_html;
    CLIPFORMAT cf_cells;
    if (!en) return NULL;
    en->lpVtbl = &g_VFGFormatEtcEnumVtbl;
    en->ref = 1;
    vfg_init_formatetc(&en->formats[en->count++], CF_UNICODETEXT);
    cf_html = vfg_clip_format_html();
    if (cf_html) vfg_init_formatetc(&en->formats[en->count++], cf_html);
    cf_cells = vfg_clip_format_cells();
    if (cf_cells) vfg_init_formatetc(&en->formats[en->count++], cf_cells);
    en->index = index <= en->count ? index : en->count;
    return en;
}

static HRESULT STDMETHODCALLTYPE VFG_FE_QueryInterface(
    IEnumFORMATETC *This, REFIID riid, void **ppv)
{
    if (!ppv) return E_POINTER;
    if (IsEqualIID(riid, &IID_IUnknown) || IsEqualIID(riid, &IID_IEnumFORMATETC)) {
        *ppv = This;
        IEnumFORMATETC_AddRef(This);
        return S_OK;
    }
    *ppv = NULL;
    return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE VFG_FE_AddRef(IEnumFORMATETC *This) {
    VFGFormatEtcEnum *en = (VFGFormatEtcEnum *)This;
    return (ULONG)InterlockedIncrement(&en->ref);
}

static ULONG STDMETHODCALLTYPE VFG_FE_Release(IEnumFORMATETC *This) {
    VFGFormatEtcEnum *en = (VFGFormatEtcEnum *)This;
    LONG refs = InterlockedDecrement(&en->ref);
    if (refs == 0) HeapFree(GetProcessHeap(), 0, en);
    return (ULONG)refs;
}

static HRESULT STDMETHODCALLTYPE VFG_FE_Next(
    IEnumFORMATETC *This, ULONG celt, FORMATETC *rgelt, ULONG *pceltFetched)
{
    VFGFormatEtcEnum *en = (VFGFormatEtcEnum *)This;
    ULONG fetched = 0;
    if (!rgelt) return E_POINTER;
    if (celt > 1 && !pceltFetched) return E_POINTER;
    while (fetched < celt && en->index < en->count) {
        rgelt[fetched] = en->formats[en->index];
        rgelt[fetched].ptd = NULL;
        fetched++;
        en->index++;
    }
    if (pceltFetched) *pceltFetched = fetched;
    return fetched == celt ? S_OK : S_FALSE;
}

static HRESULT STDMETHODCALLTYPE VFG_FE_Skip(IEnumFORMATETC *This, ULONG celt) {
    VFGFormatEtcEnum *en = (VFGFormatEtcEnum *)This;
    ULONG remaining = en->count > en->index ? en->count - en->index : 0;
    if (celt > remaining) {
        en->index = en->count;
        return S_FALSE;
    }
    en->index += celt;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_FE_Reset(IEnumFORMATETC *This) {
    VFGFormatEtcEnum *en = (VFGFormatEtcEnum *)This;
    en->index = 0;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_FE_Clone(
    IEnumFORMATETC *This, IEnumFORMATETC **ppenum)
{
    VFGFormatEtcEnum *en = (VFGFormatEtcEnum *)This;
    VFGFormatEtcEnum *clone;
    if (!ppenum) return E_POINTER;
    *ppenum = NULL;
    clone = vfg_formatetc_enum_create(en->index);
    if (!clone) return E_OUTOFMEMORY;
    *ppenum = (IEnumFORMATETC *)clone;
    return S_OK;
}

static int vfg_append_html_escaped(char **buf, int *len, int *cap, const char *src, int n) {
    int i;
    for (i = 0; i < n; ++i) {
        unsigned char ch = (unsigned char)src[i];
        if (ch == '&') {
            if (!utf8_append_bytes(buf, len, cap, "&amp;", 5)) return 0;
        } else if (ch == '<') {
            if (!utf8_append_bytes(buf, len, cap, "&lt;", 4)) return 0;
        } else if (ch == '>') {
            if (!utf8_append_bytes(buf, len, cap, "&gt;", 4)) return 0;
        } else if (ch == '"') {
            if (!utf8_append_bytes(buf, len, cap, "&quot;", 6)) return 0;
        } else {
            if (!utf8_append_bytes(buf, len, cap, (const char *)&src[i], 1)) return 0;
        }
    }
    return 1;
}

static char *vfg_build_clip_html_utf8(const char *clip, int clip_len, int *out_len) {
    static const char prefix[] = "<html><body><!--StartFragment-->";
    static const char suffix[] = "<!--EndFragment--></body></html>";
    char header[128];
    char *fragment = NULL;
    char *html = NULL;
    int frag_len = 0;
    int frag_cap = 0;
    int pos = 0;
    int header_len;
    int prefix_len = (int)strlen(prefix);
    int suffix_len = (int)strlen(suffix);
    int start_html;
    int start_fragment;
    int end_fragment;
    int end_html;
    int total_len;

    if (out_len) *out_len = 0;
    if (!clip || clip_len < 0) clip_len = 0;
    if (!utf8_append_bytes(&fragment, &frag_len, &frag_cap, "<table>", 7)) goto fail;
    while (pos < clip_len) {
        if (!utf8_append_bytes(&fragment, &frag_len, &frag_cap, "<tr><td>", 8)) goto fail;
        for (;;) {
            int start = pos;
            while (pos < clip_len && clip[pos] != '\t' && clip[pos] != '\r' && clip[pos] != '\n') {
                pos++;
            }
            if (!vfg_append_html_escaped(&fragment, &frag_len, &frag_cap, clip + start, pos - start)) goto fail;
            if (!utf8_append_bytes(&fragment, &frag_len, &frag_cap, "</td>", 5)) goto fail;
            if (pos < clip_len && clip[pos] == '\t') {
                pos++;
                if (!utf8_append_bytes(&fragment, &frag_len, &frag_cap, "<td>", 4)) goto fail;
                continue;
            }
            break;
        }
        if (!utf8_append_bytes(&fragment, &frag_len, &frag_cap, "</tr>", 5)) goto fail;
        if (pos < clip_len && clip[pos] == '\r') {
            pos++;
            if (pos < clip_len && clip[pos] == '\n') pos++;
        } else if (pos < clip_len && clip[pos] == '\n') {
            pos++;
        }
    }
    if (!utf8_append_bytes(&fragment, &frag_len, &frag_cap, "</table>", 8)) goto fail;

    header_len = snprintf(
        header,
        sizeof(header),
        "Version:0.9\r\nStartHTML:%010u\r\nEndHTML:%010u\r\nStartFragment:%010u\r\nEndFragment:%010u\r\n",
        0u,
        0u,
        0u,
        0u);
    if (header_len <= 0 || header_len >= (int)sizeof(header)) goto fail;
    start_html = header_len;
    start_fragment = start_html + prefix_len;
    end_fragment = start_fragment + frag_len;
    end_html = end_fragment + suffix_len;
    header_len = snprintf(
        header,
        sizeof(header),
        "Version:0.9\r\nStartHTML:%010u\r\nEndHTML:%010u\r\nStartFragment:%010u\r\nEndFragment:%010u\r\n",
        (unsigned)start_html,
        (unsigned)end_html,
        (unsigned)start_fragment,
        (unsigned)end_fragment);
    if (header_len <= 0 || header_len >= (int)sizeof(header)) goto fail;
    total_len = header_len + prefix_len + frag_len + suffix_len;
    html = (char *)HeapAlloc(GetProcessHeap(), 0, (SIZE_T)total_len + 1);
    if (!html) goto fail;
    memcpy(html, header, (size_t)header_len);
    memcpy(html + header_len, prefix, (size_t)prefix_len);
    memcpy(html + header_len + prefix_len, fragment, (size_t)frag_len);
    memcpy(html + header_len + prefix_len + frag_len, suffix, (size_t)suffix_len);
    html[total_len] = '\0';
    HeapFree(GetProcessHeap(), 0, fragment);
    if (out_len) *out_len = total_len;
    return html;

fail:
    if (fragment) HeapFree(GetProcessHeap(), 0, fragment);
    if (html) HeapFree(GetProcessHeap(), 0, html);
    return NULL;
}

static HRESULT STDMETHODCALLTYPE VFG_DO_QueryGetData(IDataObject *This, FORMATETC *pformatetc) {
    VolvoxGridObject *obj = OBJ_FROM_DATAOBJECT(This);
    CLIPFORMAT cf_html = vfg_clip_format_html();
    CLIPFORMAT cf_cells = vfg_clip_format_cells();
    if (!pformatetc) return E_POINTER;
    if (pformatetc->cfFormat != CF_UNICODETEXT &&
        (!cf_html || pformatetc->cfFormat != cf_html) &&
        (!cf_cells || pformatetc->cfFormat != cf_cells) &&
        !vfg_find_stored_data_format(obj, pformatetc->cfFormat)) {
        return DV_E_FORMATETC;
    }
    if (pformatetc->dwAspect != DVASPECT_CONTENT) return DV_E_DVASPECT;
    if (pformatetc->lindex != -1) return DV_E_LINDEX;
    if (!(pformatetc->tymed & TYMED_HGLOBAL)) return DV_E_TYMED;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_DO_GetData(
    IDataObject *This, FORMATETC *pformatetcIn, STGMEDIUM *pmedium)
{
    VolvoxGridObject *obj = OBJ_FROM_DATAOBJECT(This);
    int32_t utf8_len = 0;
    uint8_t *utf8 = NULL;
    int wide_len = 0;
    SIZE_T bytes;
    HGLOBAL hmem;
    WCHAR *wide;
    HRESULT hr;
    VFGStoredDataFormat *stored;

    if (!pmedium) return E_POINTER;
    memset(pmedium, 0, sizeof(*pmedium));
    hr = VFG_DO_QueryGetData(This, pformatetcIn);
    if (FAILED(hr)) return hr;

    stored = pformatetcIn
        ? vfg_find_stored_data_format(obj, pformatetcIn->cfFormat)
        : NULL;
    if (stored) {
        hmem = vfg_hglobal_from_bytes(stored->bytes, stored->len);
        if (!hmem) return STG_E_MEDIUMFULL;
        pmedium->tymed = TYMED_HGLOBAL;
        pmedium->hGlobal = hmem;
        pmedium->pUnkForRelease = NULL;
        return S_OK;
    }

    utf8 = volvox_grid_get_clip(obj->grid_id, &utf8_len);
    if (pformatetcIn && pformatetcIn->cfFormat == vfg_clip_format_html()) {
        int html_len = 0;
        char *html = vfg_build_clip_html_utf8((const char *)utf8, utf8_len, &html_len);
        if (utf8) volvox_grid_free(utf8, utf8_len);
        if (!html) return E_OUTOFMEMORY;
        hmem = vfg_hglobal_from_bytes(html, (SIZE_T)html_len + 1);
        HeapFree(GetProcessHeap(), 0, html);
        if (!hmem) return STG_E_MEDIUMFULL;
        pmedium->tymed = TYMED_HGLOBAL;
        pmedium->hGlobal = hmem;
        pmedium->pUnkForRelease = NULL;
        return S_OK;
    }
    if (pformatetcIn && pformatetcIn->cfFormat == vfg_clip_format_cells()) {
        hmem = vfg_hglobal_from_bytes(utf8, utf8_len > 0 ? (SIZE_T)utf8_len : 0);
        if (utf8) volvox_grid_free(utf8, utf8_len);
        if (!hmem) return STG_E_MEDIUMFULL;
        pmedium->tymed = TYMED_HGLOBAL;
        pmedium->hGlobal = hmem;
        pmedium->pUnkForRelease = NULL;
        return S_OK;
    }
    if (utf8 && utf8_len > 0) {
        wide_len = MultiByteToWideChar(CP_UTF8, 0, (const char *)utf8, utf8_len, NULL, 0);
        if (wide_len < 0) wide_len = 0;
    }
    bytes = ((SIZE_T)wide_len + 1) * sizeof(WCHAR);
    hmem = GlobalAlloc(GMEM_MOVEABLE | GMEM_ZEROINIT, bytes);
    if (!hmem) {
        if (utf8) volvox_grid_free(utf8, utf8_len);
        return STG_E_MEDIUMFULL;
    }
    wide = (WCHAR *)GlobalLock(hmem);
    if (!wide) {
        GlobalFree(hmem);
        if (utf8) volvox_grid_free(utf8, utf8_len);
        return E_OUTOFMEMORY;
    }
    if (utf8 && utf8_len > 0 && wide_len > 0) {
        MultiByteToWideChar(CP_UTF8, 0, (const char *)utf8, utf8_len, wide, wide_len);
    }
    wide[wide_len] = L'\0';
    GlobalUnlock(hmem);
    if (utf8) volvox_grid_free(utf8, utf8_len);

    pmedium->tymed = TYMED_HGLOBAL;
    pmedium->hGlobal = hmem;
    pmedium->pUnkForRelease = NULL;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_DO_GetDataHere(
    IDataObject *This, FORMATETC *pformatetc, STGMEDIUM *pmedium)
{
    (void)This; (void)pformatetc; (void)pmedium;
    return DATA_E_FORMATETC;
}

static HRESULT STDMETHODCALLTYPE VFG_DO_GetCanonicalFormatEtc(
    IDataObject *This, FORMATETC *pformatetcIn, FORMATETC *pformatetcOut)
{
    (void)This; (void)pformatetcIn;
    if (!pformatetcOut) return E_POINTER;
    memset(pformatetcOut, 0, sizeof(*pformatetcOut));
    pformatetcOut->ptd = NULL;
    return DATA_S_SAMEFORMATETC;
}

static HRESULT STDMETHODCALLTYPE VFG_DO_SetData(
    IDataObject *This, FORMATETC *pformatetc, STGMEDIUM *pmedium, BOOL fRelease)
{
    VolvoxGridObject *obj = OBJ_FROM_DATAOBJECT(This);
    HRESULT hr = DATA_E_FORMATETC;
    void *src = NULL;
    SIZE_T len = 0;
    if (!pformatetc || !pmedium) return E_POINTER;
    if ((pformatetc->tymed & TYMED_HGLOBAL) && pmedium->tymed == TYMED_HGLOBAL && pmedium->hGlobal) {
        len = GlobalSize(pmedium->hGlobal);
        src = GlobalLock(pmedium->hGlobal);
        if (src || len == 0) {
            if (len > INT32_MAX) {
                hr = STG_E_MEDIUMFULL;
            } else {
                hr = (HRESULT)volvox_grid_set_data_format_native(
                    obj->grid_id,
                    (uint32_t)pformatetc->cfFormat,
                    (const uint8_t *)src,
                    (int32_t)len);
            }
        } else {
            hr = E_OUTOFMEMORY;
        }
        if (src) GlobalUnlock(pmedium->hGlobal);
    }
    if (fRelease) ReleaseStgMedium(pmedium);
    return hr;
}

static HRESULT STDMETHODCALLTYPE VFG_DO_EnumFormatEtc(
    IDataObject *This, DWORD dwDirection, IEnumFORMATETC **ppenumFormatEtc)
{
    VFGFormatEtcEnum *en;
    (void)This;
    if (!ppenumFormatEtc) return E_POINTER;
    *ppenumFormatEtc = NULL;
    if (dwDirection != DATADIR_GET) return OLE_E_ADVISENOTSUPPORTED;
    en = vfg_formatetc_enum_create(0);
    if (!en) return E_OUTOFMEMORY;
    *ppenumFormatEtc = (IEnumFORMATETC *)en;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_DO_DAdvise(
    IDataObject *This, FORMATETC *pformatetc, DWORD advf, IAdviseSink *pAdvSink,
    DWORD *pdwConnection)
{
    (void)This; (void)pformatetc; (void)advf; (void)pAdvSink;
    if (pdwConnection) *pdwConnection = 0;
    return OLE_E_ADVISENOTSUPPORTED;
}

static HRESULT STDMETHODCALLTYPE VFG_DO_DUnadvise(IDataObject *This, DWORD dwConnection) {
    (void)This; (void)dwConnection;
    return OLE_E_ADVISENOTSUPPORTED;
}

static HRESULT STDMETHODCALLTYPE VFG_DO_EnumDAdvise(
    IDataObject *This, IEnumSTATDATA **ppenumAdvise)
{
    (void)This;
    if (ppenumAdvise) *ppenumAdvise = NULL;
    return OLE_E_ADVISENOTSUPPORTED;
}

static DWORD vfg_choose_drop_effect(VolvoxGridObject *obj, DWORD grfKeyState, DWORD allowed) {
    DWORD want = 0;
    if (!obj || obj->ole_drop_mode_cached == 0) return DROPEFFECT_NONE;
    if ((grfKeyState & MK_CONTROL) && (allowed & DROPEFFECT_COPY)) {
        return DROPEFFECT_COPY;
    }
    if ((grfKeyState & MK_SHIFT) && (allowed & DROPEFFECT_MOVE)) {
        return DROPEFFECT_MOVE;
    }
    if (obj->ole_drop_mode_cached == 1) want = DROPEFFECT_MOVE;
    else if (obj->ole_drop_mode_cached == 2) want = DROPEFFECT_COPY;
    else want = allowed & (DROPEFFECT_COPY | DROPEFFECT_MOVE);
    if ((want & allowed & DROPEFFECT_MOVE) != 0) return DROPEFFECT_MOVE;
    if ((want & allowed & DROPEFFECT_COPY) != 0) return DROPEFFECT_COPY;
    return DROPEFFECT_NONE;
}

static void vfg_fire_ole_start_drag_event(
    VolvoxGridObject *obj, IDataObject *data_object, LONG *allowed_effects)
{
    VARIANT args[2];
    VariantInit(&args[1]); args[1].vt = VT_UNKNOWN; args[1].punkVal = (IUnknown *)data_object;
    VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_I4; args[0].plVal = allowed_effects;
    vfg_fire_event(obj, DISPID_VFG_EVT_OLESTARTDRAG, args, 2);
}

static void vfg_fire_ole_give_feedback_event(
    VolvoxGridObject *obj, LONG effect, VARIANT_BOOL *default_cursors)
{
    VARIANT args[2];
    VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = effect;
    VariantInit(&args[0]); args[0].vt = VT_BYREF | VT_BOOL; args[0].pboolVal = default_cursors;
    vfg_fire_event(obj, DISPID_VFG_EVT_OLEGIVEFEEDBACK, args, 2);
}

static void vfg_fire_ole_complete_drag_event(VolvoxGridObject *obj, LONG effect) {
    VARIANT arg;
    VariantInit(&arg);
    arg.vt = VT_I4;
    arg.lVal = effect;
    vfg_fire_event(obj, DISPID_VFG_EVT_OLECOMPLETEDRAG, &arg, 1);
}

static void vfg_fire_ole_drag_over_event(
    VolvoxGridObject *obj,
    IDataObject *data_object,
    LONG *effect,
    LONG button,
    LONG shift,
    float x,
    float y,
    LONG state)
{
    VARIANT args[7];
    VariantInit(&args[6]); args[6].vt = VT_UNKNOWN; args[6].punkVal = (IUnknown *)data_object;
    VariantInit(&args[5]); args[5].vt = VT_BYREF | VT_I4; args[5].plVal = effect;
    VariantInit(&args[4]); args[4].vt = VT_I4; args[4].lVal = button;
    VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = shift;
    VariantInit(&args[2]); args[2].vt = VT_R4; args[2].fltVal = x;
    VariantInit(&args[1]); args[1].vt = VT_R4; args[1].fltVal = y;
    VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = state;
    vfg_fire_event(obj, DISPID_VFG_EVT_OLEDRAGOVER, args, 7);
}

static void vfg_fire_ole_drag_drop_event(
    VolvoxGridObject *obj,
    IDataObject *data_object,
    LONG *effect,
    LONG button,
    LONG shift,
    float x,
    float y)
{
    VARIANT args[6];
    VariantInit(&args[5]); args[5].vt = VT_UNKNOWN; args[5].punkVal = (IUnknown *)data_object;
    VariantInit(&args[4]); args[4].vt = VT_BYREF | VT_I4; args[4].plVal = effect;
    VariantInit(&args[3]); args[3].vt = VT_I4; args[3].lVal = button;
    VariantInit(&args[2]); args[2].vt = VT_I4; args[2].lVal = shift;
    VariantInit(&args[1]); args[1].vt = VT_R4; args[1].fltVal = x;
    VariantInit(&args[0]); args[0].vt = VT_R4; args[0].fltVal = y;
    vfg_fire_event(obj, DISPID_VFG_EVT_OLEDRAGDROP, args, 6);
}

static HRESULT vfg_paste_unicode_data_object(VolvoxGridObject *obj, IDataObject *data_object) {
    FORMATETC fmt;
    STGMEDIUM med;
    WCHAR *wide = NULL;
    int chars;
    int utf8_len;
    char *utf8 = NULL;
    int32_t out_len = 0;
    int32_t status;
    HRESULT hr;

    if (!obj || !data_object) return E_POINTER;
    vfg_init_formatetc(&fmt, CF_UNICODETEXT);
    memset(&med, 0, sizeof(med));
    hr = IDataObject_GetData(data_object, &fmt, &med);
    if (FAILED(hr)) return hr;
    if (med.tymed != TYMED_HGLOBAL || !med.hGlobal) {
        ReleaseStgMedium(&med);
        return DATA_E_FORMATETC;
    }
    wide = (WCHAR *)GlobalLock(med.hGlobal);
    if (!wide) {
        ReleaseStgMedium(&med);
        return E_OUTOFMEMORY;
    }
    chars = (int)wcslen(wide);
    utf8_len = WideCharToMultiByte(CP_UTF8, 0, wide, chars, NULL, 0, NULL, NULL);
    if (utf8_len > 0) {
        utf8 = (char *)HeapAlloc(GetProcessHeap(), 0, (SIZE_T)utf8_len);
        if (!utf8) {
            GlobalUnlock(med.hGlobal);
            ReleaseStgMedium(&med);
            return E_OUTOFMEMORY;
        }
        WideCharToMultiByte(CP_UTF8, 0, wide, chars, utf8, utf8_len, NULL, NULL);
    }
    GlobalUnlock(med.hGlobal);
    status = vfg_take_status_response(volvox_grid_set_clip(
        obj->grid_id,
        (const uint8_t *)(utf8 ? utf8 : ""),
        utf8 ? utf8_len : 0,
        &out_len));
    if (utf8) HeapFree(GetProcessHeap(), 0, utf8);
    ReleaseStgMedium(&med);
    return status == 0 ? S_OK : E_FAIL;
}

int32_t volvox_grid_ole_begin_drag_native(
    int64_t id,
    int32_t allowed_effects,
    int32_t *out_effect)
{
    VolvoxGridObject *obj = vfg_find_object_by_grid_id(id);
    LONG allowed = allowed_effects != 0
        ? (LONG)allowed_effects
        : (LONG)(DROPEFFECT_COPY | DROPEFFECT_MOVE);
    DWORD effect = DROPEFFECT_NONE;
    HRESULT hr;
    if (out_effect) *out_effect = DROPEFFECT_NONE;
    if (!obj) return E_INVALIDARG;
    if (obj->ole_drag_mode_cached == 0) return S_OK;
    if (!obj->ole_initialized) {
        hr = OleInitialize(NULL);
        if (SUCCEEDED(hr) || hr == S_FALSE) {
            obj->ole_initialized = 1;
        } else {
            return hr;
        }
    }
    vfg_fire_ole_start_drag_event(
        obj,
        (IDataObject *)&obj->lpVtblDataObject,
        &allowed);
    if (allowed == 0) {
        vfg_fire_ole_complete_drag_event(obj, DROPEFFECT_NONE);
        return S_OK;
    }
    hr = DoDragDrop(
        (IDataObject *)&obj->lpVtblDataObject,
        (IDropSource *)&obj->lpVtblDropSource,
        (DWORD)allowed,
        &effect);
    if (hr == DRAGDROP_S_CANCEL) effect = DROPEFFECT_NONE;
    if (FAILED(hr) && hr != DRAGDROP_S_CANCEL) return hr;
    vfg_fire_ole_complete_drag_event(obj, (LONG)effect);
    if (out_effect) *out_effect = (int32_t)effect;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_DS_QueryInterface(
    IDropSource *This, REFIID riid, void **ppv)
{
    if (!ppv) return E_POINTER;
    if (IsEqualIID(riid, &IID_IUnknown) || IsEqualIID(riid, &IID_IDropSource)) {
        *ppv = This;
        VFG_AddRef((IDispatch *)OBJ_FROM_DROPSOURCE(This));
        return S_OK;
    }
    return VFG_QueryInterface((IDispatch *)OBJ_FROM_DROPSOURCE(This), riid, ppv);
}

static ULONG STDMETHODCALLTYPE VFG_DS_AddRef(IDropSource *This) {
    return VFG_AddRef((IDispatch *)OBJ_FROM_DROPSOURCE(This));
}

static ULONG STDMETHODCALLTYPE VFG_DS_Release(IDropSource *This) {
    return VFG_Release((IDispatch *)OBJ_FROM_DROPSOURCE(This));
}

static HRESULT STDMETHODCALLTYPE VFG_DS_QueryContinueDrag(
    IDropSource *This, BOOL fEscapePressed, DWORD grfKeyState)
{
    (void)This;
    if (fEscapePressed) return DRAGDROP_S_CANCEL;
    if (!(grfKeyState & (MK_LBUTTON | MK_RBUTTON | MK_MBUTTON))) return DRAGDROP_S_DROP;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_DS_GiveFeedback(IDropSource *This, DWORD dwEffect) {
    VolvoxGridObject *obj = OBJ_FROM_DROPSOURCE(This);
    VARIANT_BOOL default_cursors = VARIANT_TRUE;
    vfg_fire_ole_give_feedback_event(obj, (LONG)dwEffect, &default_cursors);
    return default_cursors != VARIANT_FALSE ? DRAGDROP_S_USEDEFAULTCURSORS : S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_DT_QueryInterface(
    IDropTarget *This, REFIID riid, void **ppv)
{
    if (!ppv) return E_POINTER;
    if (IsEqualIID(riid, &IID_IUnknown) || IsEqualIID(riid, &IID_IDropTarget)) {
        *ppv = This;
        VFG_AddRef((IDispatch *)OBJ_FROM_DROPTARGET(This));
        return S_OK;
    }
    return VFG_QueryInterface((IDispatch *)OBJ_FROM_DROPTARGET(This), riid, ppv);
}

static ULONG STDMETHODCALLTYPE VFG_DT_AddRef(IDropTarget *This) {
    return VFG_AddRef((IDispatch *)OBJ_FROM_DROPTARGET(This));
}

static ULONG STDMETHODCALLTYPE VFG_DT_Release(IDropTarget *This) {
    return VFG_Release((IDispatch *)OBJ_FROM_DROPTARGET(This));
}

static HRESULT STDMETHODCALLTYPE VFG_DT_DragEnter(
    IDropTarget *This, IDataObject *pDataObj, DWORD grfKeyState, POINTL pt, DWORD *pdwEffect)
{
    VolvoxGridObject *obj = OBJ_FROM_DROPTARGET(This);
    LONG effect;
    if (!pdwEffect) return E_POINTER;
    effect = (LONG)vfg_choose_drop_effect(obj, grfKeyState, *pdwEffect);
    vfg_fire_ole_drag_over_event(
        obj, pDataObj, &effect, 0, (LONG)vfg_current_modifier_flags(), (float)pt.x, (float)pt.y, 0);
    *pdwEffect = (DWORD)effect;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_DT_DragOver(
    IDropTarget *This, DWORD grfKeyState, POINTL pt, DWORD *pdwEffect)
{
    VolvoxGridObject *obj = OBJ_FROM_DROPTARGET(This);
    LONG effect;
    if (!pdwEffect) return E_POINTER;
    effect = (LONG)vfg_choose_drop_effect(obj, grfKeyState, *pdwEffect);
    vfg_fire_ole_drag_over_event(
        obj, NULL, &effect, 0, (LONG)vfg_current_modifier_flags(), (float)pt.x, (float)pt.y, 1);
    *pdwEffect = (DWORD)effect;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_DT_DragLeave(IDropTarget *This) {
    VolvoxGridObject *obj = OBJ_FROM_DROPTARGET(This);
    LONG effect = DROPEFFECT_NONE;
    vfg_fire_ole_drag_over_event(obj, NULL, &effect, 0, 0, 0.0f, 0.0f, 2);
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_DT_Drop(
    IDropTarget *This, IDataObject *pDataObj, DWORD grfKeyState, POINTL pt, DWORD *pdwEffect)
{
    VolvoxGridObject *obj = OBJ_FROM_DROPTARGET(This);
    LONG effect;
    if (!pdwEffect) return E_POINTER;
    effect = (LONG)vfg_choose_drop_effect(obj, grfKeyState, *pdwEffect);
    vfg_fire_ole_drag_drop_event(
        obj, pDataObj, &effect, 0, (LONG)vfg_current_modifier_flags(), (float)pt.x, (float)pt.y);
    if (effect != DROPEFFECT_NONE && pDataObj) {
        (void)vfg_paste_unicode_data_object(obj, pDataObj);
    }
    *pdwEffect = (DWORD)effect;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_OS_QueryInterface(
    IObjectSafety *This, REFIID riid, void **ppv)
{
    return VFG_QueryInterface((IDispatch *)OBJ_FROM_OBJECTSAFETY(This), riid, ppv);
}

static ULONG STDMETHODCALLTYPE VFG_OS_AddRef(IObjectSafety *This) {
    return VFG_AddRef((IDispatch *)OBJ_FROM_OBJECTSAFETY(This));
}

static ULONG STDMETHODCALLTYPE VFG_OS_Release(IObjectSafety *This) {
    return VFG_Release((IDispatch *)OBJ_FROM_OBJECTSAFETY(This));
}

static HRESULT STDMETHODCALLTYPE VFG_OS_GetInterfaceSafetyOptions(
    IObjectSafety *This, REFIID riid, DWORD *pdwSupportedOptions, DWORD *pdwEnabledOptions)
{
    VolvoxGridObject *obj = OBJ_FROM_OBJECTSAFETY(This);
    (void)riid;
    if (!pdwSupportedOptions || !pdwEnabledOptions) return E_POINTER;
    *pdwSupportedOptions = INTERFACESAFE_FOR_UNTRUSTED_CALLER | INTERFACESAFE_FOR_UNTRUSTED_DATA;
    *pdwEnabledOptions = obj->object_safety_options;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE VFG_OS_SetInterfaceSafetyOptions(
    IObjectSafety *This, REFIID riid, DWORD dwOptionSetMask, DWORD dwEnabledOptions)
{
    VolvoxGridObject *obj = OBJ_FROM_OBJECTSAFETY(This);
    DWORD supported = INTERFACESAFE_FOR_UNTRUSTED_CALLER | INTERFACESAFE_FOR_UNTRUSTED_DATA;
    (void)riid;
    obj->object_safety_options &= ~dwOptionSetMask;
    obj->object_safety_options |= (dwEnabledOptions & dwOptionSetMask & supported);
    return S_OK;
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

static IViewObject2Vtbl g_VFGViewObject2Vtbl = {
    VFG_VO2_QueryInterface,
    VFG_VO2_AddRef,
    VFG_VO2_Release,
    VFG_VO2_Draw,
    VFG_VO2_GetColorSet,
    VFG_VO2_Freeze,
    VFG_VO2_Unfreeze,
    VFG_VO2_SetAdvise,
    VFG_VO2_GetAdvise,
    VFG_VO2_GetExtent,
};

static IOleObjectVtbl g_VFGOleObjectVtbl = {
    VFG_OO_QueryInterface,
    VFG_OO_AddRef,
    VFG_OO_Release,
    VFG_OO_SetClientSite,
    VFG_OO_GetClientSite,
    VFG_OO_SetHostNames,
    VFG_OO_Close,
    VFG_OO_SetMoniker,
    VFG_OO_GetMoniker,
    VFG_OO_InitFromData,
    VFG_OO_GetClipboardData,
    VFG_OO_DoVerb,
    VFG_OO_EnumVerbs,
    VFG_OO_Update,
    VFG_OO_IsUpToDate,
    VFG_OO_GetUserClassID,
    VFG_OO_GetUserType,
    VFG_OO_SetExtent,
    VFG_OO_GetExtent,
    VFG_OO_Advise,
    VFG_OO_Unadvise,
    VFG_OO_EnumAdvise,
    VFG_OO_GetMiscStatus,
    VFG_OO_SetColorScheme,
};

static IOleInPlaceObjectVtbl g_VFGInPlaceObjectVtbl = {
    VFG_IPO_QueryInterface,
    VFG_IPO_AddRef,
    VFG_IPO_Release,
    VFG_IPO_GetWindow,
    VFG_IPO_ContextSensitiveHelp,
    VFG_IPO_InPlaceDeactivate,
    VFG_IPO_UIDeactivate,
    VFG_IPO_SetObjectRects,
    VFG_IPO_ReactivateAndUndo,
};

static IOleInPlaceActiveObjectVtbl g_VFGInPlaceActiveObjectVtbl = {
    VFG_IPAO_QueryInterface,
    VFG_IPAO_AddRef,
    VFG_IPAO_Release,
    VFG_IPAO_GetWindow,
    VFG_IPAO_ContextSensitiveHelp,
    VFG_IPAO_TranslateAccelerator,
    VFG_IPAO_OnFrameWindowActivate,
    VFG_IPAO_OnDocWindowActivate,
    VFG_IPAO_ResizeBorder,
    VFG_IPAO_EnableModeless,
};

static IOleControlVtbl g_VFGOleControlVtbl = {
    VFG_OC_QueryInterface,
    VFG_OC_AddRef,
    VFG_OC_Release,
    VFG_OC_GetControlInfo,
    VFG_OC_OnMnemonic,
    VFG_OC_OnAmbientPropertyChange,
    VFG_OC_FreezeEvents,
};

static IPersistStreamInitVtbl g_VFGPersistStreamInitVtbl = {
    VFG_PSI_QueryInterface,
    VFG_PSI_AddRef,
    VFG_PSI_Release,
    VFG_PSI_GetClassID,
    VFG_PSI_IsDirty,
    VFG_PSI_Load,
    VFG_PSI_Save,
    VFG_PSI_GetSizeMax,
    VFG_PSI_InitNew,
};

static IConnectionPointContainerVtbl g_VFGConnectionPointContainerVtbl = {
    VFG_CPC_QueryInterface,
    VFG_CPC_AddRef,
    VFG_CPC_Release,
    VFG_CPC_EnumConnectionPoints,
    VFG_CPC_FindConnectionPoint,
};

static IConnectionPointVtbl g_VFGConnectionPointVtbl = {
    VFG_CP_QueryInterface,
    VFG_CP_AddRef,
    VFG_CP_Release,
    VFG_CP_GetConnectionInterface,
    VFG_CP_GetConnectionPointContainer,
    VFG_CP_Advise,
    VFG_CP_Unadvise,
    VFG_CP_EnumConnections,
};

static IEnumConnectionPointsVtbl g_VFGConnectionPointsEnumVtbl = {
    VFG_CPE_QueryInterface,
    VFG_CPE_AddRef,
    VFG_CPE_Release,
    VFG_CPE_Next,
    VFG_CPE_Skip,
    VFG_CPE_Reset,
    VFG_CPE_Clone,
};

static IEnumConnectionsVtbl g_VFGConnectionsEnumVtbl = {
    VFG_CE_QueryInterface,
    VFG_CE_AddRef,
    VFG_CE_Release,
    VFG_CE_Next,
    VFG_CE_Skip,
    VFG_CE_Reset,
    VFG_CE_Clone,
};

static IDataObjectVtbl g_VFGDataObjectVtbl = {
    VFG_DO_QueryInterface,
    VFG_DO_AddRef,
    VFG_DO_Release,
    VFG_DO_GetData,
    VFG_DO_GetDataHere,
    VFG_DO_QueryGetData,
    VFG_DO_GetCanonicalFormatEtc,
    VFG_DO_SetData,
    VFG_DO_EnumFormatEtc,
    VFG_DO_DAdvise,
    VFG_DO_DUnadvise,
    VFG_DO_EnumDAdvise,
};

static IEnumFORMATETCVtbl g_VFGFormatEtcEnumVtbl = {
    VFG_FE_QueryInterface,
    VFG_FE_AddRef,
    VFG_FE_Release,
    VFG_FE_Next,
    VFG_FE_Skip,
    VFG_FE_Reset,
    VFG_FE_Clone,
};

static IDropSourceVtbl g_VFGDropSourceVtbl = {
    VFG_DS_QueryInterface,
    VFG_DS_AddRef,
    VFG_DS_Release,
    VFG_DS_QueryContinueDrag,
    VFG_DS_GiveFeedback,
};

static IDropTargetVtbl g_VFGDropTargetVtbl = {
    VFG_DT_QueryInterface,
    VFG_DT_AddRef,
    VFG_DT_Release,
    VFG_DT_DragEnter,
    VFG_DT_DragOver,
    VFG_DT_DragLeave,
    VFG_DT_Drop,
};

static IObjectSafetyVtbl g_VFGObjectSafetyVtbl = {
    VFG_OS_QueryInterface,
    VFG_OS_AddRef,
    VFG_OS_Release,
    VFG_OS_GetInterfaceSafetyOptions,
    VFG_OS_SetInterfaceSafetyOptions,
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
    if (!hdc || !hfont) {
        if (hfont) DeleteObject(hfont);
        if (hdc) DeleteDC(hdc);
        *out_height = font_size * 1.2f;
        return;
    }
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
    HFONT hfont = gdi_create_font(font_name_ptr, font_name_len,
                                  font_size,
                                  bold, italic);
    if (!hdc || !hbmp || !hfont) {
        if (hbmp) DeleteObject(hbmp);
        if (hfont) DeleteObject(hfont);
        if (hdc) DeleteDC(hdc);
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
    obj->lpVtblViewObject2 = &g_VFGViewObject2Vtbl;
    obj->lpVtblOleObject = &g_VFGOleObjectVtbl;
    obj->lpVtblInPlaceObject = &g_VFGInPlaceObjectVtbl;
    obj->lpVtblInPlaceActiveObject = &g_VFGInPlaceActiveObjectVtbl;
    obj->lpVtblOleControl = &g_VFGOleControlVtbl;
    obj->lpVtblPersistStreamInit = &g_VFGPersistStreamInitVtbl;
    obj->lpVtblConnectionPointContainer = &g_VFGConnectionPointContainerVtbl;
    obj->lpVtblConnectionPoint = &g_VFGConnectionPointVtbl;
    obj->lpVtblDataObject = &g_VFGDataObjectVtbl;
    obj->lpVtblDropSource = &g_VFGDropSourceVtbl;
    obj->lpVtblDropTarget = &g_VFGDropTargetVtbl;
    obj->lpVtblObjectSafety = &g_VFGObjectSafetyVtbl;
    obj->cRef = 1;
    obj->extent_himetric.cx = (640 * 2540) / VFG_DEFAULT_DPI;
    obj->extent_himetric.cy = (480 * 2540) / VFG_DEFAULT_DPI;
    obj->object_safety_options =
        INTERFACESAFE_FOR_UNTRUSTED_CALLER | INTERFACESAFE_FOR_UNTRUSTED_DATA;
    obj->next_sink_cookie = 1;
    obj->fixed_rows_cached = 1;
    obj->fixed_cols_cached = 1;
    obj->bound_fixed_cols = 0;
    obj->bound_data_col_offset = 0;
    obj->bound_col_width_uses_data_offset = 0;
    obj->bound_virtual_active = 0;
    obj->bound_record_count = -1;
    obj->bound_window_start = 0;
    obj->bound_window_end = 0;
    obj->has_bound_layout = 0;
    obj->frozen_rows_cached = 0;
    obj->frozen_cols_cached = 0;
    obj->row_sel_cached = 1;
    obj->col_sel_cached = 1;
    obj->data_mode = 0;
    obj->virtual_data = 0;
    obj->auto_resize = 1;
    obj->sort_order_cached = 0;
    obj->ole_drag_mode_cached = 0;
    obj->ole_drop_mode_cached = 0;
    obj->ole_initialized = 0;
    obj->drop_registered = 0;
    obj->suppress_bound_text_writes = 0;
    obj->edit_max_length_empty = 0;
    obj->mouse_pointer_cached = 0;
    obj->col_width_min_twips = -1;
    obj->row_height_min_twips = -1;
    obj->data_source = NULL;
    obj->recordset = NULL;
    obj->data_member = NULL;
    VariantInit(&obj->height_cached);
    VariantInit(&obj->width_cached);
    SetRectEmpty(&obj->pos_rect);
    SetRectEmpty(&obj->clip_rect);
    obj->registry_next = NULL;
    /* Match the legacy control's fresh-instance default geometry. */
    obj->grid_id = volvox_grid_create_grid(640, 480, 50, 10, 1, 1, 1.0f);
    vfg_register_object(obj);
    volvox_grid_set_custom_compare_native(
        obj->grid_id,
        vfg_custom_compare_callback,
        obj);
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
    volvox_grid_set_appearance_native(obj->grid_id, 0);
    volvox_grid_set_sheet_border_native(obj->grid_id, 0);
    volvox_grid_set_font_bold_native(obj->grid_id, 0);
    volvox_grid_set_font_italic_native(obj->grid_id, 0);
    volvox_grid_set_font_underline_native(obj->grid_id, 0);
    volvox_grid_set_font_strikethrough_native(obj->grid_id, 0);
    volvox_grid_set_font_width_native(obj->grid_id, 0);
    volvox_grid_set_grid_line_width_native(obj->grid_id, 1);
    volvox_grid_set_col_width_min_default_native(
        obj->grid_id,
        vfg_twips_to_px_x(-1));
    volvox_grid_set_row_height_min_native(
        obj->grid_id,
        vfg_twips_to_px_y(-1));
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
