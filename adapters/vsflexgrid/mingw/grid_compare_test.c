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
#include <ctype.h>
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

static void get_text_matrix_utf8(
    IDispatch *pDisp, int row, int col, char *out, int out_cap)
{
    if (!out || out_cap <= 0) return;
    out[0] = '\0';

    DISPID dispid;
    LPOLESTR name = L"TextMatrix";
    if (FAILED(pDisp->lpVtbl->GetIDsOfNames(pDisp, &IID_NULL, &name, 1, 0, &dispid))) {
        return;
    }

    VARIANT args[2];
    VariantInit(&args[0]); args[0].vt = VT_I4; args[0].lVal = col;
    VariantInit(&args[1]); args[1].vt = VT_I4; args[1].lVal = row;
    DISPPARAMS dp = { args, NULL, 2, 0 };

    VARIANT vr;
    VariantInit(&vr);
    HRESULT hr = pDisp->lpVtbl->Invoke(
        pDisp, dispid, &IID_NULL, 0, DISPATCH_PROPERTYGET, &dp, &vr, NULL, NULL);
    if (FAILED(hr)) return;
    if (vr.vt != VT_BSTR || !vr.bstrVal) {
        VariantClear(&vr);
        return;
    }

    int wlen = SysStringLen(vr.bstrVal);
    int n = WideCharToMultiByte(CP_UTF8, 0, vr.bstrVal, wlen, out, out_cap - 1, NULL, NULL);
    if (n < 0) n = 0;
    if (n >= out_cap) n = out_cap - 1;
    out[n] = '\0';
    VariantClear(&vr);
}

static void dump_grid_rows(IDispatch *pDisp, const char *tag, int test_no) {
    int rows = get_int(pDisp, L"Rows", 0);
    int cols = get_int(pDisp, L"Cols", 0);
    if (cols > 5) cols = 5;
    printf("  DUMP[%s][%02d]: rows=%d cols=%d\n", tag, test_no, rows, cols);
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

/* ════════════════════════════════════════════════════════════ */
/* VBScript engine via IActiveScript                            */
/* ════════════════════════════════════════════════════════════ */

/* Minimal IActiveScriptSite: provides "fg" named item */

typedef struct {
    IActiveScriptSiteVtbl *lpVtbl;
    LONG ref;
    IDispatch *grid;
} ScriptSite;

static HRESULT STDMETHODCALLTYPE ss_qi(IActiveScriptSite *This, REFIID riid, void **ppv) {
    if (IsEqualGUID(riid, &IID_IUnknown) || IsEqualGUID(riid, &IID_IActiveScriptSite)) {
        *ppv = This;
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
    L"    fg.FontName = \"Arial\"\r\n"
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

/* ── Main ────────────────────────────────────────────────── */

int main(int argc, char *argv[]) {
    int only_vv = 0;
    int skip_diff = 0;
    int dump_test = 0;
    int only_test = 0;
    char test_filter[256] = {0};
    /* Keep tests non-interactive/silent on faults in CI/Wine runs. */
    SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX | SEM_NOOPENFILEERRORBOX);
    for (int a = 1; a < argc; a++) {
        if (strcmp(argv[a], "--only-vv") == 0) only_vv = 1;
        else if (strcmp(argv[a], "--no-diff") == 0) skip_diff = 1;
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

    int pass = 0, fail = 0, compared = 0;
    double total_similarity = 0.0;

    for (int i = 0; g_tests[i].name; i++) {
        if (!test_selected(i + 1, only_test, test_filter)) {
            continue;
        }
        TestCase *tc = &g_tests[i];
        char bmp_lg[128], bmp_vv[128], bmp_diff[128];
        snprintf(bmp_lg, sizeof(bmp_lg), "test_%02d_%s_lg.bmp", i+1, tc->name);
        snprintf(bmp_vv, sizeof(bmp_vv), "test_%02d_%s_vv.bmp", i+1, tc->name);
        snprintf(bmp_diff, sizeof(bmp_diff), "test_%02d_%s_diff.bmp", i+1, tc->name);

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

        /* FlexGrid (reference) */
        if (!only_vv) {
            IDispatch *pLG = create_grid(g_ref_progid, "LG");
            if (pLG) {
                run_vbs(pLG, vbs_code);
                if (dump_test == (i + 1)) {
                    dump_grid_rows(pLG, "LG", i + 1);
                }
                render_to_bmp(pLG, bmp_lg, tc->width, tc->height);
                pLG->lpVtbl->Release(pLG);
                has_lg = 1;
            } else {
                printf("  LG: skipped (not registered)\n");
            }
        }

        /* VolvoxGrid */
        IDispatch *pVV = create_grid(PROGID_VOLVOXGRID, "VV");
        if (pVV) {
            run_vbs(pVV, vbs_code);
            if (dump_test == (i + 1)) {
                dump_grid_rows(pVV, "VV", i + 1);
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
