/* grid_compare_test.c — Side-by-side comparison: FlexGrid vs VolvoxGrid
 *
 * Creates COM instances of both controls, loads VBScript test files from
 * the tests/ directory, executes them via IActiveScript, renders the grids
 * via IViewObject::Draw, and saves BMP files.  Generates pixel-diff BMPs
 * and reports similarity percentages.
 *
 * Build with MinGW:
 *   i686-w64-mingw32-gcc -O2 -o grid_compare_test.exe grid_compare_test.c \
 *       -lole32 -loleaut32 -luuid -lgdi32 -static-libgcc
 *
 * Usage:
 *   1. Register both OCXs:
 *        regsvr32 FlexGrid.ocx
 *        regsvr32 VolvoxGrid_i686.ocx
 *   2. Run:  grid_compare_test.exe --ref-progid "ProgID.Of.Reference"
 *
 * Options:
 *   --ref-progid ID     ProgID of the reference control to compare against
 *   --only-vv           Skip reference, only render VolvoxGrid
 *   --no-diff           Skip pixel diff generation
 *   --test N            Run only one test number
 *   --tests LIST        Run only selected tests (e.g. 1,3,7-9)
 *
 * Output:
 *   test_NN_name_lg.bmp   — rendered by FlexGrid
 *   test_NN_name_vv.bmp   — rendered by VolvoxGrid
 *   test_NN_name_diff.bmp — pixel diff (red = different)
 */

#define COBJMACROS
#define CINTERFACE
#include <windows.h>
#include <ole2.h>
#include <oleauto.h>
#include <olectl.h>
#include <activscp.h>
#include <servprov.h>
#include <ctype.h>
#include <stddef.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* MinGW doesn't link IID_IActiveScriptParse32 by default — define it here. */
static const GUID MY_IID_IActiveScriptParse =
    {0xBB1A2AE2, 0xA4F9, 0x11cf, {0x8F, 0x20, 0x00, 0x80, 0x5F, 0x2C, 0xD0, 0x64}};

/* ── ProgIDs ─────────────────────────────────────────────── */
static const WCHAR PROGID_VOLVOXGRID[]  = L"VolvoxGrid.VolvoxGridCtrl";
/* Reference ProgID is passed via --ref-progid on the command line */
static WCHAR g_ref_progid[256] = {0};

/* ── GUIDs ───────────────────────────────────────────────── */
static const GUID CLSID_VBScript =
    {0xB54F3741,0x5B07,0x11cf,{0xA4,0xB0,0x00,0xAA,0x00,0x4A,0x55,0xE8}};

/* ── IDispatch helpers (kept for populate_standard) ──────── */

static HRESULT get_dispid(IDispatch *pDisp, LPCOLESTR name, DISPID *out) {
    LPOLESTR names[1] = { (LPOLESTR)name };
    return pDisp->lpVtbl->GetIDsOfNames(pDisp, &IID_NULL, names, 1, 0, out);
}

static int get_int(IDispatch *pDisp, LPCOLESTR name, int fallback) {
    DISPID dispid;
    if (FAILED(get_dispid(pDisp, name, &dispid))) return fallback;
    DISPPARAMS dp = { 0 };
    VARIANT vr;
    VariantInit(&vr);
    HRESULT hr = pDisp->lpVtbl->Invoke(
        pDisp, dispid, &IID_NULL, 0, DISPATCH_PROPERTYGET, &dp, &vr, NULL, NULL);
    if (FAILED(hr)) return fallback;
    VARIANT tmp;
    VariantInit(&tmp);
    hr = VariantChangeType(&tmp, &vr, 0, VT_I4);
    VariantClear(&vr);
    if (FAILED(hr)) {
        VariantClear(&tmp);
        return fallback;
    }
    int out = tmp.lVal;
    VariantClear(&tmp);
    return out;
}

static HRESULT call_resize_viewport(IDispatch *pDisp, int width, int height) {
    DISPID dispid;
    VARIANT args[2];
    DISPPARAMS dp;

    if (FAILED(get_dispid(pDisp, L"ResizeViewport", &dispid))) return DISP_E_MEMBERNOTFOUND;

    VariantInit(&args[0]);
    VariantInit(&args[1]);
    args[0].vt = VT_I4;
    args[0].lVal = height;
    args[1].vt = VT_I4;
    args[1].lVal = width;

    dp.rgvarg = args;
    dp.rgdispidNamedArgs = NULL;
    dp.cArgs = 2;
    dp.cNamedArgs = 0;
    return pDisp->lpVtbl->Invoke(
        pDisp, dispid, &IID_NULL, 0, DISPATCH_METHOD, &dp, NULL, NULL, NULL);
}

static double get_double(IDispatch *pDisp, LPCOLESTR name, double fallback) {
    DISPID dispid;
    if (FAILED(get_dispid(pDisp, name, &dispid))) return fallback;
    DISPPARAMS dp = { 0 };
    VARIANT vr;
    VariantInit(&vr);
    HRESULT hr = pDisp->lpVtbl->Invoke(
        pDisp, dispid, &IID_NULL, 0, DISPATCH_PROPERTYGET, &dp, &vr, NULL, NULL);
    if (FAILED(hr)) return fallback;
    VARIANT tmp;
    VariantInit(&tmp);
    hr = VariantChangeType(&tmp, &vr, 0, VT_R8);
    VariantClear(&vr);
    if (FAILED(hr)) {
        VariantClear(&tmp);
        return fallback;
    }
    {
        double out = tmp.dblVal;
        VariantClear(&tmp);
        return out;
    }
}

static int get_indexed_int(IDispatch *pDisp, LPCOLESTR name, int index, int fallback) {
    DISPID dispid;
    if (FAILED(get_dispid(pDisp, name, &dispid))) return fallback;

    VARIANT arg;
    VariantInit(&arg);
    arg.vt = VT_I4;
    arg.lVal = index;
    DISPPARAMS dp = { &arg, NULL, 1, 0 };

    VARIANT vr;
    VariantInit(&vr);
    HRESULT hr = pDisp->lpVtbl->Invoke(
        pDisp, dispid, &IID_NULL, 0, DISPATCH_PROPERTYGET, &dp, &vr, NULL, NULL);
    if (FAILED(hr)) return fallback;
    VARIANT tmp;
    VariantInit(&tmp);
    hr = VariantChangeType(&tmp, &vr, 0, VT_I4);
    VariantClear(&vr);
    if (FAILED(hr)) {
        VariantClear(&tmp);
        return fallback;
    }
    int out = tmp.lVal;
    VariantClear(&tmp);
    return out;
}

static void get_string_utf8(IDispatch *pDisp, LPCOLESTR name, char *out, int out_cap) {
    DISPID dispid;
    DISPPARAMS dp = { 0 };
    VARIANT vr;
    VARIANT tmp;
    int wlen;
    int n;

    if (!out || out_cap <= 0) return;
    out[0] = '\0';
    if (FAILED(get_dispid(pDisp, name, &dispid))) return;

    VariantInit(&vr);
    if (FAILED(pDisp->lpVtbl->Invoke(
            pDisp, dispid, &IID_NULL, 0, DISPATCH_PROPERTYGET, &dp, &vr, NULL, NULL))) {
        return;
    }

    VariantInit(&tmp);
    if (FAILED(VariantChangeType(&tmp, &vr, 0, VT_BSTR))) {
        VariantClear(&vr);
        VariantClear(&tmp);
        return;
    }
    VariantClear(&vr);

    if (!tmp.bstrVal) {
        VariantClear(&tmp);
        return;
    }

    wlen = SysStringLen(tmp.bstrVal);
    n = WideCharToMultiByte(CP_UTF8, 0, tmp.bstrVal, wlen, out, out_cap - 1, NULL, NULL);
    if (n < 0) n = 0;
    if (n >= out_cap) n = out_cap - 1;
    out[n] = '\0';
    VariantClear(&tmp);
}


static char *dup_utf8_string(const char *src) {
    size_t len;
    char *copy;

    if (!src) src = "";
    len = strlen(src);
    copy = (char *)malloc(len + 1);
    if (!copy) return NULL;
    memcpy(copy, src, len + 1);
    return copy;
}

static char *get_text_matrix_utf8_alloc(
    IDispatch *pDisp,
    int row,
    int col,
    HRESULT *out_hr)
{
    DISPID dispid;
    LPOLESTR name = L"TextMatrix";
    VARIANT args[2];
    DISPPARAMS dp;
    VARIANT vr;
    VARIANT tmp;
    HRESULT hr;
    int wlen;
    int n;
    char *out;

    if (out_hr) *out_hr = E_FAIL;
    if (!pDisp) {
        if (out_hr) *out_hr = E_POINTER;
        return NULL;
    }

    if (FAILED(pDisp->lpVtbl->GetIDsOfNames(pDisp, &IID_NULL, &name, 1, 0, &dispid))) {
        if (out_hr) *out_hr = DISP_E_MEMBERNOTFOUND;
        return NULL;
    }

    VariantInit(&args[0]);
    VariantInit(&args[1]);
    args[0].vt = VT_I4;
    args[0].lVal = col;
    args[1].vt = VT_I4;
    args[1].lVal = row;
    dp.rgvarg = args;
    dp.rgdispidNamedArgs = NULL;
    dp.cArgs = 2;
    dp.cNamedArgs = 0;

    VariantInit(&vr);
    hr = pDisp->lpVtbl->Invoke(
        pDisp, dispid, &IID_NULL, 0, DISPATCH_PROPERTYGET, &dp, &vr, NULL, NULL);
    if (FAILED(hr)) {
        if (out_hr) *out_hr = hr;
        VariantClear(&vr);
        return NULL;
    }

    VariantInit(&tmp);
    hr = VariantChangeType(&tmp, &vr, 0, VT_BSTR);
    VariantClear(&vr);
    if (FAILED(hr)) {
        if (out_hr) *out_hr = hr;
        VariantClear(&tmp);
        return NULL;
    }

    if (!tmp.bstrVal) {
        if (out_hr) *out_hr = S_OK;
        VariantClear(&tmp);
        return dup_utf8_string("");
    }

    wlen = SysStringLen(tmp.bstrVal);
    if (wlen <= 0) {
        if (out_hr) *out_hr = S_OK;
        VariantClear(&tmp);
        return dup_utf8_string("");
    }

    n = WideCharToMultiByte(CP_UTF8, 0, tmp.bstrVal, wlen, NULL, 0, NULL, NULL);
    if (n <= 0) {
        hr = HRESULT_FROM_WIN32(GetLastError());
        if (hr == S_OK) hr = E_FAIL;
        if (out_hr) *out_hr = hr;
        VariantClear(&tmp);
        return NULL;
    }

    out = (char *)malloc((size_t)n + 1);
    if (!out) {
        if (out_hr) *out_hr = E_OUTOFMEMORY;
        VariantClear(&tmp);
        return NULL;
    }

    if (WideCharToMultiByte(CP_UTF8, 0, tmp.bstrVal, wlen, out, n, NULL, NULL) <= 0) {
        hr = HRESULT_FROM_WIN32(GetLastError());
        if (hr == S_OK) hr = E_FAIL;
        if (out_hr) *out_hr = hr;
        VariantClear(&tmp);
        free(out);
        return NULL;
    }

    out[n] = '\0';
    if (out_hr) *out_hr = S_OK;
    VariantClear(&tmp);
    return out;
}

static void get_text_matrix_utf8(
    IDispatch *pDisp, int row, int col, char *out, int out_cap)
{
    char *text;

    if (!out || out_cap <= 0) return;
    out[0] = '\0';
    text = get_text_matrix_utf8_alloc(pDisp, row, col, NULL);
    if (!text) return;
    snprintf(out, (size_t)out_cap, "%s", text);
    free(text);
}

static unsigned int get_u32_prop(IDispatch *disp, LPCOLESTR name, unsigned int fallback);

static void dump_grid_rows(IDispatch *pDisp, const char *tag, int test_no) {
    int rows = get_int(pDisp, L"Rows", 0);
    int cols = get_int(pDisp, L"Cols", 0);
    int row = get_int(pDisp, L"Row", 0);
    int col = get_int(pDisp, L"Col", 0);
    int row_sel = get_int(pDisp, L"RowSel", 0);
    int col_sel = get_int(pDisp, L"ColSel", 0);
    unsigned int back_color = get_u32_prop(pDisp, L"BackColor", 0);
    unsigned int grid_color = get_u32_prop(pDisp, L"GridColor", 0);
    unsigned int back_color_sel = get_u32_prop(pDisp, L"BackColorSel", 0);
    unsigned int fore_color_sel = get_u32_prop(pDisp, L"ForeColorSel", 0);
    int grid_lines = get_int(pDisp, L"GridLines", 0);
    int grid_lines_fixed = get_int(pDisp, L"GridLinesFixed", 0);
    int focus_rect = get_int(pDisp, L"FocusRect", 0);
    if (cols > 5) cols = 5;
    printf("  DUMP[%s][%02d]: rows=%d cols=%d row=%d col=%d row_sel=%d col_sel=%d focus_rect=%d grid_lines=%d grid_lines_fixed=%d back=%08X grid=%08X sel_back=%08X sel_fore=%08X\n",
           tag, test_no, rows, cols, row, col, row_sel, col_sel, focus_rect, grid_lines, grid_lines_fixed,
           back_color, grid_color, back_color_sel, fore_color_sel);
    for (int r = 0; r < rows; r++) {
        int lvl = get_indexed_int(pDisp, L"RowOutlineLevel", r, -9999);
        int sub = get_indexed_int(pDisp, L"IsSubtotal", r, -9999);
        char c0[128], c1[128], c2[128], c3[128], c4[128];
        get_text_matrix_utf8(pDisp, r, 0, c0, sizeof(c0));
        get_text_matrix_utf8(pDisp, r, 1, c1, sizeof(c1));
        get_text_matrix_utf8(pDisp, r, 2, c2, sizeof(c2));
        get_text_matrix_utf8(pDisp, r, 3, c3, sizeof(c3));
        get_text_matrix_utf8(pDisp, r, 4, c4, sizeof(c4));
        printf("    %d|L=%d|S=%d|%s|%s|%s|%s|%s\n", r, lvl, sub, c0, c1, c2, c3, c4);
    }
}

#define SNAP_MISSING_INT (-2147483647)

typedef struct {
    int rows;
    int cols;
    int fixed_rows;
    int fixed_cols;
    int frozen_rows;
    int frozen_cols;
    int row;
    int col;
    int row_sel;
    int col_sel;
    int top_row;
    int left_col;
    int *row_heights;
    int row_heights_count;
    int *col_widths;
    int col_widths_count;
} GridSnapshot;

static void free_grid_snapshot(GridSnapshot *snap) {
    if (!snap) return;
    free(snap->row_heights);
    free(snap->col_widths);
    memset(snap, 0, sizeof(*snap));
}

static void capture_grid_snapshot(IDispatch *pDisp, GridSnapshot *snap) {
    int i;
    if (!snap) return;
    memset(snap, 0, sizeof(*snap));
    snap->rows = get_int(pDisp, L"Rows", SNAP_MISSING_INT);
    snap->cols = get_int(pDisp, L"Cols", SNAP_MISSING_INT);
    snap->fixed_rows = get_int(pDisp, L"FixedRows", SNAP_MISSING_INT);
    snap->fixed_cols = get_int(pDisp, L"FixedCols", SNAP_MISSING_INT);
    snap->frozen_rows = get_int(pDisp, L"FrozenRows", SNAP_MISSING_INT);
    snap->frozen_cols = get_int(pDisp, L"FrozenCols", SNAP_MISSING_INT);
    snap->row = get_int(pDisp, L"Row", SNAP_MISSING_INT);
    snap->col = get_int(pDisp, L"Col", SNAP_MISSING_INT);
    snap->row_sel = get_int(pDisp, L"RowSel", SNAP_MISSING_INT);
    snap->col_sel = get_int(pDisp, L"ColSel", SNAP_MISSING_INT);
    snap->top_row = get_int(pDisp, L"TopRow", SNAP_MISSING_INT);
    snap->left_col = get_int(pDisp, L"LeftCol", SNAP_MISSING_INT);

    if (snap->rows > 0) {
        snap->row_heights_count = snap->rows;
        snap->row_heights = (int *)calloc((size_t)snap->row_heights_count, sizeof(int));
        if (snap->row_heights) {
            for (i = 0; i < snap->row_heights_count; i++) {
                snap->row_heights[i] = get_indexed_int(pDisp, L"RowHeight", i, SNAP_MISSING_INT);
            }
        }
    }
    if (snap->cols > 0) {
        snap->col_widths_count = snap->cols;
        snap->col_widths = (int *)calloc((size_t)snap->col_widths_count, sizeof(int));
        if (snap->col_widths) {
            for (i = 0; i < snap->col_widths_count; i++) {
                snap->col_widths[i] = get_indexed_int(pDisp, L"ColWidth", i, SNAP_MISSING_INT);
            }
        }
    }
}

static void format_snapshot_value(int value, char *buf, size_t buf_cap) {
    if (!buf || buf_cap == 0) return;
    if (value == SNAP_MISSING_INT) {
        snprintf(buf, buf_cap, "<missing>");
    } else {
        snprintf(buf, buf_cap, "%d", value);
    }
}

static void print_snapshot_int_diff(const char *name, int lg_value, int vv_value, int *printed) {
    char lg_buf[32];
    char vv_buf[32];
    if (lg_value == vv_value) return;
    if (printed && !*printed) {
        printf("  PropertyDiff:\n");
        *printed = 1;
    }
    format_snapshot_value(lg_value, lg_buf, sizeof(lg_buf));
    format_snapshot_value(vv_value, vv_buf, sizeof(vv_buf));
    printf("    %s: lg=%s vv=%s\n", name, lg_buf, vv_buf);
}

static void print_snapshot_array_diff(
    const char *name,
    const int *lg_values,
    int lg_count,
    const int *vv_values,
    int vv_count,
    int *printed)
{
    int count = lg_count > vv_count ? lg_count : vv_count;
    int i;
    for (i = 0; i < count; i++) {
        int lg_value = i < lg_count && lg_values ? lg_values[i] : SNAP_MISSING_INT;
        int vv_value = i < vv_count && vv_values ? vv_values[i] : SNAP_MISSING_INT;
        char label[64];
        if (lg_value == vv_value) continue;
        if (printed && !*printed) {
            printf("  PropertyDiff:\n");
            *printed = 1;
        }
        snprintf(label, sizeof(label), "%s[%d]", name, i);
        print_snapshot_int_diff(label, lg_value, vv_value, printed);
    }
}

static void print_grid_property_diffs(
    int test_no,
    const char *test_name,
    const GridSnapshot *lg,
    const GridSnapshot *vv)
{
    int printed = 0;
    if (!lg || !vv) return;
    print_snapshot_int_diff("Rows", lg->rows, vv->rows, &printed);
    print_snapshot_int_diff("Cols", lg->cols, vv->cols, &printed);
    print_snapshot_int_diff("FixedRows", lg->fixed_rows, vv->fixed_rows, &printed);
    print_snapshot_int_diff("FixedCols", lg->fixed_cols, vv->fixed_cols, &printed);
    print_snapshot_int_diff("FrozenRows", lg->frozen_rows, vv->frozen_rows, &printed);
    print_snapshot_int_diff("FrozenCols", lg->frozen_cols, vv->frozen_cols, &printed);
    print_snapshot_int_diff("Row", lg->row, vv->row, &printed);
    print_snapshot_int_diff("Col", lg->col, vv->col, &printed);
    print_snapshot_int_diff("RowSel", lg->row_sel, vv->row_sel, &printed);
    print_snapshot_int_diff("ColSel", lg->col_sel, vv->col_sel, &printed);
    print_snapshot_int_diff("TopRow", lg->top_row, vv->top_row, &printed);
    print_snapshot_int_diff("LeftCol", lg->left_col, vv->left_col, &printed);
    print_snapshot_array_diff("RowHeight", lg->row_heights, lg->row_heights_count, vv->row_heights, vv->row_heights_count, &printed);
    print_snapshot_array_diff("ColWidth", lg->col_widths, lg->col_widths_count, vv->col_widths, vv->col_widths_count, &printed);
    if (printed) {
        printf("  PropertyDiffEnd[%02d] %s\n", test_no, test_name);
    }
}


static char *escape_cell_text_for_diff_alloc(const char *src) {
    size_t src_len;
    size_t cap;
    size_t si;
    size_t di = 0;
    char *dst;

    if (!src) src = "";
    src_len = strlen(src);
    cap = src_len * 4 + 1;
    if (cap < src_len + 1) cap = src_len + 1;
    dst = (char *)malloc(cap);
    if (!dst) return NULL;

    for (si = 0; si < src_len; si++) {
        unsigned char ch = (unsigned char)src[si];
        if (di + 5 >= cap) break;
        switch (ch) {
        case '\\':
            dst[di++] = '\\';
            dst[di++] = '\\';
            break;
        case '"':
            dst[di++] = '\\';
            dst[di++] = '"';
            break;
        case '\r':
            dst[di++] = '\\';
            dst[di++] = 'r';
            break;
        case '\n':
            dst[di++] = '\\';
            dst[di++] = 'n';
            break;
        case '\t':
            dst[di++] = '\\';
            dst[di++] = 't';
            break;
        default:
            if (ch < 0x20 || ch == 0x7F) {
                snprintf(dst + di, cap - di, "\\x%02X", ch);
                di += 4;
            } else {
                dst[di++] = (char)ch;
            }
            break;
        }
    }

    dst[di] = '\0';
    return dst;
}

static char *get_cell_compare_value(
    IDispatch *pDisp,
    int row,
    int col,
    int rows,
    int cols)
{
    HRESULT hr;
    char marker[64];
    char *text;

    if (!pDisp || row < 0 || col < 0 || row >= rows || col >= cols) {
        return dup_utf8_string("<missing>");
    }

    text = get_text_matrix_utf8_alloc(pDisp, row, col, &hr);
    if (text) return text;

    snprintf(marker, sizeof(marker), "<error 0x%08lx>", hr);
    return dup_utf8_string(marker);
}

static int write_grid_cell_diff_file(
    int test_no,
    const char *test_name,
    const GridSnapshot *lg,
    const GridSnapshot *vv,
    IDispatch *lg_disp,
    IDispatch *vv_disp,
    const char *path)
{
    int lg_rows = (lg && lg->rows > 0) ? lg->rows : 0;
    int lg_cols = (lg && lg->cols > 0) ? lg->cols : 0;
    int vv_rows = (vv && vv->rows > 0) ? vv->rows : 0;
    int vv_cols = (vv && vv->cols > 0) ? vv->cols : 0;
    int max_rows = lg_rows > vv_rows ? lg_rows : vv_rows;
    int max_cols = lg_cols > vv_cols ? lg_cols : vv_cols;
    long long total_cells = (long long)max_rows * (long long)max_cols;
    int diff_count = 0;
    int r;
    int c;
    FILE *f;

    if (!path || !*path || !lg_disp || !vv_disp) return -1;

    remove(path);

    f = fopen(path, "wb");
    if (!f) {
        printf("  CellTextDiff: failed to open %s\n", path);
        return -1;
    }

    fprintf(f, "Cell text diff [%02d] %s\n", test_no, test_name);
    fprintf(f, "Compared %lld cell slots including header and fixed cells\n", total_cells);
    fprintf(f, "LG size: %d rows x %d cols\n", lg_rows, lg_cols);
    fprintf(f, "VV size: %d rows x %d cols\n", vv_rows, vv_cols);
    fprintf(f, "\n");

    for (r = 0; r < max_rows; r++) {
        for (c = 0; c < max_cols; c++) {
            char *lg_value = get_cell_compare_value(lg_disp, r, c, lg_rows, lg_cols);
            char *vv_value = get_cell_compare_value(vv_disp, r, c, vv_rows, vv_cols);

            if (!lg_value) lg_value = dup_utf8_string("<oom>");
            if (!vv_value) vv_value = dup_utf8_string("<oom>");

            if (lg_value && vv_value && strcmp(lg_value, vv_value) != 0) {
                char *lg_escaped = escape_cell_text_for_diff_alloc(lg_value);
                char *vv_escaped = escape_cell_text_for_diff_alloc(vv_value);
                fprintf(
                    f,
                    "[r=%d c=%d] lg=\"%s\" vv=\"%s\"\n",
                    r,
                    c,
                    lg_escaped ? lg_escaped : "<oom>",
                    vv_escaped ? vv_escaped : "<oom>");
                free(lg_escaped);
                free(vv_escaped);
                diff_count++;
            }

            free(lg_value);
            free(vv_value);
        }
    }

    if (diff_count == 0) {
        fclose(f);
        remove(path);
        printf("  CellTextDiff: 0/%lld cells differ (including header)\n", total_cells);
        return 0;
    }

    fprintf(f, "\nSummary: %d/%lld cell slots differ\n", diff_count, total_cells);
    fclose(f);
    printf(
        "  CellTextDiff: %d/%lld cells differ (including header) -> %s\n",
        diff_count,
        total_cells,
        path);
    return diff_count;
}

static void pump_messages_ms(DWORD ms) {
    DWORD end = GetTickCount() + ms;
    MSG msg;
    for (;;) {
        while (PeekMessage(&msg, NULL, 0, 0, PM_REMOVE)) {
            TranslateMessage(&msg);
            DispatchMessage(&msg);
        }
        if ((LONG)(GetTickCount() - end) >= 0) break;
        Sleep(5);
    }
}

/* ── BMP writer ──────────────────────────────────────────── */

static void save_bmp(HDC hdcMem, HBITMAP hbm, int w, int h, const char *filename) {
    int stride = ((w * 3 + 3) & ~3);
    int dataSize = stride * h;
    BITMAPINFOHEADER bi = {0};
    bi.biSize = sizeof(bi);
    bi.biWidth = w;
    bi.biHeight = h;
    bi.biPlanes = 1;
    bi.biBitCount = 24;
    bi.biCompression = BI_RGB;
    bi.biSizeImage = dataSize;
    BYTE *pixels = (BYTE *)malloc(dataSize);
    GetDIBits(hdcMem, hbm, 0, h, pixels, (BITMAPINFO *)&bi, DIB_RGB_COLORS);
    BITMAPFILEHEADER bf = {0};
    bf.bfType = 0x4D42;
    bf.bfOffBits = sizeof(bf) + sizeof(bi);
    bf.bfSize = bf.bfOffBits + dataSize;
    FILE *f = fopen(filename, "wb");
    if (f) {
        fwrite(&bf, sizeof(bf), 1, f);
        fwrite(&bi, sizeof(bi), 1, f);
        fwrite(pixels, dataSize, 1, f);
        fclose(f);
        printf("  Saved: %s\n", filename);
    } else {
        printf("  FAIL: cannot open %s\n", filename);
    }
    free(pixels);
}

/* ── Render grid to BMP via IViewObject::Draw ────────────── */

static int render_to_bmp(IDispatch *pGrid, const char *filename, int w, int h) {
    IViewObject *pView = NULL;
    HRESULT hr = pGrid->lpVtbl->QueryInterface(pGrid, &IID_IViewObject, (void **)&pView);
    if (FAILED(hr) || !pView) {
        printf("  QueryInterface(IViewObject) failed: 0x%08lx\n", hr);
        return -1;
    }

    HDC hdcScreen = GetDC(NULL);
    HDC hdcMem = CreateCompatibleDC(hdcScreen);
    HBITMAP hbm = CreateCompatibleBitmap(hdcScreen, w, h);
    HGDIOBJ hOld = SelectObject(hdcMem, hbm);

    /* White background */
    RECT rc = { 0, 0, w, h };
    HBRUSH hBrush = CreateSolidBrush(RGB(255, 255, 255));
    FillRect(hdcMem, &rc, hBrush);
    DeleteObject(hBrush);

    RECTL rcl = { 0, 0, w, h };
    hr = pView->lpVtbl->Draw(pView, DVASPECT_CONTENT, -1, NULL, NULL,
                              NULL, hdcMem, &rcl, NULL, NULL, 0);
    if (FAILED(hr)) {
        printf("  IViewObject::Draw failed: 0x%08lx\n", hr);
    }

    save_bmp(hdcMem, hbm, w, h, filename);

    SelectObject(hdcMem, hOld);
    DeleteObject(hbm);
    DeleteDC(hdcMem);
    ReleaseDC(NULL, hdcScreen);
    pView->lpVtbl->Release(pView);
    return SUCCEEDED(hr) ? 0 : -1;
}

typedef struct HostSite HostSite;

typedef struct {
    IOleClientSiteVtbl *lpVtbl;
    HostSite *site;
} HostClientSite;

typedef struct {
    IOleInPlaceSiteVtbl *lpVtbl;
    HostSite *site;
} HostInPlaceSite;

typedef struct {
    IOleInPlaceFrameVtbl *lpVtbl;
    HostSite *site;
} HostInPlaceFrame;

struct HostSite {
    LONG ref;
    HWND hwnd_host;
    IOleInPlaceObject *inplace_obj;
    HostClientSite client;
    HostInPlaceSite inplace;
    HostInPlaceFrame frame;
};

static IOleClientSiteVtbl g_host_client_vtbl;
static IOleInPlaceSiteVtbl g_host_inplace_vtbl;
static IOleInPlaceFrameVtbl g_host_frame_vtbl;

static ULONG host_addref(HostSite *s) {
    return (ULONG)InterlockedIncrement(&s->ref);
}

static ULONG host_release(HostSite *s) {
    LONG c = InterlockedDecrement(&s->ref);
    if (c == 0) {
        if (s->inplace_obj) {
            s->inplace_obj->lpVtbl->Release(s->inplace_obj);
            s->inplace_obj = NULL;
        }
        free(s);
    }
    return (ULONG)c;
}

static HRESULT host_query_from_client(HostSite *s, REFIID riid, void **ppv) {
    if (!ppv) return E_POINTER;
    *ppv = NULL;

    if (IsEqualIID(riid, &IID_IUnknown) || IsEqualIID(riid, &IID_IOleClientSite)) {
        *ppv = &s->client;
        host_addref(s);
        return S_OK;
    }
    if (IsEqualIID(riid, &IID_IOleInPlaceSite) || IsEqualIID(riid, &IID_IOleWindow)) {
        *ppv = &s->inplace;
        host_addref(s);
        return S_OK;
    }
    if (IsEqualIID(riid, &IID_IOleInPlaceFrame) || IsEqualIID(riid, &IID_IOleInPlaceUIWindow)) {
        *ppv = &s->frame;
        host_addref(s);
        return S_OK;
    }
    return E_NOINTERFACE;
}

static HRESULT host_query_from_inplace(HostSite *s, REFIID riid, void **ppv) {
    if (!ppv) return E_POINTER;
    *ppv = NULL;

    if (IsEqualIID(riid, &IID_IUnknown) || IsEqualIID(riid, &IID_IOleInPlaceSite) || IsEqualIID(riid, &IID_IOleWindow)) {
        *ppv = &s->inplace;
        host_addref(s);
        return S_OK;
    }
    if (IsEqualIID(riid, &IID_IOleClientSite)) {
        *ppv = &s->client;
        host_addref(s);
        return S_OK;
    }
    if (IsEqualIID(riid, &IID_IOleInPlaceFrame) || IsEqualIID(riid, &IID_IOleInPlaceUIWindow)) {
        *ppv = &s->frame;
        host_addref(s);
        return S_OK;
    }
    return E_NOINTERFACE;
}

static HRESULT host_query_from_frame(HostSite *s, REFIID riid, void **ppv) {
    if (!ppv) return E_POINTER;
    *ppv = NULL;

    if (IsEqualIID(riid, &IID_IUnknown) || IsEqualIID(riid, &IID_IOleInPlaceFrame) || IsEqualIID(riid, &IID_IOleInPlaceUIWindow) || IsEqualIID(riid, &IID_IOleWindow)) {
        *ppv = &s->frame;
        host_addref(s);
        return S_OK;
    }
    if (IsEqualIID(riid, &IID_IOleClientSite)) {
        *ppv = &s->client;
        host_addref(s);
        return S_OK;
    }
    if (IsEqualIID(riid, &IID_IOleInPlaceSite)) {
        *ppv = &s->inplace;
        host_addref(s);
        return S_OK;
    }
    return E_NOINTERFACE;
}

static HRESULT STDMETHODCALLTYPE hs_client_qi(IOleClientSite *This, REFIID riid, void **ppv) {
    HostClientSite *cs = (HostClientSite *)This;
    return host_query_from_client(cs->site, riid, ppv);
}
static ULONG STDMETHODCALLTYPE hs_client_addref(IOleClientSite *This) {
    HostClientSite *cs = (HostClientSite *)This;
    return host_addref(cs->site);
}
static ULONG STDMETHODCALLTYPE hs_client_release(IOleClientSite *This) {
    HostClientSite *cs = (HostClientSite *)This;
    return host_release(cs->site);
}
static HRESULT STDMETHODCALLTYPE hs_client_save_object(IOleClientSite *This) {
    (void)This;
    return E_NOTIMPL;
}
static HRESULT STDMETHODCALLTYPE hs_client_get_moniker(IOleClientSite *This, DWORD a, DWORD b, IMoniker **ppmk) {
    (void)This; (void)a; (void)b;
    if (ppmk) *ppmk = NULL;
    return E_NOTIMPL;
}
static HRESULT STDMETHODCALLTYPE hs_client_get_container(IOleClientSite *This, IOleContainer **ppC) {
    (void)This;
    if (!ppC) return E_POINTER;
    *ppC = NULL;
    return E_NOINTERFACE;
}
static HRESULT STDMETHODCALLTYPE hs_client_show_object(IOleClientSite *This) {
    (void)This;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE hs_client_on_show_window(IOleClientSite *This, BOOL fShow) {
    (void)This; (void)fShow;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE hs_client_request_new_object_layout(IOleClientSite *This) {
    (void)This;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE hs_inplace_qi(IOleInPlaceSite *This, REFIID riid, void **ppv) {
    HostInPlaceSite *ips = (HostInPlaceSite *)This;
    return host_query_from_inplace(ips->site, riid, ppv);
}
static ULONG STDMETHODCALLTYPE hs_inplace_addref(IOleInPlaceSite *This) {
    HostInPlaceSite *ips = (HostInPlaceSite *)This;
    return host_addref(ips->site);
}
static ULONG STDMETHODCALLTYPE hs_inplace_release(IOleInPlaceSite *This) {
    HostInPlaceSite *ips = (HostInPlaceSite *)This;
    return host_release(ips->site);
}
static HRESULT STDMETHODCALLTYPE hs_inplace_get_window(IOleInPlaceSite *This, HWND *phwnd) {
    HostInPlaceSite *ips = (HostInPlaceSite *)This;
    if (!phwnd) return E_POINTER;
    *phwnd = ips->site->hwnd_host;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE hs_inplace_context_help(IOleInPlaceSite *This, BOOL fEnter) {
    (void)This; (void)fEnter;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE hs_inplace_can_activate(IOleInPlaceSite *This) {
    (void)This;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE hs_inplace_on_activate(IOleInPlaceSite *This) {
    (void)This;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE hs_inplace_on_ui_activate(IOleInPlaceSite *This) {
    (void)This;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE hs_inplace_get_window_context(
    IOleInPlaceSite *This,
    IOleInPlaceFrame **ppFrame,
    IOleInPlaceUIWindow **ppDoc,
    LPRECT lprcPosRect,
    LPRECT lprcClipRect,
    OLEINPLACEFRAMEINFO *lpFrameInfo)
{
    HostInPlaceSite *ips = (HostInPlaceSite *)This;
    RECT rc;

    if (ppFrame) {
        *ppFrame = (IOleInPlaceFrame *)&ips->site->frame;
        host_addref(ips->site);
    }
    if (ppDoc) *ppDoc = NULL;

    GetClientRect(ips->site->hwnd_host, &rc);
    if (lprcPosRect) *lprcPosRect = rc;
    if (lprcClipRect) *lprcClipRect = rc;

    if (lpFrameInfo) {
        memset(lpFrameInfo, 0, sizeof(*lpFrameInfo));
        lpFrameInfo->cb = sizeof(*lpFrameInfo);
        lpFrameInfo->fMDIApp = FALSE;
        lpFrameInfo->hwndFrame = ips->site->hwnd_host;
        lpFrameInfo->haccel = NULL;
        lpFrameInfo->cAccelEntries = 0;
    }

    return S_OK;
}
static HRESULT STDMETHODCALLTYPE hs_inplace_scroll(IOleInPlaceSite *This, SIZE sz) {
    (void)This; (void)sz;
    return E_NOTIMPL;
}
static HRESULT STDMETHODCALLTYPE hs_inplace_on_ui_deactivate(IOleInPlaceSite *This, BOOL fUndoable) {
    (void)This; (void)fUndoable;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE hs_inplace_on_deactivate(IOleInPlaceSite *This) {
    (void)This;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE hs_inplace_discard_undo(IOleInPlaceSite *This) {
    (void)This;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE hs_inplace_deactivate_and_undo(IOleInPlaceSite *This) {
    (void)This;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE hs_inplace_on_pos_rect_change(IOleInPlaceSite *This, LPCRECT lprcPosRect) {
    HostInPlaceSite *ips = (HostInPlaceSite *)This;
    if (ips->site->inplace_obj && lprcPosRect) {
        ips->site->inplace_obj->lpVtbl->SetObjectRects(
            ips->site->inplace_obj,
            lprcPosRect,
            lprcPosRect);
    }
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE hs_frame_qi(IOleInPlaceFrame *This, REFIID riid, void **ppv) {
    HostInPlaceFrame *f = (HostInPlaceFrame *)This;
    return host_query_from_frame(f->site, riid, ppv);
}
static ULONG STDMETHODCALLTYPE hs_frame_addref(IOleInPlaceFrame *This) {
    HostInPlaceFrame *f = (HostInPlaceFrame *)This;
    return host_addref(f->site);
}
static ULONG STDMETHODCALLTYPE hs_frame_release(IOleInPlaceFrame *This) {
    HostInPlaceFrame *f = (HostInPlaceFrame *)This;
    return host_release(f->site);
}
static HRESULT STDMETHODCALLTYPE hs_frame_get_window(IOleInPlaceFrame *This, HWND *phwnd) {
    HostInPlaceFrame *f = (HostInPlaceFrame *)This;
    if (!phwnd) return E_POINTER;
    *phwnd = f->site->hwnd_host;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE hs_frame_context_help(IOleInPlaceFrame *This, BOOL fEnter) {
    (void)This; (void)fEnter;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE hs_frame_get_border(IOleInPlaceFrame *This, LPRECT lprectBorder) {
    (void)This; (void)lprectBorder;
    return INPLACE_E_NOTOOLSPACE;
}
static HRESULT STDMETHODCALLTYPE hs_frame_request_border_space(IOleInPlaceFrame *This, LPCBORDERWIDTHS pborderwidths) {
    (void)This; (void)pborderwidths;
    return INPLACE_E_NOTOOLSPACE;
}
static HRESULT STDMETHODCALLTYPE hs_frame_set_border_space(IOleInPlaceFrame *This, LPCBORDERWIDTHS pborderwidths) {
    (void)This; (void)pborderwidths;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE hs_frame_set_active_object(IOleInPlaceFrame *This, IOleInPlaceActiveObject *pActiveObject, LPCOLESTR pszObjName) {
    (void)This; (void)pActiveObject; (void)pszObjName;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE hs_frame_insert_menus(IOleInPlaceFrame *This, HMENU hmenuShared, LPOLEMENUGROUPWIDTHS lpMenuWidths) {
    (void)This; (void)hmenuShared; (void)lpMenuWidths;
    return E_NOTIMPL;
}
static HRESULT STDMETHODCALLTYPE hs_frame_set_menu(IOleInPlaceFrame *This, HMENU hmenuShared, HOLEMENU holemenu, HWND hwndActiveObject) {
    (void)This; (void)hmenuShared; (void)holemenu; (void)hwndActiveObject;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE hs_frame_remove_menus(IOleInPlaceFrame *This, HMENU hmenuShared) {
    (void)This; (void)hmenuShared;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE hs_frame_set_status_text(IOleInPlaceFrame *This, LPCOLESTR pszStatusText) {
    (void)This; (void)pszStatusText;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE hs_frame_enable_modeless(IOleInPlaceFrame *This, BOOL fEnable) {
    (void)This; (void)fEnable;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE hs_frame_translate_accel(IOleInPlaceFrame *This, LPMSG lpmsg, WORD wID) {
    (void)This; (void)lpmsg; (void)wID;
    return S_FALSE;
}

static IOleClientSiteVtbl g_host_client_vtbl = {
    hs_client_qi,
    hs_client_addref,
    hs_client_release,
    hs_client_save_object,
    hs_client_get_moniker,
    hs_client_get_container,
    hs_client_show_object,
    hs_client_on_show_window,
    hs_client_request_new_object_layout
};

static IOleInPlaceSiteVtbl g_host_inplace_vtbl = {
    hs_inplace_qi,
    hs_inplace_addref,
    hs_inplace_release,
    hs_inplace_get_window,
    hs_inplace_context_help,
    hs_inplace_can_activate,
    hs_inplace_on_activate,
    hs_inplace_on_ui_activate,
    hs_inplace_get_window_context,
    hs_inplace_scroll,
    hs_inplace_on_ui_deactivate,
    hs_inplace_on_deactivate,
    hs_inplace_discard_undo,
    hs_inplace_deactivate_and_undo,
    hs_inplace_on_pos_rect_change
};

static IOleInPlaceFrameVtbl g_host_frame_vtbl = {
    hs_frame_qi,
    hs_frame_addref,
    hs_frame_release,
    hs_frame_get_window,
    hs_frame_context_help,
    hs_frame_get_border,
    hs_frame_request_border_space,
    hs_frame_set_border_space,
    hs_frame_set_active_object,
    hs_frame_insert_menus,
    hs_frame_set_menu,
    hs_frame_remove_menus,
    hs_frame_set_status_text,
    hs_frame_enable_modeless,
    hs_frame_translate_accel
};

static HostSite *host_site_create(HWND hwnd_host) {
    HostSite *s = (HostSite *)calloc(1, sizeof(HostSite));
    if (!s) return NULL;
    s->ref = 1;
    s->hwnd_host = hwnd_host;
    s->client.lpVtbl = &g_host_client_vtbl;
    s->client.site = s;
    s->inplace.lpVtbl = &g_host_inplace_vtbl;
    s->inplace.site = s;
    s->frame.lpVtbl = &g_host_frame_vtbl;
    s->frame.site = s;
    return s;
}

static const WCHAR HOST_WND_CLASS[] = L"VFG_CompareHostWindow";

static LRESULT CALLBACK host_wnd_proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    (void)wp; (void)lp;
    switch (msg) {
    case WM_ERASEBKGND:
        return 1;
    default:
        return DefWindowProcW(hwnd, msg, wp, lp);
    }
}

static int ensure_host_window_class(void) {
    static int registered = 0;
    if (registered) return 1;

    {
        WNDCLASSW wc;
        memset(&wc, 0, sizeof(wc));
        wc.lpfnWndProc = host_wnd_proc;
        wc.hInstance = GetModuleHandleW(NULL);
        wc.hCursor = LoadCursor(NULL, IDC_ARROW);
        wc.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
        wc.lpszClassName = HOST_WND_CLASS;

        if (!RegisterClassW(&wc)) {
            DWORD err = GetLastError();
            if (err != ERROR_CLASS_ALREADY_EXISTS) {
                return 0;
            }
        }
    }

    registered = 1;
    return 1;
}

static HWND create_host_window(int client_w, int client_h, const WCHAR *title, int x_offset) {
    RECT rc = {0, 0, client_w, client_h};
    HWND hwnd;

    if (!ensure_host_window_class()) return NULL;

    AdjustWindowRect(&rc, WS_OVERLAPPEDWINDOW, FALSE);
    hwnd = CreateWindowW(
        HOST_WND_CLASS,
        title,
        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
        80 + x_offset,
        80,
        rc.right - rc.left,
        rc.bottom - rc.top,
        NULL,
        NULL,
        GetModuleHandleW(NULL),
        NULL);

    if (!hwnd) return NULL;
    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);
    return hwnd;
}

typedef struct {
    HWND hwnd_host;
    HostSite *site;
    IOleObject *ole_obj;
    IOleInPlaceObject *inplace_obj;
    IDispatch *disp;
    int render_width;
    int render_height;
} HostedGrid;

static void hosted_grid_destroy(HostedGrid *hg) {
    if (!hg) return;

    if (hg->inplace_obj) {
        hg->inplace_obj->lpVtbl->InPlaceDeactivate(hg->inplace_obj);
    }

    if (hg->ole_obj) {
        hg->ole_obj->lpVtbl->Close(hg->ole_obj, OLECLOSE_NOSAVE);
        hg->ole_obj->lpVtbl->SetClientSite(hg->ole_obj, NULL);
    }

    if (hg->disp) {
        hg->disp->lpVtbl->Release(hg->disp);
        hg->disp = NULL;
    }

    if (hg->site) {
        hg->site->inplace_obj = NULL;
    }
    if (hg->inplace_obj) {
        hg->inplace_obj->lpVtbl->Release(hg->inplace_obj);
        hg->inplace_obj = NULL;
    }
    if (hg->ole_obj) {
        hg->ole_obj->lpVtbl->Release(hg->ole_obj);
        hg->ole_obj = NULL;
    }

    if (hg->site) {
        host_release(hg->site);
        hg->site = NULL;
    }

    if (hg->hwnd_host && IsWindow(hg->hwnd_host)) {
        DestroyWindow(hg->hwnd_host);
        hg->hwnd_host = NULL;
    }
}

static int hosted_grid_create(HostedGrid *hg, const WCHAR *progid, const WCHAR *title, int width, int height, int x_offset) {
    CLSID clsid;
    HRESULT hr;
    RECT rc;

    memset(hg, 0, sizeof(*hg));

    hg->hwnd_host = create_host_window(width, height, title, x_offset);
    if (!hg->hwnd_host) {
        printf("  Host window create failed\n");
        return -1;
    }

    hg->site = host_site_create(hg->hwnd_host);
    if (!hg->site) {
        printf("  Host site allocation failed\n");
        hosted_grid_destroy(hg);
        return -1;
    }

    hr = CLSIDFromProgID(progid, &clsid);
    if (FAILED(hr)) {
        printf("  CLSIDFromProgID failed: 0x%08lx\n", hr);
        hosted_grid_destroy(hg);
        return -1;
    }

    hr = CoCreateInstance(&clsid, NULL, CLSCTX_INPROC_SERVER, &IID_IOleObject, (void **)&hg->ole_obj);
    if (FAILED(hr) || !hg->ole_obj) {
        printf("  CoCreateInstance(IOleObject) failed: 0x%08lx\n", hr);
        hosted_grid_destroy(hg);
        return -1;
    }

    hg->ole_obj->lpVtbl->SetClientSite(hg->ole_obj, (IOleClientSite *)&hg->site->client);
    hg->ole_obj->lpVtbl->SetHostNames(hg->ole_obj, L"VFGHost", L"VFGDoc");
    OleSetContainedObject((IUnknown *)hg->ole_obj, TRUE);

    GetClientRect(hg->hwnd_host, &rc);
    hr = hg->ole_obj->lpVtbl->DoVerb(
        hg->ole_obj,
        OLEIVERB_INPLACEACTIVATE,
        NULL,
        (IOleClientSite *)&hg->site->client,
        0,
        hg->hwnd_host,
        &rc);
    if (FAILED(hr)) {
        printf("  DoVerb(INPLACEACTIVATE) failed: 0x%08lx\n", hr);
        hosted_grid_destroy(hg);
        return -1;
    }

    hr = hg->ole_obj->lpVtbl->QueryInterface(hg->ole_obj, &IID_IOleInPlaceObject, (void **)&hg->inplace_obj);
    if (SUCCEEDED(hr) && hg->inplace_obj) {
        hg->site->inplace_obj = hg->inplace_obj;
        hg->inplace_obj->lpVtbl->SetObjectRects(hg->inplace_obj, &rc, &rc);
    }

    hr = hg->ole_obj->lpVtbl->QueryInterface(hg->ole_obj, &IID_IDispatch, (void **)&hg->disp);
    if (FAILED(hr) || !hg->disp) {
        printf("  QueryInterface(IDispatch) failed: 0x%08lx\n", hr);
        hosted_grid_destroy(hg);
        return -1;
    }

    hg->render_width = width;
    hg->render_height = height;
    SetForegroundWindow(hg->hwnd_host);
    SetFocus(hg->hwnd_host);
    pump_messages_ms(120);
    return 0;
}

/* ════════════════════════════════════════════════════════════ */
/* VBScript engine via IActiveScript                            */
/* ════════════════════════════════════════════════════════════ */

/* Minimal IActiveScriptSite: provides "fg" named item */

typedef struct {
    IActiveScriptSiteVtbl *lpVtbl;
    IServiceProviderVtbl *lpVtblServiceProvider;
    LONG ref;
    IDispatch *grid;
} ScriptSite;

#define SCRIPT_SITE_FROM_SP(p) \
    ((ScriptSite *)((char *)(p) - offsetof(ScriptSite, lpVtblServiceProvider)))

static HRESULT STDMETHODCALLTYPE ss_qi(IActiveScriptSite *This, REFIID riid, void **ppv) {
    if (IsEqualGUID(riid, &IID_IUnknown) || IsEqualGUID(riid, &IID_IActiveScriptSite)) {
        *ppv = This;
        This->lpVtbl->AddRef(This);
        return S_OK;
    }
    if (IsEqualGUID(riid, &IID_IServiceProvider)) {
        ScriptSite *ss = (ScriptSite *)This;
        *ppv = (void *)&ss->lpVtblServiceProvider;
        This->lpVtbl->AddRef(This);
        return S_OK;
    }
    *ppv = NULL;
    return E_NOINTERFACE;
}
static ULONG STDMETHODCALLTYPE ss_addref(IActiveScriptSite *This) {
    return InterlockedIncrement(&((ScriptSite *)This)->ref);
}
static ULONG STDMETHODCALLTYPE ss_release(IActiveScriptSite *This) {
    return InterlockedDecrement(&((ScriptSite *)This)->ref);
}
static HRESULT STDMETHODCALLTYPE ss_getlcid(IActiveScriptSite *This, LCID *p) {
    *p = LOCALE_USER_DEFAULT;
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE ss_getiteminfo(
    IActiveScriptSite *This, LPCOLESTR name, DWORD mask,
    IUnknown **ppUnk, ITypeInfo **ppTI)
{
    ScriptSite *ss = (ScriptSite *)This;
    if (ppTI) *ppTI = NULL;
    if (ppUnk) *ppUnk = NULL;
    if (wcscmp(name, L"fg") == 0) {
        if ((mask & SCRIPTINFO_IUNKNOWN) && ppUnk) {
            *ppUnk = (IUnknown *)ss->grid;
            ss->grid->lpVtbl->AddRef(ss->grid);
        }
        return S_OK;
    }
    return TYPE_E_ELEMENTNOTFOUND;
}
static HRESULT STDMETHODCALLTYPE ss_docver(IActiveScriptSite *This, BSTR *p) {
    *p = SysAllocString(L"1.0");
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE ss_onterm(IActiveScriptSite *This,
    const VARIANT *pv, const EXCEPINFO *pe) { return S_OK; }
static HRESULT STDMETHODCALLTYPE ss_onstate(IActiveScriptSite *This,
    SCRIPTSTATE ss) { return S_OK; }
static HRESULT STDMETHODCALLTYPE ss_onerror(IActiveScriptSite *This,
    IActiveScriptError *pErr)
{
    EXCEPINFO ei;
    memset(&ei, 0, sizeof(ei));
    if (SUCCEEDED(pErr->lpVtbl->GetExceptionInfo(pErr, &ei))) {
        if (ei.bstrDescription)
            printf("  VBS error: %ls\n", ei.bstrDescription);
        SysFreeString(ei.bstrSource);
        SysFreeString(ei.bstrDescription);
        SysFreeString(ei.bstrHelpFile);
    }
    DWORD ctx; ULONG line; LONG ch;
    if (SUCCEEDED(pErr->lpVtbl->GetSourcePosition(pErr, &ctx, &line, &ch)))
        printf("  at line %lu, char %ld\n", (unsigned long)(line + 1), (long)ch);
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE ss_enter(IActiveScriptSite *This) { return S_OK; }
static HRESULT STDMETHODCALLTYPE ss_leave(IActiveScriptSite *This) { return S_OK; }

static HRESULT STDMETHODCALLTYPE sp_qi(IServiceProvider *This, REFIID riid, void **ppv) {
    ScriptSite *ss = SCRIPT_SITE_FROM_SP(This);
    return ss_qi((IActiveScriptSite *)ss, riid, ppv);
}
static ULONG STDMETHODCALLTYPE sp_addref(IServiceProvider *This) {
    ScriptSite *ss = SCRIPT_SITE_FROM_SP(This);
    return ss_addref((IActiveScriptSite *)ss);
}
static ULONG STDMETHODCALLTYPE sp_release(IServiceProvider *This) {
    ScriptSite *ss = SCRIPT_SITE_FROM_SP(This);
    return ss_release((IActiveScriptSite *)ss);
}
static HRESULT STDMETHODCALLTYPE sp_queryservice(
    IServiceProvider *This, REFGUID guidService, REFIID riid, void **ppv)
{
    (void)This;
    (void)guidService;
    (void)riid;
    if (ppv) *ppv = NULL;
    return E_NOINTERFACE;
}

static IServiceProviderVtbl g_sp_vtbl = {
    sp_qi, sp_addref, sp_release, sp_queryservice
};

static IActiveScriptSiteVtbl g_ss_vtbl = {
    ss_qi, ss_addref, ss_release,
    ss_getlcid, ss_getiteminfo, ss_docver,
    ss_onterm, ss_onstate, ss_onerror,
    ss_enter, ss_leave
};

/* VBS preamble: defines helper arrays and PopulateStandard sub.
 * Prepended to every test script. */
static const WCHAR g_vbs_preamble[] =
    L"Dim products : products = Array(\"Widget A\", \"Widget B\", \"Gadget X\", \"Gadget Y\", \"Tool Z\")\r\n"
    L"Dim categories : categories = Array(\"Electronics\", \"Electronics\", \"Hardware\", \"Hardware\", \"Tools\")\r\n"
    L"Dim regions : regions = Array(\"North\", \"South\", \"East\", \"West\")\r\n"
    L"Dim sales : sales = Array(1200, 3400, 5600, 7800, 2300, 4500, 6700, 8900, 1100, 3300, 5500, 7700, 9900, 2200, 4400, 6600, 8800, 1000, 3200, 5400)\r\n"
    L"\r\n"
    L"Sub PopulateStandard()\r\n"
    L"    fg.Redraw = 0\r\n"
    L"    fg.Cols = 5\r\n"
    L"    fg.Rows = 21\r\n"
    L"    fg.FixedRows = 1\r\n"
    L"    fg.FixedCols = 0\r\n"
    L"    fg.TextMatrix(0, 0) = \"Product\"\r\n"
    L"    fg.TextMatrix(0, 1) = \"Category\"\r\n"
    L"    fg.TextMatrix(0, 2) = \"Sales\"\r\n"
    L"    fg.TextMatrix(0, 3) = \"Quarter\"\r\n"
    L"    fg.TextMatrix(0, 4) = \"Region\"\r\n"
    L"    Dim i\r\n"
    L"    For i = 1 To 20\r\n"
    L"        fg.TextMatrix(i, 0) = products((i - 1) Mod 5)\r\n"
    L"        fg.TextMatrix(i, 1) = categories((i - 1) Mod 5)\r\n"
    L"        fg.TextMatrix(i, 2) = CStr(sales(i - 1))\r\n"
    L"        fg.TextMatrix(i, 3) = \"Q\" & CStr(((i - 1) Mod 4) + 1)\r\n"
    L"        fg.TextMatrix(i, 4) = regions((i - 1) Mod 4)\r\n"
    L"    Next\r\n"
    L"    fg.Redraw = 1\r\n"
    L"End Sub\r\n"
    L"\r\n"
    L"' Legacy-compatible sort helper\r\n"
    L"Sub SortColumn(order, col)\r\n"
    L"    fg.Col = col\r\n"
    L"    fg.ColSel = col\r\n"
    L"    fg.Sort = order\r\n"
    L"End Sub\r\n"
    L"\r\n"
    L"' Legacy-compatible cell flood helper\r\n"
    L"Sub SetCellFlood(row, col, oleColor, percent)\r\n"
    L"    Dim prevRow, prevCol\r\n"
    L"    prevRow = fg.Row\r\n"
    L"    prevCol = fg.Col\r\n"
    L"    fg.Row = row\r\n"
    L"    fg.Col = col\r\n"
    L"    On Error Resume Next\r\n"
    L"    fg.CellFloodColor = oleColor\r\n"
    L"    fg.CellFloodPercent = percent\r\n"
    L"    If Err.Number <> 0 Then\r\n"
    L"        Err.Clear\r\n"
    L"        fg.CellFlood row, col, oleColor, percent\r\n"
    L"    End If\r\n"
    L"    On Error GoTo 0\r\n"
    L"    fg.Row = prevRow\r\n"
    L"    fg.Col = prevCol\r\n"
    L"End Sub\r\n"
    L"\r\n"
    L"' Legacy-compatible cell checked helper\r\n"
    L"Sub SetCellChecked(row, col, state)\r\n"
    L"    Dim prevRow, prevCol\r\n"
    L"    prevRow = fg.Row\r\n"
    L"    prevCol = fg.Col\r\n"
    L"    fg.Row = row\r\n"
    L"    fg.Col = col\r\n"
    L"    On Error Resume Next\r\n"
    L"    fg.CellChecked = state\r\n"
    L"    If Err.Number <> 0 Then\r\n"
    L"        Err.Clear\r\n"
    L"        fg.CellChecked(row, col) = state\r\n"
    L"    End If\r\n"
    L"    On Error GoTo 0\r\n"
    L"    fg.Row = prevRow\r\n"
    L"    fg.Col = prevCol\r\n"
    L"End Sub\r\n"
    L"\r\n"

    L"Rem Shared ADO and live SQL helpers for compare tests\r\n"
    L"Const adInteger = 3\r\n"
    L"Const adDouble = 5\r\n"
    L"Const adCurrency = 6\r\n"
    L"Const adDate = 7\r\n"
    L"Const adBoolean = 11\r\n"
    L"Const adVariant = 12\r\n"
    L"Const adVarChar = 200\r\n"
    L"Const adUseClient = 3\r\n"  /* adUseServer (2) requires MSDAINITIALIZE
                                      and OLEDB_CONVERSIONLIBRARY COM classes
                                      that are OS-level Windows components, not
                                      part of the MDAC 2.8 SP1 redistributable.
                                      Wine does not provide them, so we must use
                                      adUseClient (3) which routes through the
                                      ADO client cursor engine (msadce.dll)
                                      instead. */
    L"Const adOpenKeyset = 1\r\n"
    L"Const adOpenStatic = 3\r\n"
    L"Const adLockReadOnly = 1\r\n"
    L"Const adLockOptimistic = 3\r\n"
    L"Const adCmdText = 1\r\n"
    L"\r\n"
    L"Dim g_sqlConn\r\n"
    L"Dim g_sqlTableSeq\r\n"
    L"Dim g_sqlLastError\r\n"
    L"Set g_sqlConn = Nothing\r\n"
    L"g_sqlTableSeq = 0\r\n"
    L"g_sqlLastError = \"\"\r\n"
    L"Randomize Timer\r\n"
    L"\r\n"
    L"Sub SetupBoundFallback(title, detail)\r\n"
    L"    Err.Clear\r\n"
    L"    fg.Redraw = False\r\n"
    L"    fg.Cols = 2\r\n"
    L"    fg.Rows = 2\r\n"
    L"    fg.FixedRows = 1\r\n"
    L"    fg.FixedCols = 0\r\n"
    L"    fg.TextMatrix(0, 0) = title\r\n"
    L"    fg.TextMatrix(0, 1) = \"Status\"\r\n"
    L"    fg.TextMatrix(1, 0) = \"SQL\"\r\n"
    L"    fg.TextMatrix(1, 1) = detail\r\n"
    L"    fg.Redraw = True\r\n"
    L"End Sub\r\n"
    L"\r\n"
    L"Function SqlStatus(defaultText)\r\n"
    L"    If Len(g_sqlLastError) > 0 Then\r\n"
    L"        SqlStatus = g_sqlLastError\r\n"
    L"    Else\r\n"
    L"        SqlStatus = defaultText\r\n"
    L"    End If\r\n"
    L"End Function\r\n"
    L"\r\n"
    L"Function ReadProcessEnv(name, fallbackValue)\r\n"
    L"    On Error Resume Next\r\n"
    L"    Dim sh, env, value\r\n"
    L"    value = \"\"\r\n"
    L"    Set sh = CreateObject(\"WScript.Shell\")\r\n"
    L"    If Err.Number = 0 Then\r\n"
    L"        Set env = sh.Environment(\"PROCESS\")\r\n"
    L"        value = env(name)\r\n"
    L"    End If\r\n"
    L"    Err.Clear\r\n"
    L"    On Error GoTo 0\r\n"
    L"    If Len(value) = 0 Then value = fallbackValue\r\n"
    L"    ReadProcessEnv = value\r\n"
    L"End Function\r\n"
    L"\r\n"
    L"Function BuildSqlConnectionString()\r\n"
    L"    Dim serverName, databaseName, userName, passwordText\r\n"
    L"    serverName = ReadProcessEnv(\"VFG_SQL_SERVER\", \"127.0.0.1,1433\")\r\n"
    L"    databaseName = ReadProcessEnv(\"VFG_SQL_DATABASE\", \"tempdb\")\r\n"
    L"    userName = ReadProcessEnv(\"VFG_SQL_USER\", \"sa\")\r\n"
    L"    passwordText = ReadProcessEnv(\"VFG_SQL_PASSWORD\", \"sapassword12#\" & Chr(36) & \"%\")\r\n"
    L"    BuildSqlConnectionString = \"Provider=SQLOLEDB.1;Network Library=DBMSSOCN;Data Source=\" & serverName & \";Initial Catalog=\" & databaseName & \";User ID=\" & userName & \";Password=\" & passwordText & \";Persist Security Info=True;\"\r\n"
    L"End Function\r\n"
    L"\r\n"
    L"Sub SetSqlLastError(prefix)\r\n"
    L"    If Err.Number <> 0 Then\r\n"
    L"        g_sqlLastError = prefix & \" Err=\" & CStr(Err.Number)\r\n"
    L"        If Len(Err.Description) > 0 Then g_sqlLastError = g_sqlLastError & \" \" & Err.Description\r\n"
    L"        Err.Clear\r\n"
    L"    Else\r\n"
    L"        g_sqlLastError = prefix\r\n"
    L"    End If\r\n"
    L"End Sub\r\n"
    L"\r\n"
    L"Function OpenSqlConnection()\r\n"
    L"    On Error Resume Next\r\n"
    L"    g_sqlLastError = \"\"\r\n"
    L"    If Not (g_sqlConn Is Nothing) Then\r\n"
    L"        If g_sqlConn.State = 1 Then\r\n"
    L"            Set OpenSqlConnection = g_sqlConn\r\n"
    L"            Exit Function\r\n"
    L"        End If\r\n"
    L"    End If\r\n"
    L"    Set g_sqlConn = CreateObject(\"ADODB.Connection\")\r\n"
    L"    If Err.Number <> 0 Then\r\n"
    L"        SetSqlLastError \"Create ADODB.Connection failed\"\r\n"
    L"        Set g_sqlConn = Nothing\r\n"
    L"        Set OpenSqlConnection = Nothing\r\n"
    L"        Exit Function\r\n"
    L"    End If\r\n"
    L"    g_sqlConn.ConnectionTimeout = 15\r\n"
    L"    g_sqlConn.CommandTimeout = 15\r\n"
    L"    g_sqlConn.Open BuildSqlConnectionString()\r\n"
    L"    If Err.Number <> 0 Then\r\n"
    L"        SetSqlLastError \"SQL connect failed\"\r\n"
    L"        Set g_sqlConn = Nothing\r\n"
    L"        Set OpenSqlConnection = Nothing\r\n"
    L"        Exit Function\r\n"
    L"    End If\r\n"
    L"    g_sqlConn.Execute \"SET NOCOUNT ON\"\r\n"
    L"    If Err.Number <> 0 Then\r\n"
    L"        SetSqlLastError \"SQL session init failed\"\r\n"
    L"        Set g_sqlConn = Nothing\r\n"
    L"        Set OpenSqlConnection = Nothing\r\n"
    L"        Exit Function\r\n"
    L"    End If\r\n"
    L"    Set OpenSqlConnection = g_sqlConn\r\n"
    L"    On Error GoTo 0\r\n"
    L"End Function\r\n"
    L"\r\n"
    L"Function SqlIdentifier(name)\r\n"
    L"    SqlIdentifier = \"[\" & Replace(CStr(name), \"]\", \"]]\") & \"]\"\r\n"
    L"End Function\r\n"
    L"\r\n"
    L"Function CreateBoundRecordset(fieldNames, fieldTypes, fieldSizes)\r\n"
    L"    On Error Resume Next\r\n"
    L"    Dim rs, i\r\n"
    L"    Set rs = CreateObject(\"ADODB.Recordset\")\r\n"
    L"    If Err.Number <> 0 Then\r\n"
    L"        Err.Clear\r\n"
    L"        Set CreateBoundRecordset = Nothing\r\n"
    L"        Exit Function\r\n"
    L"    End If\r\n"
    L"    rs.CursorLocation = 3\r\n"
    L"    rs.CursorType = 3\r\n"
    L"    rs.LockType = 3\r\n"
    L"    For i = 0 To UBound(fieldNames)\r\n"
    L"        If fieldSizes(i) > 0 Then\r\n"
    L"            rs.Fields.Append fieldNames(i), fieldTypes(i), fieldSizes(i)\r\n"
    L"        Else\r\n"
    L"            rs.Fields.Append fieldNames(i), fieldTypes(i)\r\n"
    L"        End If\r\n"
    L"    Next\r\n"
    L"    rs.Open\r\n"
    L"    If Err.Number <> 0 Then\r\n"
    L"        Err.Clear\r\n"
    L"        Set CreateBoundRecordset = Nothing\r\n"
    L"        Exit Function\r\n"
    L"    End If\r\n"
    L"    Set CreateBoundRecordset = rs\r\n"
    L"    On Error GoTo 0\r\n"
    L"End Function\r\n"
    L"\r\n"
    L"Sub AppendRecord(rs, values)\r\n"
    L"    Dim i\r\n"
    L"    rs.AddNew\r\n"
    L"    For i = 0 To UBound(values)\r\n"
    L"        rs.Fields(i).Value = values(i)\r\n"
    L"    Next\r\n"
    L"    rs.Update\r\n"
    L"End Sub\r\n"
    L"\r\n"
    L"Function SqlTypeName(adoType, fieldSize)\r\n"
    L"    Select Case adoType\r\n"
    L"        Case adInteger\r\n"
    L"            SqlTypeName = \"int\"\r\n"
    L"        Case adDouble\r\n"
    L"            SqlTypeName = \"float\"\r\n"
    L"        Case adCurrency\r\n"
    L"            SqlTypeName = \"money\"\r\n"
    L"        Case adDate\r\n"
    L"            SqlTypeName = \"datetime\"\r\n"
    L"        Case adBoolean\r\n"
    L"            SqlTypeName = \"bit\"\r\n"
    L"        Case adVarChar\r\n"
    L"            If fieldSize < 1 Then fieldSize = 255\r\n"
    L"            If fieldSize > 8000 Then fieldSize = 8000\r\n"
    L"            SqlTypeName = \"varchar(\" & CStr(fieldSize) & \")\"\r\n"
    L"        Case Else\r\n"
    L"            SqlTypeName = \"varchar(255)\"\r\n"
    L"    End Select\r\n"
    L"End Function\r\n"
    L"\r\n"
    L"Function SqlDateTimeText(value)\r\n"
    L"    SqlDateTimeText = Right(\"0000\" & CStr(Year(value)), 4) & \"-\" & Right(\"00\" & CStr(Month(value)), 2) & \"-\" & Right(\"00\" & CStr(Day(value)), 2) & \" \" & Right(\"00\" & CStr(Hour(value)), 2) & \":\" & Right(\"00\" & CStr(Minute(value)), 2) & \":\" & Right(\"00\" & CStr(Second(value)), 2)\r\n"
    L"End Function\r\n"
    L"\r\n"
    L"Function SqlStringLiteral(value)\r\n"
    L"    SqlStringLiteral = Chr(39) & Replace(CStr(value), Chr(39), Chr(39) & Chr(39)) & Chr(39)\r\n"
    L"End Function\r\n"
    L"\r\n"
    L"Function SqlNumberLiteral(value)\r\n"
    L"    Dim txt\r\n"
    L"    txt = Trim(Str(CDbl(value)))\r\n"
    L"    txt = Replace(txt, \",\", \".\")\r\n"
    L"    SqlNumberLiteral = txt\r\n"
    L"End Function\r\n"
    L"\r\n"
    L"Function SqlValueLiteral(value, adoType)\r\n"
    L"    If IsNull(value) Then\r\n"
    L"        SqlValueLiteral = \"NULL\"\r\n"
    L"        Exit Function\r\n"
    L"    End If\r\n"
    L"    Select Case adoType\r\n"
    L"        Case adInteger\r\n"
    L"            SqlValueLiteral = CStr(CLng(value))\r\n"
    L"        Case adDouble, adCurrency\r\n"
    L"            SqlValueLiteral = SqlNumberLiteral(value)\r\n"
    L"        Case adBoolean\r\n"
    L"            If CBool(value) Then\r\n"
    L"                SqlValueLiteral = \"1\"\r\n"
    L"            Else\r\n"
    L"                SqlValueLiteral = \"0\"\r\n"
    L"            End If\r\n"
    L"        Case adDate\r\n"
    L"            SqlValueLiteral = Chr(39) & SqlDateTimeText(value) & Chr(39)\r\n"
    L"        Case Else\r\n"
    L"            SqlValueLiteral = SqlStringLiteral(value)\r\n"
    L"    End Select\r\n"
    L"End Function\r\n"
    L"\r\n"
    L"Function BuildSqlColumnDefinitions(fieldNames, fieldTypes, fieldSizes)\r\n"
    L"    Dim sqlText, i\r\n"
    L"    sqlText = \"__vfg_pk int IDENTITY(1,1) NOT NULL PRIMARY KEY\"\r\n"
    L"    For i = 0 To UBound(fieldNames)\r\n"
    L"        sqlText = sqlText & \", \" & SqlIdentifier(fieldNames(i)) & \" \" & SqlTypeName(fieldTypes(i), fieldSizes(i))\r\n"
    L"    Next\r\n"
    L"    BuildSqlColumnDefinitions = sqlText\r\n"
    L"End Function\r\n"
    L"\r\n"
    L"Function BuildSqlFieldList(fieldNames)\r\n"
    L"    Dim sqlText, i\r\n"
    L"    sqlText = \"\"\r\n"
    L"    For i = 0 To UBound(fieldNames)\r\n"
    L"        If i > 0 Then sqlText = sqlText & \", \"\r\n"
    L"        sqlText = sqlText & SqlIdentifier(fieldNames(i))\r\n"
    L"    Next\r\n"
    L"    BuildSqlFieldList = sqlText\r\n"
    L"End Function\r\n"
    L"\r\n"
    L"Function BuildSqlRowValues(fieldTypes, values)\r\n"
    L"    Dim sqlText, i\r\n"
    L"    sqlText = \"\"\r\n"
    L"    For i = 0 To UBound(fieldTypes)\r\n"
    L"        If i > 0 Then sqlText = sqlText & \", \"\r\n"
    L"        sqlText = sqlText & SqlValueLiteral(values(i), fieldTypes(i))\r\n"
    L"    Next\r\n"
    L"    BuildSqlRowValues = sqlText\r\n"
    L"End Function\r\n"
    L"\r\n"
    L"Function NextSqlTableName()\r\n"
    L"    g_sqlTableSeq = g_sqlTableSeq + 1\r\n"
    L"    NextSqlTableName = \"#vfg_sql_\" & CStr(CLng(Timer * 1000)) & \"_\" & CStr(g_sqlTableSeq)\r\n"
    L"End Function\r\n"
    L"\r\n"
    L"Function OpenSqlRecordset(selectSql, cursorType, lockType)\r\n"
    L"    On Error Resume Next\r\n"
    L"    Dim cn, rs\r\n"
    L"    g_sqlLastError = \"\"\r\n"
    L"    Set cn = OpenSqlConnection()\r\n"
    L"    If cn Is Nothing Then\r\n"
    L"        Set OpenSqlRecordset = Nothing\r\n"
    L"        Exit Function\r\n"
    L"    End If\r\n"
    L"    Set rs = CreateObject(\"ADODB.Recordset\")\r\n"
    L"    If Err.Number <> 0 Then\r\n"
    L"        SetSqlLastError \"Create ADODB.Recordset failed\"\r\n"
    L"        Set OpenSqlRecordset = Nothing\r\n"
    L"        Exit Function\r\n"
    L"    End If\r\n"
    L"    rs.CursorLocation = adUseClient\r\n"  /* see adUseClient comment above */
    L"    rs.Open selectSql, cn, cursorType, lockType, adCmdText\r\n"
    L"    If Err.Number <> 0 Then\r\n"
    L"        SetSqlLastError \"SQL query failed\"\r\n"
    L"        Set OpenSqlRecordset = Nothing\r\n"
    L"        Exit Function\r\n"
    L"    End If\r\n"
    L"    Set OpenSqlRecordset = rs\r\n"
    L"    On Error GoTo 0\r\n"
    L"End Function\r\n"
    L"\r\n"
    L"Function OpenSqlQueryRecordset(selectSql)\r\n"
    L"    Set OpenSqlQueryRecordset = OpenSqlRecordset(selectSql, adOpenStatic, adLockReadOnly)\r\n"
    L"End Function\r\n"
    L"\r\n"
    L"Function OpenSqlTableRecordset(selectSql)\r\n"
    L"    Set OpenSqlTableRecordset = OpenSqlRecordset(selectSql, adOpenKeyset, adLockOptimistic)\r\n"
    L"End Function\r\n"
    L"\r\n"
    L"Function CreateSequenceRows(maxN)\r\n"
    L"    Dim rows(), i\r\n"
    L"    ReDim rows(maxN - 1)\r\n"
    L"    For i = 1 To maxN\r\n"
    L"        rows(i - 1) = Array(i)\r\n"
    L"    Next\r\n"
    L"    CreateSequenceRows = rows\r\n"
    L"End Function\r\n"
    L"\r\n"
    L"Function CreateSqlRecordset(fieldNames, fieldTypes, fieldSizes, rows)\r\n"
    L"    On Error Resume Next\r\n"
    L"    Dim cn, tableName, fieldList, i, rowSql\r\n"
    L"    g_sqlLastError = \"\"\r\n"
    L"    Set cn = OpenSqlConnection()\r\n"
    L"    If cn Is Nothing Then\r\n"
    L"        Set CreateSqlRecordset = Nothing\r\n"
    L"        Exit Function\r\n"
    L"    End If\r\n"
    L"    tableName = NextSqlTableName()\r\n"
    L"    fieldList = BuildSqlFieldList(fieldNames)\r\n"
    L"    cn.Execute \"CREATE TABLE \" & tableName & \" (\" & BuildSqlColumnDefinitions(fieldNames, fieldTypes, fieldSizes) & \")\"\r\n"
    L"    If Err.Number <> 0 Then\r\n"
    L"        SetSqlLastError \"SQL create table failed\"\r\n"
    L"        Set CreateSqlRecordset = Nothing\r\n"
    L"        Exit Function\r\n"
    L"    End If\r\n"
    L"    For i = 0 To UBound(rows)\r\n"
    L"        rowSql = \"INSERT INTO \" & tableName & \" (\" & fieldList & \") VALUES (\" & BuildSqlRowValues(fieldTypes, rows(i)) & \")\"\r\n"
    L"        cn.Execute rowSql\r\n"
    L"        If Err.Number <> 0 Then\r\n"
    L"            SetSqlLastError \"SQL insert failed\"\r\n"
    L"            Set CreateSqlRecordset = Nothing\r\n"
    L"            Exit Function\r\n"
    L"        End If\r\n"
    L"    Next\r\n"
    L"    Set CreateSqlRecordset = OpenSqlTableRecordset(\"SELECT \" & fieldList & \" FROM \" & tableName & \" ORDER BY __vfg_pk\")\r\n"
    L"    On Error GoTo 0\r\n"
    L"End Function\r\n"
    L"\r\n";


/* Load a UTF-8 text file and return wide string (malloc'd). */
static WCHAR *load_file_wide(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    char *buf = (char *)malloc(sz + 1);
    fread(buf, 1, sz, f);
    buf[sz] = '\0';
    fclose(f);
    /* Convert UTF-8 to wide */
    int wlen = MultiByteToWideChar(CP_UTF8, 0, buf, -1, NULL, 0);
    WCHAR *wbuf = (WCHAR *)malloc(wlen * sizeof(WCHAR));
    MultiByteToWideChar(CP_UTF8, 0, buf, -1, wbuf, wlen);
    free(buf);
    return wbuf;
}

/* Execute VBScript code with "fg" bound to the grid IDispatch. */
static HRESULT run_vbs(IDispatch *grid, const WCHAR *code) {
    ScriptSite site;
    site.lpVtbl = &g_ss_vtbl;
    site.lpVtblServiceProvider = &g_sp_vtbl;
    site.ref = 1;
    site.grid = grid;

    IActiveScript *pAS = NULL;
    HRESULT hr = CoCreateInstance(&CLSID_VBScript, NULL, CLSCTX_INPROC_SERVER,
                                   &IID_IActiveScript, (void **)&pAS);
    if (FAILED(hr)) {
        printf("  CoCreateInstance(VBScript) failed: 0x%08lx\n", hr);
        return hr;
    }

    IActiveScriptParse *pASP = NULL;
    hr = pAS->lpVtbl->QueryInterface(pAS, &MY_IID_IActiveScriptParse, (void **)&pASP);
    if (FAILED(hr)) {
        printf("  QI(IActiveScriptParse) failed: 0x%08lx\n", hr);
        pAS->lpVtbl->Release(pAS);
        return hr;
    }

    pASP->lpVtbl->InitNew(pASP);
    pAS->lpVtbl->SetScriptSite(pAS, (IActiveScriptSite *)&site);
    pAS->lpVtbl->AddNamedItem(pAS, L"fg",
        SCRIPTITEM_ISVISIBLE | SCRIPTITEM_ISSOURCE);

    /* Concatenate preamble + test code */
    int preamble_len = (int)wcslen(g_vbs_preamble);
    int code_len = (int)wcslen(code);
    WCHAR *full = (WCHAR *)malloc((preamble_len + code_len + 1) * sizeof(WCHAR));
    memcpy(full, g_vbs_preamble, preamble_len * sizeof(WCHAR));
    memcpy(full + preamble_len, code, (code_len + 1) * sizeof(WCHAR));

    EXCEPINFO ei;
    memset(&ei, 0, sizeof(ei));
    hr = pASP->lpVtbl->ParseScriptText(pASP, full, NULL, NULL, NULL,
                                         0, 0, 0, NULL, &ei);
    free(full);

    if (SUCCEEDED(hr))
        pAS->lpVtbl->SetScriptState(pAS, SCRIPTSTATE_CONNECTED);

    pAS->lpVtbl->Close(pAS);
    pASP->lpVtbl->Release(pASP);
    pAS->lpVtbl->Release(pAS);
    return hr;
}

/* ── Test table ──────────────────────────────────────────── */

typedef struct {
    const char *name;
    int         width;
    int         height;
} TestCase;

static TestCase g_tests[] = {
    { "default",            800, 400 },
    { "colors",             800, 400 },
    { "alternate_rows",     800, 400 },
    { "gridlines",          800, 400 },
    { "selection_row",      800, 400 },
    { "selection_col",      800, 400 },
    { "focus_rect",         800, 400 },
    { "col_alignment",      800, 400 },
    { "col_widths",         800, 400 },
    { "row_heights",        800, 400 },
    { "merge_cells",        600, 350 },
    { "word_wrap",          700, 400 },
    { "frozen",             800, 400 },
    { "sort",               800, 400 },
    { "subtotals",          800, 500 },
    { "checkboxes",         500, 300 },
    { "cell_flood",         500, 300 },
    { "hidden",             800, 400 },
    { "fixed_alignment",    800, 400 },
    { "ellipsis",           400, 250 },
    { "extend_last_col",    800, 400 },
    { "additem",            500, 250 },
    { "range_selection",    800, 400 },
    { "gridlines_inset",    800, 400 },
    { "gridlines_horz",     800, 400 },
    { "gridlines_vert",     800, 400 },
    { "outline_styles",     800, 500 },
    { "subtotal_above",     800, 500 },
    { "selection_listbox",  800, 400 },
    { "fill_style",         800, 400 },
    { "large_grid",         800, 500 },
    { "scrolled",           800, 400 },
    { "no_gridlines",       800, 400 },
    { "focus_rect_inset",   800, 400 },
    { "multi_fixed",        700, 350 },
    { "unicode",            800, 350 },
    { "multi_hierarchy",    800, 500 },
    { "autosize",           800, 300 },
    { "removeitem",         500, 300 },
    { "cell_flood_colors",  700, 350 },
    { "cell_checked_states", 700, 300 },
    { "clear_repopulate",   500, 250 },
    { "redraw_batch",       800, 400 },
    { "merge_row",          700, 350 },
    { "sort_descending",    800, 400 },
    { "erp_ledger",         900, 400 },
    { "merge_both",         700, 400 },
    { "scroll_bars_none",   800, 400 },
    { "outline_collapse",   800, 500 },
    { "wide_report",        1000, 350 },
    { "many_hidden_cols",   800, 300 },
    { "subtotal_sum",       800, 500 },
    { "sort_then_merge",    800, 400 },
    { "three_level_subtotal", 800, 600 },
    { "allow_big_selection", 800, 400 },
    { "frozen_merge",       700, 400 },
    { "mixed_alignment",    700, 500 },
    { "cell_range_copy",    800, 350 },
    { "row_state_marks",   800, 350 },
    { "col_combo_lists",   800, 380 },
    { "sort_findrow_toprow", 800, 420 },
    { "fixedrow_bold_esscols", 820, 420 },
    { "colformat_editmask", 800, 380 },
    { "visible_row_recovery", 800, 360 },
    { "event_edit_hooks", 820, 420 },
    { "datasource_bind", 840, 400 },
    { "data_roundtrip_refresh", 840, 400 },
    { "ado_properties_refresh", 840, 400 },
    { "ado_clone_bind", 840, 400 },
    { "ado_filter_refresh", 840, 400 },
    { "ado_null_display", 840, 400 },
    { "ado_source_swap", 840, 400 },
    { "ado_datamember_bind", 840, 400 },
    { "ado_move_cursor_ops", 840, 400 },
    { "ado_absoluteposition_ops", 840, 400 },
    { "ado_find_ops", 840, 400 },
    { "ado_bookmark_ops", 840, 400 },
    { "ado_bound_immediate_edit", 840, 400 },
    { "ado_bound_batch_edit", 840, 400 },
    { "ado_external_addnew_ops", 840, 400 },
    { "ado_external_delete_ops", 840, 400 },
    { "ado_bound_additem_ops", 840, 400 },
    { "ado_bound_removeitem_ops", 840, 400 },
    { "sql_connect_basic", 840, 400 },
    { "sql_datatypes", 840, 400 },
    { "sql_nulls", 840, 400 },
    { "sql_datamode_0", 840, 400 },
    { "sql_datamode_1_read_only", 840, 400 },
    { "sql_datamode_1_updatable", 840, 400 },
    { "sql_col_formatting", 840, 400 },
    { "sql_edit_update", 840, 400 },
    { "sql_additem_error", 840, 400 },
    { "sql_col_alignment", 840, 400 },
    { "sql_auto_resize", 840, 400 },
    { "sql_sort_live", 840, 400 },
    { "sql_colkey_mapping", 840, 400 },
    { "sql_boolean_checkboxes", 840, 400 },
    { "sql_large_rowset", 840, 400 },
    { "sql_subtotals", 840, 400 },
    { "sql_refresh", 840, 400 },
    { "sql_unbind", 840, 400 },
    { "sql_rebind", 840, 400 },
    { "sql_error_handling", 840, 400 },
    { NULL, 0, 0 }
};

/* ── Create a grid by ProgID ─────────────────────────────── */

static IDispatch *create_grid(const WCHAR *progid, const char *label) {
    CLSID clsid;
    HRESULT hr = CLSIDFromProgID(progid, &clsid);
    if (FAILED(hr)) {
        printf("  %s: CLSIDFromProgID failed: 0x%08lx (not registered?)\n", label, hr);
        return NULL;
    }
    IDispatch *pGrid = NULL;
    hr = CoCreateInstance(&clsid, NULL, CLSCTX_INPROC_SERVER,
                          &IID_IDispatch, (void **)&pGrid);
    if (FAILED(hr)) {
        printf("  %s: CoCreateInstance failed: 0x%08lx\n", label, hr);
        return NULL;
    }
    return pGrid;
}

/* ── Pixel diff between two BMPs ─────────────────────────── */

/* Load raw 24-bit pixel data from a BMP file.
 * Returns malloc'd buffer, sets *out_w, *out_h.  NULL on failure. */
static BYTE *load_bmp_pixels(const char *filename, int *out_w, int *out_h) {
    FILE *f = fopen(filename, "rb");
    if (!f) return NULL;
    BITMAPFILEHEADER bf;
    BITMAPINFOHEADER bi;
    if (fread(&bf, sizeof(bf), 1, f) != 1 || bf.bfType != 0x4D42) { fclose(f); return NULL; }
    if (fread(&bi, sizeof(bi), 1, f) != 1) { fclose(f); return NULL; }
    if (bi.biBitCount != 24) { fclose(f); return NULL; }
    *out_w = bi.biWidth;
    *out_h = abs(bi.biHeight);
    int stride = ((bi.biWidth * 3 + 3) & ~3);
    int dataSize = stride * (*out_h);
    BYTE *pixels = (BYTE *)malloc(dataSize);
    fseek(f, bf.bfOffBits, SEEK_SET);
    fread(pixels, dataSize, 1, f);
    fclose(f);
    return pixels;
}

/* Compare two BMP files pixel-by-pixel.
 * Returns similarity percentage (0.0 - 100.0).
 * Optionally saves a diff BMP highlighting differences in red. */
static double compare_bmps(const char *file_vs, const char *file_vv,
                            const char *diff_file) {
    int w1, h1, w2, h2;
    BYTE *px1 = load_bmp_pixels(file_vs, &w1, &h1);
    BYTE *px2 = load_bmp_pixels(file_vv, &w2, &h2);
    if (!px1 || !px2) {
        free(px1); free(px2);
        return -1.0;  /* cannot compare */
    }
    int w = (w1 < w2) ? w1 : w2;
    int h = (h1 < h2) ? h1 : h2;
    int stride1 = ((w1 * 3 + 3) & ~3);
    int stride2 = ((w2 * 3 + 3) & ~3);
    int strideD = ((w * 3 + 3) & ~3);

    long long total_pixels = (long long)w * h;
    long long matching = 0;
    long long total_diff = 0;

    /* Diff image: white where matching, red where different */
    BYTE *diff = (BYTE *)malloc(strideD * h);
    memset(diff, 0xFF, strideD * h);

    for (int y = 0; y < h; y++) {
        BYTE *row1 = px1 + y * stride1;
        BYTE *row2 = px2 + y * stride2;
        BYTE *rowD = diff + y * strideD;
        for (int x = 0; x < w; x++) {
            int b1 = row1[x*3+0], g1 = row1[x*3+1], r1 = row1[x*3+2];
            int b2 = row2[x*3+0], g2 = row2[x*3+1], r2 = row2[x*3+2];
            int dr = abs(r1-r2), dg = abs(g1-g2), db = abs(b1-b2);
            int d = dr + dg + db;
            total_diff += d;
            if (d <= 12) {  /* threshold: nearly identical */
                matching++;
                /* Keep original pixel (average) */
                rowD[x*3+0] = (b1+b2)/2;
                rowD[x*3+1] = (g1+g2)/2;
                rowD[x*3+2] = (r1+r2)/2;
            } else {
                /* Highlight diff: red channel = diff intensity, other channels dimmed */
                int intensity = (d * 255) / (3 * 255);
                if (intensity > 255) intensity = 255;
                rowD[x*3+0] = 0;                        /* B */
                rowD[x*3+1] = 0;                        /* G */
                rowD[x*3+2] = 128 + intensity / 2;      /* R */
            }
        }
    }

    /* Save diff BMP if requested */
    if (diff_file) {
        FILE *f = fopen(diff_file, "wb");
        if (f) {
            BITMAPINFOHEADER bi = {0};
            bi.biSize = sizeof(bi);
            bi.biWidth = w;
            bi.biHeight = h;
            bi.biPlanes = 1;
            bi.biBitCount = 24;
            bi.biCompression = BI_RGB;
            bi.biSizeImage = strideD * h;
            BITMAPFILEHEADER bf = {0};
            bf.bfType = 0x4D42;
            bf.bfOffBits = sizeof(bf) + sizeof(bi);
            bf.bfSize = bf.bfOffBits + bi.biSizeImage;
            fwrite(&bf, sizeof(bf), 1, f);
            fwrite(&bi, sizeof(bi), 1, f);
            fwrite(diff, bi.biSizeImage, 1, f);
            fclose(f);
        }
    }

    free(px1); free(px2); free(diff);

    if (total_pixels == 0) return 0.0;
    return (double)matching * 100.0 / (double)total_pixels;
}

static int test_selected(int test_no, int only_test, const char *test_filter) {
    const char *p;

    if (only_test > 0) {
        return test_no == only_test;
    }
    if (!test_filter || !*test_filter) {
        return 1;
    }

    p = test_filter;
    while (*p) {
        int start, end;
        while (*p == ',' || isspace((unsigned char)*p)) p++;
        if (!*p) break;
        if (!isdigit((unsigned char)*p)) {
            while (*p && *p != ',') p++;
            continue;
        }

        start = (int)strtol(p, (char **)&p, 10);
        end = start;
        if (*p == '-') {
            p++;
            if (isdigit((unsigned char)*p)) {
                end = (int)strtol(p, (char **)&p, 10);
            }
        }
        if (end < start) {
            int t = start;
            start = end;
            end = t;
        }
        if (test_no >= start && test_no <= end) {
            return 1;
        }
        while (*p && *p != ',') p++;
    }

    return 0;
}

typedef struct {
    const char *name;
    const WCHAR *script;
} ProbeCase;

static const ProbeCase g_probe_cases[] = {
    { "fresh_hosted", L"" },
    { "single_cell_grid",
      L"fg.Cols = 1\r\n"
      L"fg.Rows = 1\r\n"
      L"fg.FixedRows = 0\r\n"
      L"fg.FixedCols = 0\r\n" },
    { "dims_only_standard",
      L"fg.Cols = 5\r\n"
      L"fg.Rows = 21\r\n"
      L"fg.FixedRows = 1\r\n"
      L"fg.FixedCols = 0\r\n" },
    { "fixed_before_dims",
      L"fg.FixedRows = 1\r\n"
      L"fg.FixedCols = 0\r\n"
      L"fg.Cols = 5\r\n"
      L"fg.Rows = 21\r\n" },
    { "rows_before_cols",
      L"fg.Rows = 21\r\n"
      L"fg.Cols = 5\r\n"
      L"fg.FixedRows = 1\r\n"
      L"fg.FixedCols = 0\r\n" },
    { "font_then_dims_test01",
      L"fg.FontName = \"Arial\"\r\n"
      L"fg.FontSize = 10\r\n"
      L"fg.Cols = 5\r\n"
      L"fg.Rows = 21\r\n"
      L"fg.FixedRows = 1\r\n"
      L"fg.FixedCols = 0\r\n" },
    { "dims_then_font",
      L"fg.Cols = 5\r\n"
      L"fg.Rows = 21\r\n"
      L"fg.FixedRows = 1\r\n"
      L"fg.FixedCols = 0\r\n"
      L"fg.FontName = \"Arial\"\r\n"
      L"fg.FontSize = 10\r\n" },
    { "populate_standard",
      L"Call PopulateStandard()\r\n" },
    { "font_then_populate_standard",
      L"fg.FontName = \"Arial\"\r\n"
      L"fg.FontSize = 10\r\n"
      L"Call PopulateStandard()\r\n" },
    { "populate_then_font",
      L"Call PopulateStandard()\r\n"
      L"fg.FontName = \"Arial\"\r\n"
      L"fg.FontSize = 10\r\n" },
    { "toggle_fixed_rows",
      L"fg.Cols = 5\r\n"
      L"fg.Rows = 21\r\n"
      L"fg.FixedRows = 0\r\n"
      L"fg.FixedCols = 0\r\n"
      L"fg.FixedRows = 1\r\n" },
    { NULL, NULL }
};

static double twips_to_px(int twips) {
    if (twips < 0) return -1.0;
    return (double)twips / 15.0;
}

static unsigned int get_u32_prop(IDispatch *disp, LPCOLESTR name, unsigned int fallback) {
    int value = get_int(disp, name, (int)fallback);
    return (unsigned int)value;
}

static void dump_probe_metrics(IDispatch *disp, const char *label, const char *case_name) {
    int rows = get_int(disp, L"Rows", 0);
    int cols = get_int(disp, L"Cols", 0);
    int fixed_rows = get_int(disp, L"FixedRows", 0);
    int fixed_cols = get_int(disp, L"FixedCols", 0);
    int row = get_int(disp, L"Row", 0);
    int col = get_int(disp, L"Col", 0);
    int row_sel = get_int(disp, L"RowSel", 0);
    int col_sel = get_int(disp, L"ColSel", 0);
    int top_row = get_int(disp, L"TopRow", 0);
    int left_col = get_int(disp, L"LeftCol", 0);
    double font_size = get_double(disp, L"FontSize", -1.0);
    unsigned int back_color = get_u32_prop(disp, L"BackColor", 0);
    unsigned int back_color_fixed = get_u32_prop(disp, L"BackColorFixed", 0);
    unsigned int fore_color_fixed = get_u32_prop(disp, L"ForeColorFixed", 0);
    unsigned int back_color_sel = get_u32_prop(disp, L"BackColorSel", 0);
    unsigned int fore_color_sel = get_u32_prop(disp, L"ForeColorSel", 0);
    char font_name[128];
    long long total_row_twips = 0;
    long long total_col_twips = 0;
    int row_samples = rows < 3 ? rows : 3;
    int col_samples = cols < 3 ? cols : 3;
    int i;

    get_string_utf8(disp, L"FontName", font_name, sizeof(font_name));

    for (i = 0; i < rows; i++) {
        int tw = get_indexed_int(disp, L"RowHeight", i, -1);
        if (tw >= 0) total_row_twips += tw;
    }
    for (i = 0; i < cols; i++) {
        int tw = get_indexed_int(disp, L"ColWidth", i, -1);
        if (tw >= 0) total_col_twips += tw;
    }

    printf("PROBE[%s][%s]\n", label, case_name);
    printf("  state: rows=%d cols=%d fixed_rows=%d fixed_cols=%d row=%d col=%d row_sel=%d col_sel=%d top_row=%d left_col=%d font=\"%s\" size=%.2f\n",
           rows, cols, fixed_rows, fixed_cols, row, col, row_sel, col_sel, top_row, left_col, font_name, font_size);
    printf("  colors: back=%08X fixed_back=%08X fixed_fore=%08X sel_back=%08X sel_fore=%08X\n",
           back_color, back_color_fixed, fore_color_fixed, back_color_sel, fore_color_sel);

    printf("  row_height:");
    if (row_samples <= 0) {
        printf(" <none>");
    } else {
        for (i = 0; i < row_samples; i++) {
            int tw = get_indexed_int(disp, L"RowHeight", i, -1);
            printf(" r%d=%d twips(%.2fpx)", i, tw, twips_to_px(tw));
        }
    }
    printf("\n");

    printf("  col_width:");
    if (col_samples <= 0) {
        printf(" <none>");
    } else {
        for (i = 0; i < col_samples; i++) {
            int tw = get_indexed_int(disp, L"ColWidth", i, -1);
            printf(" c%d=%d twips(%.2fpx)", i, tw, twips_to_px(tw));
        }
    }
    printf("\n");

    printf("  totals: row_sum=%lld twips(%.2fpx) col_sum=%lld twips(%.2fpx)\n",
           total_row_twips, twips_to_px((int)total_row_twips),
           total_col_twips, twips_to_px((int)total_col_twips));
}

static int run_probe_cases_for_control(const WCHAR *progid, const WCHAR *title, const char *label, int x_offset) {
    int i;

    for (i = 0; g_probe_cases[i].name; i++) {
        HostedGrid hg;
        printf("\n[%s] %s\n", label, g_probe_cases[i].name);
        if (hosted_grid_create(&hg, progid, title, 800, 400, x_offset) != 0) {
            printf("  FAILED: could not host control for probe\n");
            return -1;
        }
        if (g_probe_cases[i].script && g_probe_cases[i].script[0]) {
            run_vbs(hg.disp, g_probe_cases[i].script);
        }
        pump_messages_ms(120);
        dump_probe_metrics(hg.disp, label, g_probe_cases[i].name);
        hosted_grid_destroy(&hg);
    }

    return 0;
}

static int run_probe_cases_for_dispatch_only_control(const WCHAR *progid, const char *label) {
    int i;

    for (i = 0; g_probe_cases[i].name; i++) {
        IDispatch *disp;

        printf("\n[%s] %s\n", label, g_probe_cases[i].name);
        disp = create_grid(progid, label);
        if (!disp) {
            printf("  FAILED: could not create control for probe\n");
            return -1;
        }
        if (g_probe_cases[i].script && g_probe_cases[i].script[0]) {
            run_vbs(disp, g_probe_cases[i].script);
        }
        pump_messages_ms(120);
        dump_probe_metrics(disp, label, g_probe_cases[i].name);
        disp->lpVtbl->Release(disp);
    }

    return 0;
}

static int run_default_metric_probe(void) {
    int rc = 0;

    printf("=== Default Metric Probe ===\n");
    printf("Cases: hosted creation, init order changes, font changes, and PopulateStandard()\n");

    if (g_ref_progid[0]) {
        rc |= run_probe_cases_for_control(g_ref_progid, L"Reference Metric Probe", "REF", 0);
    } else {
        printf("\n[REF] skipped (no --ref-progid provided)\n");
    }

    rc |= run_probe_cases_for_dispatch_only_control(PROGID_VOLVOXGRID, "VV");
    return rc;
}

/* ── Main ────────────────────────────────────────────────── */

int main(int argc, char *argv[]) {
    int only_vv = 0;
    int skip_diff = 0;
    int dump_test = 0;
    int only_test = 0;
    int probe_defaults = 0;
    char test_filter[256] = {0};
    /* Keep tests non-interactive/silent on faults in CI/Wine runs. */
    SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX | SEM_NOOPENFILEERRORBOX);
    for (int a = 1; a < argc; a++) {
        if (strcmp(argv[a], "--only-vv") == 0) only_vv = 1;
        else if (strcmp(argv[a], "--no-diff") == 0) skip_diff = 1;
        else if (strcmp(argv[a], "--probe-defaults") == 0) probe_defaults = 1;
        else if (strcmp(argv[a], "--test") == 0 && a + 1 < argc) {
            only_test = atoi(argv[++a]);
        }
        else if (strcmp(argv[a], "--tests") == 0 && a + 1 < argc) {
            snprintf(test_filter, sizeof(test_filter), "%s", argv[++a]);
        }
        else if ((strcmp(argv[a], "--ref-progid") == 0 || strcmp(argv[a], "--legacy-progid") == 0) && a + 1 < argc) {
            a++;
            MultiByteToWideChar(CP_ACP, 0, argv[a], -1, g_ref_progid, 256);
        }
    }
    {
        const char *env_dump = getenv("VFG_DUMP_TEST");
        if (env_dump && *env_dump) {
            dump_test = atoi(env_dump);
        }
    }
    if (!g_ref_progid[0]) only_vv = 1;

    printf("=== FlexGrid vs VolvoxGrid — Feature Comparison Tests ===\n");
    printf("    %d test scenarios\n\n", (int)(sizeof(g_tests)/sizeof(g_tests[0])) - 1);

    HRESULT hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
    if (FAILED(hr)) {
        printf("CoInitializeEx failed: 0x%08lx\n", hr);
        return 1;
    }

    if (probe_defaults) {
        int probe_rc = run_default_metric_probe();
        CoUninitialize();
        return probe_rc ? 1 : 0;
    }

    int pass = 0, fail = 0, compared = 0;
    double total_similarity = 0.0;

    for (int i = 0; g_tests[i].name; i++) {
        if (!test_selected(i + 1, only_test, test_filter)) {
            continue;
        }
        TestCase *tc = &g_tests[i];
        char bmp_lg[128], bmp_vv[128], bmp_diff[128], cell_diff_txt[128];
        snprintf(bmp_lg, sizeof(bmp_lg), "test_%02d_%s_lg.bmp", i+1, tc->name);
        snprintf(bmp_vv, sizeof(bmp_vv), "test_%02d_%s_vv.bmp", i+1, tc->name);
        snprintf(bmp_diff, sizeof(bmp_diff), "test_%02d_%s_diff.bmp", i+1, tc->name);
        snprintf(cell_diff_txt, sizeof(cell_diff_txt), "test_%02d_%s_cells.diff.txt", i+1, tc->name);
        remove(cell_diff_txt);

        printf("[%02d] %s\n", i+1, tc->name);

        /* Load VBS test file */
        char vbs_path[256];
        snprintf(vbs_path, sizeof(vbs_path), "tests/%02d_%s.vbs", i+1, tc->name);
        WCHAR *vbs_code = load_file_wide(vbs_path);
        if (!vbs_code) {
            printf("  SKIP: cannot load %s\n", vbs_path);
            fail++;
            continue;
        }

        int has_lg = 0;
        int has_lg_snapshot = 0;
        int lg_active = 0;
        HostedGrid lg = {0};
        GridSnapshot lg_snapshot = {0};
        GridSnapshot vv_snapshot = {0};

        /* FlexGrid (reference) */
        if (!only_vv) {
            if (hosted_grid_create(&lg, g_ref_progid, L"FlexGrid Host", tc->width, tc->height, 0) == 0) {
                run_vbs(lg.disp, vbs_code);
                pump_messages_ms(120);
                capture_grid_snapshot(lg.disp, &lg_snapshot);
                has_lg_snapshot = 1;
                if (dump_test == (i + 1)) {
                    dump_grid_rows(lg.disp, "LG", i + 1);
                }
                render_to_bmp(lg.disp, bmp_lg, lg.render_width, lg.render_height);
                has_lg = 1;
                lg_active = 1;
            } else {
                printf("  LG: host/create failed\n");
            }
        }

        /* VolvoxGrid */
        IDispatch *pVV = create_grid(PROGID_VOLVOXGRID, "VV");
        if (pVV) {
            HRESULT resize_hr = call_resize_viewport(pVV, tc->width, tc->height);
            if (FAILED(resize_hr)) {
                printf("  VV: ResizeViewport failed: 0x%08lx\n", resize_hr);
            }
            run_vbs(pVV, vbs_code);
            capture_grid_snapshot(pVV, &vv_snapshot);
            if (dump_test == (i + 1)) {
                dump_grid_rows(pVV, "VV", i + 1);
            }
            if (has_lg_snapshot) {
                print_grid_property_diffs(i + 1, tc->name, &lg_snapshot, &vv_snapshot);
                write_grid_cell_diff_file(
                    i + 1,
                    tc->name,
                    &lg_snapshot,
                    &vv_snapshot,
                    lg.disp,
                    pVV,
                    cell_diff_txt);
            }
            render_to_bmp(pVV, bmp_vv, tc->width, tc->height);
            pVV->lpVtbl->Release(pVV);
            pass++;

            /* Pixel diff */
            if (has_lg && !skip_diff) {
                double sim = compare_bmps(bmp_lg, bmp_vv, bmp_diff);
                if (sim >= 0) {
                    printf("  Similarity: %.1f%%  -> %s\n", sim, bmp_diff);
                    total_similarity += sim;
                    compared++;
                }
            }
        } else {
            printf("  VV: FAILED to create\n");
            fail++;
        }

        if (lg_active) {
            hosted_grid_destroy(&lg);
        }

        free_grid_snapshot(&lg_snapshot);
        free_grid_snapshot(&vv_snapshot);

        free(vbs_code);
    }

    CoUninitialize();

    printf("\n");
    printf("══════════════════════════════════════════════════\n");
    printf("  Results: %d rendered, %d failed\n", pass, fail);
    if (compared > 0) {
        printf("  Compared: %d pairs, avg similarity: %.1f%%\n",
               compared, total_similarity / compared);
    }
    printf("══════════════════════════════════════════════════\n");
    return fail > 0 ? 1 : 0;
}
