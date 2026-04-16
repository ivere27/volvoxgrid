/* grid_compare_ux_test.c — Side-by-side comparison with real UI/UX interaction
 *
 * Unlike grid_compare_test.c (offscreen IViewObject::Draw), this harness hosts
 * each control in a real in-place ActiveX window, pumps messages, replays
 * optional UI actions, and captures hosted controls from the live screen
 * region. Dispatch-only controls fall back to IViewObject::Draw.
 *
 * Build with MinGW:
 *   i686-w64-mingw32-gcc -O2 -o grid_compare_ux_test.exe grid_compare_ux_test.c \
 *       -lole32 -loleaut32 -luuid -lgdi32 -static-libgcc
 *
 * Optional per-test UX action file:
 *   tests/NN_name.ux
 *
 * Optional filters:
 *   --test N            run only one test number
 *   --tests LIST        run only selected tests (e.g. 1,3,7-9)
 *
 * Supported action commands (one per line):
 *   set_cell <row> <col>
 *   click_cell <row> <col>
 *   drag_cell <from_row> <from_col> <to_row> <to_col>
 *   drag_cell_edge <from_row> <from_col> <edge> <to_row> <to_col>
 *   click_combo <row> <col>
 *   key <VK_NAME|number>   (F2,F4,SPACE,ENTER,ESC,UP,DOWN,LEFT,RIGHT,TAB)
 *   sleep <ms>
 *   dblclick_cell <row> <col>
 */

#define COBJMACROS
#define CINTERFACE
#include <windows.h>
#include <ole2.h>
#include <oleauto.h>
#include <olectl.h>
#include <activscp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

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

/* ── IDispatch helpers ───────────────────────────────────── */

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
    {
        int out = tmp.lVal;
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
    {
        HRESULT hr = pDisp->lpVtbl->Invoke(
            pDisp, dispid, &IID_NULL, 0, DISPATCH_PROPERTYGET, &dp, &vr, NULL, NULL);
        if (FAILED(hr)) return fallback;
    }
    {
        VARIANT tmp;
        HRESULT hr;
        int out;
        VariantInit(&tmp);
        hr = VariantChangeType(&tmp, &vr, 0, VT_I4);
        VariantClear(&vr);
        if (FAILED(hr)) {
            VariantClear(&tmp);
            return fallback;
        }
        out = tmp.lVal;
        VariantClear(&tmp);
        return out;
    }
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

static char *get_text_matrix_utf8_alloc(IDispatch *pDisp, int row, int col) {
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

    if (!pDisp) return NULL;
    if (FAILED(pDisp->lpVtbl->GetIDsOfNames(pDisp, &IID_NULL, &name, 1, 0, &dispid))) {
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
        VariantClear(&vr);
        return NULL;
    }

    VariantInit(&tmp);
    hr = VariantChangeType(&tmp, &vr, 0, VT_BSTR);
    VariantClear(&vr);
    if (FAILED(hr)) {
        VariantClear(&tmp);
        return NULL;
    }

    if (!tmp.bstrVal) {
        VariantClear(&tmp);
        return dup_utf8_string("");
    }

    wlen = SysStringLen(tmp.bstrVal);
    if (wlen <= 0) {
        VariantClear(&tmp);
        return dup_utf8_string("");
    }

    n = WideCharToMultiByte(CP_UTF8, 0, tmp.bstrVal, wlen, NULL, 0, NULL, NULL);
    if (n <= 0) {
        VariantClear(&tmp);
        return NULL;
    }

    out = (char *)malloc((size_t)n + 1);
    if (!out) {
        VariantClear(&tmp);
        return NULL;
    }

    if (WideCharToMultiByte(CP_UTF8, 0, tmp.bstrVal, wlen, out, n, NULL, NULL) <= 0) {
        VariantClear(&tmp);
        free(out);
        return NULL;
    }

    out[n] = '\0';
    VariantClear(&tmp);
    return out;
}

static char *get_bstr_prop_utf8_alloc(IDispatch *pDisp, LPCOLESTR name) {
    DISPID dispid;
    DISPPARAMS dp;
    VARIANT vr;
    VARIANT tmp;
    HRESULT hr;
    int wlen;
    int n;
    char *out;

    if (!pDisp || !name) return NULL;
    if (FAILED(pDisp->lpVtbl->GetIDsOfNames(pDisp, &IID_NULL, (LPOLESTR *)&name, 1, 0, &dispid))) {
        return NULL;
    }

    memset(&dp, 0, sizeof(dp));
    VariantInit(&vr);
    hr = pDisp->lpVtbl->Invoke(
        pDisp, dispid, &IID_NULL, 0, DISPATCH_PROPERTYGET, &dp, &vr, NULL, NULL);
    if (FAILED(hr)) return NULL;

    VariantInit(&tmp);
    hr = VariantChangeType(&tmp, &vr, 0, VT_BSTR);
    VariantClear(&vr);
    if (FAILED(hr) || !tmp.bstrVal) {
        VariantClear(&tmp);
        return NULL;
    }

    wlen = SysStringLen(tmp.bstrVal);
    n = WideCharToMultiByte(CP_UTF8, 0, tmp.bstrVal, wlen, NULL, 0, NULL, NULL);
    out = (char *)malloc((size_t)n + 1);
    if (!out) {
        VariantClear(&tmp);
        return NULL;
    }
    WideCharToMultiByte(CP_UTF8, 0, tmp.bstrVal, wlen, out, n, NULL, NULL);
    out[n] = '\0';
    VariantClear(&tmp);
    return out;
}

static void dump_top_row_snapshot(IDispatch *pDisp, const char *tag, int test_no) {
    int cols;
    int limit;
    int c;

    if (!pDisp) return;
    cols = get_int(pDisp, L"Cols", 0);
    if (cols <= 0) return;
    limit = cols;
    if (limit > 6) limit = 6;

    printf("  Snapshot[%s][%02d]:", tag, test_no);
    for (c = 0; c < limit; ++c) {
        char *text = get_text_matrix_utf8_alloc(pDisp, 0, c);
        printf(" %s%s", c == 0 ? "" : " |", text ? text : "");
        free(text);
    }
    printf("\n");
}

static HRESULT put_int(IDispatch *pDisp, LPCOLESTR name, int val) {
    DISPID dispid;
    if (FAILED(get_dispid(pDisp, name, &dispid))) return DISP_E_MEMBERNOTFOUND;

    VARIANT v;
    DISPID putid = DISPID_PROPERTYPUT;
    DISPPARAMS dp;
    VariantInit(&v);
    v.vt = VT_I4;
    v.lVal = val;

    dp.rgvarg = &v;
    dp.rgdispidNamedArgs = &putid;
    dp.cArgs = 1;
    dp.cNamedArgs = 1;

    return pDisp->lpVtbl->Invoke(
        pDisp, dispid, &IID_NULL, 0, DISPATCH_PROPERTYPUT, &dp, NULL, NULL, NULL);
}

static void utf8_to_wchar_buf(const char *src, WCHAR *dst, int dst_cap) {
    if (!dst || dst_cap <= 0) return;
    if (!src) {
        dst[0] = L'\0';
        return;
    }
    if (MultiByteToWideChar(CP_UTF8, 0, src, -1, dst, dst_cap) <= 0) {
        dst[0] = L'\0';
    }
}

static HRESULT put_int_named_utf8(IDispatch *pDisp, const char *name_utf8, int val) {
    WCHAR wname[96];
    utf8_to_wchar_buf(name_utf8, wname, (int)(sizeof(wname) / sizeof(wname[0])));
    if (!wname[0]) return E_INVALIDARG;
    return put_int(pDisp, wname, val);
}

static HRESULT put_indexed_int_named_utf8(IDispatch *pDisp, const char *name_utf8, int index, int val) {
    WCHAR wname[96];
    DISPID dispid;
    VARIANT args[2];
    DISPID putid = DISPID_PROPERTYPUT;
    DISPPARAMS dp;

    utf8_to_wchar_buf(name_utf8, wname, (int)(sizeof(wname) / sizeof(wname[0])));
    if (!wname[0]) return E_INVALIDARG;
    if (FAILED(get_dispid(pDisp, wname, &dispid))) return DISP_E_MEMBERNOTFOUND;

    VariantInit(&args[0]);
    VariantInit(&args[1]);
    args[1].vt = VT_I4; args[1].lVal = index;
    args[0].vt = VT_I4; args[0].lVal = val;

    dp.rgvarg = args;
    dp.rgdispidNamedArgs = &putid;
    dp.cArgs = 2;
    dp.cNamedArgs = 1;
    return pDisp->lpVtbl->Invoke(
        pDisp, dispid, &IID_NULL, 0, DISPATCH_PROPERTYPUT, &dp, NULL, NULL, NULL);
}

static HRESULT call_method0_named_utf8(IDispatch *pDisp, const char *name_utf8) {
    WCHAR wname[96];
    DISPID dispid;
    DISPPARAMS dp;

    utf8_to_wchar_buf(name_utf8, wname, (int)(sizeof(wname) / sizeof(wname[0])));
    if (!wname[0]) return E_INVALIDARG;
    if (FAILED(get_dispid(pDisp, wname, &dispid))) return DISP_E_MEMBERNOTFOUND;

    memset(&dp, 0, sizeof(dp));
    return pDisp->lpVtbl->Invoke(
        pDisp, dispid, &IID_NULL, 0, DISPATCH_METHOD, &dp, NULL, NULL, NULL);
}

static HRESULT call_method2_i4(IDispatch *pDisp, LPCOLESTR name, int arg0, int arg1) {
    DISPID dispid;
    VARIANT args[2];
    DISPPARAMS dp;

    if (FAILED(get_dispid(pDisp, name, &dispid))) return DISP_E_MEMBERNOTFOUND;

    VariantInit(&args[0]);
    VariantInit(&args[1]);
    /* IDispatch args are reversed: [1]=first arg, [0]=second arg */
    args[1].vt = VT_I4; args[1].lVal = arg0;
    args[0].vt = VT_I4; args[0].lVal = arg1;

    dp.rgvarg = args;
    dp.rgdispidNamedArgs = NULL;
    dp.cArgs = 2;
    dp.cNamedArgs = 0;

    return pDisp->lpVtbl->Invoke(
        pDisp, dispid, &IID_NULL, 0, DISPATCH_METHOD, &dp, NULL, NULL, NULL);
}

static HRESULT call_method2_r4_named_utf8(
    IDispatch *pDisp, const char *name_utf8, float arg0, float arg1)
{
    WCHAR wname[96];
    DISPID dispid;
    VARIANT args[2];
    DISPPARAMS dp;

    utf8_to_wchar_buf(name_utf8, wname, (int)(sizeof(wname) / sizeof(wname[0])));
    if (!wname[0]) return E_INVALIDARG;
    if (FAILED(get_dispid(pDisp, wname, &dispid))) return DISP_E_MEMBERNOTFOUND;

    VariantInit(&args[0]);
    VariantInit(&args[1]);
    args[1].vt = VT_R4; args[1].fltVal = arg0;
    args[0].vt = VT_R4; args[0].fltVal = arg1;

    dp.rgvarg = args;
    dp.rgdispidNamedArgs = NULL;
    dp.cArgs = 2;
    dp.cNamedArgs = 0;

    return pDisp->lpVtbl->Invoke(
        pDisp, dispid, &IID_NULL, 0, DISPATCH_METHOD, &dp, NULL, NULL, NULL);
}

static HRESULT call_method4_r4_r4_i4_i4_named_utf8(
    IDispatch *pDisp, const char *name_utf8, float arg0, float arg1, int arg2, int arg3)
{
    WCHAR wname[96];
    DISPID dispid;
    VARIANT args[4];
    DISPPARAMS dp;

    utf8_to_wchar_buf(name_utf8, wname, (int)(sizeof(wname) / sizeof(wname[0])));
    if (!wname[0]) return E_INVALIDARG;
    if (FAILED(get_dispid(pDisp, wname, &dispid))) return DISP_E_MEMBERNOTFOUND;

    VariantInit(&args[0]);
    VariantInit(&args[1]);
    VariantInit(&args[2]);
    VariantInit(&args[3]);
    args[3].vt = VT_R4; args[3].fltVal = arg0;
    args[2].vt = VT_R4; args[2].fltVal = arg1;
    args[1].vt = VT_I4; args[1].lVal = arg2;
    args[0].vt = VT_I4; args[0].lVal = arg3;

    dp.rgvarg = args;
    dp.rgdispidNamedArgs = NULL;
    dp.cArgs = 4;
    dp.cNamedArgs = 0;

    return pDisp->lpVtbl->Invoke(
        pDisp, dispid, &IID_NULL, 0, DISPATCH_METHOD, &dp, NULL, NULL, NULL);
}

/* ── Utilities ───────────────────────────────────────────── */

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

static int file_exists(const char *path) {
    FILE *f = fopen(path, "rb");
    if (!f) return 0;
    fclose(f);
    return 1;
}

static void rstrip_inplace(char *s) {
    size_t n = strlen(s);
    while (n > 0) {
        char ch = s[n - 1];
        if (ch == '\r' || ch == '\n' || ch == ' ' || ch == '\t') {
            s[n - 1] = '\0';
            n--;
        } else {
            break;
        }
    }
}

static char *lstrip_ptr(char *s) {
    while (*s == ' ' || *s == '\t') s++;
    return s;
}

static int units_to_px(int value, int dpi, int fallback_px) {
    if (value <= 0) return fallback_px;
    /* Heuristic: ActiveX widths/heights are often in twips when > 96. */
    if (value > 96) {
        int px = MulDiv(value, dpi, 1440);
        if (px <= 0) px = fallback_px;
        return px;
    }
    return value;
}

/* ── BMP writer / screen capture ─────────────────────────── */

static void save_bmp(HDC hdcMem, HBITMAP hbm, int w, int h, const char *filename) {
    int stride = ((w * 3 + 3) & ~3);
    int dataSize = stride * h;
    BITMAPINFOHEADER bi = {0};
    BITMAPFILEHEADER bf = {0};
    BYTE *pixels;
    FILE *f;

    bi.biSize = sizeof(bi);
    bi.biWidth = w;
    bi.biHeight = h;
    bi.biPlanes = 1;
    bi.biBitCount = 24;
    bi.biCompression = BI_RGB;
    bi.biSizeImage = dataSize;

    pixels = (BYTE *)malloc(dataSize);
    if (!pixels) return;
    GetDIBits(hdcMem, hbm, 0, h, pixels, (BITMAPINFO *)&bi, DIB_RGB_COLORS);

    bf.bfType = 0x4D42;
    bf.bfOffBits = sizeof(bf) + sizeof(bi);
    bf.bfSize = bf.bfOffBits + dataSize;

    f = fopen(filename, "wb");
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
    HDC hdcScreen, hdcMem;
    HBITMAP hbm;
    HGDIOBJ hOld;
    RECT rc;
    HBRUSH hBrush;
    RECTL rcl;

    if (FAILED(hr) || !pView) {
        printf("  QueryInterface(IViewObject) failed: 0x%08lx\n", hr);
        return -1;
    }

    hdcScreen = GetDC(NULL);
    hdcMem = CreateCompatibleDC(hdcScreen);
    hbm = CreateCompatibleBitmap(hdcScreen, w, h);
    hOld = SelectObject(hdcMem, hbm);

    rc.left = 0; rc.top = 0; rc.right = w; rc.bottom = h;
    hBrush = CreateSolidBrush(RGB(255, 255, 255));
    FillRect(hdcMem, &rc, hBrush);
    DeleteObject(hBrush);

    rcl.left = 0; rcl.top = 0; rcl.right = w; rcl.bottom = h;
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
/* OLE host: minimal in-place ActiveX container                 */
/* ════════════════════════════════════════════════════════════ */

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

/* IOleClientSite */
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

/* IOleInPlaceSite */
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

/* IOleInPlaceFrame */
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

/* ── Host window ─────────────────────────────────────────── */

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
    HWND hwnd_ctrl;
    HostSite *site;
    IOleObject *ole_obj;
    IOleInPlaceObject *inplace_obj;
    IDispatch *disp;
    int dispatch_only;   /* 1 if control lacks IOleObject (e.g. VolvoxGrid) */
    int render_width;    /* save for IViewObject fallback capture */
    int render_height;
    struct EventProbe *event_probe;
} HostedGrid;

typedef enum {
    EVT_BEFORE_EDIT = 0,
    EVT_START_EDIT,
    EVT_AFTER_EDIT,
    EVT_BEFORE_ROW_COL_CHANGE,
    EVT_AFTER_ROW_COL_CHANGE,
    EVT_BEFORE_SEL_CHANGE,
    EVT_AFTER_SEL_CHANGE,
    EVT_BEFORE_SORT,
    EVT_AFTER_SORT,
    EVT_BEFORE_COLLAPSE,
    EVT_AFTER_COLLAPSE,
    EVT_BEFORE_SCROLL,
    EVT_AFTER_SCROLL,
    EVT_BEFORE_SCROLL_TIP,
    EVT_BEFORE_USER_RESIZE,
    EVT_AFTER_USER_RESIZE,
    EVT_AFTER_USER_FREEZE,
    EVT_BEFORE_MOVE_COLUMN,
    EVT_AFTER_MOVE_COLUMN,
    EVT_BEFORE_MOVE_ROW,
    EVT_AFTER_MOVE_ROW,
    EVT_BEFORE_MOUSE_DOWN,
    EVT_BEFORE_DATA_REFRESH,
    EVT_AFTER_DATA_REFRESH,
    EVT_BEFORE_PAGE_BREAK,
    EVT_CLICK,
    EVT_DBLCLICK,
    EVT_CELL_BUTTON_CLICK,
    EVT_COUNT
} EventId;

typedef enum {
    PROBE_MUTATION_NONE = 0,
    PROBE_MUTATION_BOOL,
    PROBE_MUTATION_I2,
    PROBE_MUTATION_I4
} ProbeMutationKind;

typedef struct {
    const WCHAR *name;
    DISPID dispid;
    DISPID script_dispid;
    int count;
    int mutate_on_count;
    ProbeMutationKind mutate_kind;
    LONG mutate_value;
} EventSlot;

typedef struct EventProbe {
    IDispatchVtbl *lpVtbl;
    LONG ref;
    IConnectionPoint *cp;
    ITypeInfo *typeinfo;
    IDispatch *script_dispatch;
    DWORD cookie;
    EventSlot slots[EVT_COUNT];
} EventProbe;

static const WCHAR *g_event_slot_names[EVT_COUNT] = {
    L"BeforeEdit",
    L"StartEdit",
    L"AfterEdit",
    L"BeforeRowColChange",
    L"AfterRowColChange",
    L"BeforeSelChange",
    L"AfterSelChange",
    L"BeforeSort",
    L"AfterSort",
    L"BeforeCollapse",
    L"AfterCollapse",
    L"BeforeScroll",
    L"AfterScroll",
    L"BeforeScrollTip",
    L"BeforeUserResize",
    L"AfterUserResize",
    L"AfterUserFreeze",
    L"BeforeMoveColumn",
    L"AfterMoveColumn",
    L"BeforeMoveRow",
    L"AfterMoveRow",
    L"BeforeMouseDown",
    L"BeforeDataRefresh",
    L"AfterDataRefresh",
    L"BeforePageBreak",
    L"Click",
    L"DblClick",
    L"CellButtonClick"
};

static void event_probe_init_slots(EventProbe *probe) {
    int i;
    if (!probe) return;
    for (i = 0; i < EVT_COUNT; ++i) {
        probe->slots[i].name = g_event_slot_names[i];
        probe->slots[i].dispid = DISPID_UNKNOWN;
        probe->slots[i].script_dispid = DISPID_UNKNOWN;
        probe->slots[i].count = 0;
        probe->slots[i].mutate_on_count = 0;
        probe->slots[i].mutate_kind = PROBE_MUTATION_NONE;
        probe->slots[i].mutate_value = 0;
    }
}

static EventSlot *event_probe_slot_by_dispid(EventProbe *probe, DISPID dispid) {
    int i;
    if (!probe) return NULL;
    for (i = 0; i < EVT_COUNT; ++i) {
        if (probe->slots[i].dispid == dispid) return &probe->slots[i];
    }
    return NULL;
}

static void event_probe_reset(EventProbe *probe) {
    int i;
    if (!probe) return;
    for (i = 0; i < EVT_COUNT; ++i) {
        probe->slots[i].count = 0;
        probe->slots[i].mutate_on_count = 0;
        probe->slots[i].mutate_kind = PROBE_MUTATION_NONE;
        probe->slots[i].mutate_value = 0;
    }
}

static int event_probe_count(const EventProbe *probe, EventId id) {
    if (!probe || id < 0 || id >= EVT_COUNT) return 0;
    return probe->slots[id].count;
}

static int event_probe_has_event(const EventProbe *probe, EventId id) {
    if (!probe || id < 0 || id >= EVT_COUNT) return 0;
    return probe->slots[id].dispid != DISPID_UNKNOWN;
}

static void event_probe_apply_mutation(EventSlot *slot, DISPPARAMS *pDispParams) {
    VARIANT *arg;
    if (!slot || !pDispParams || pDispParams->cArgs < 1) return;
    if (slot->mutate_on_count <= 0 || slot->count != slot->mutate_on_count) return;
    arg = &pDispParams->rgvarg[0];
    switch (slot->mutate_kind) {
    case PROBE_MUTATION_BOOL:
        if (arg->vt == (VT_BYREF | VT_BOOL) && arg->pboolVal) {
            *arg->pboolVal = (VARIANT_BOOL)slot->mutate_value;
        }
        break;
    case PROBE_MUTATION_I2:
        if (arg->vt == (VT_BYREF | VT_I2) && arg->piVal) {
            *arg->piVal = (short)slot->mutate_value;
        }
        break;
    case PROBE_MUTATION_I4:
        if (arg->vt == (VT_BYREF | VT_I4) && arg->plVal) {
            *arg->plVal = slot->mutate_value;
        }
        break;
    default:
        break;
    }
}

static void event_probe_bind_script_dispatch(
    EventProbe *probe, IDispatch *script_dispatch, const WCHAR *prefix)
{
    int i;

    if (!probe) return;

    if (probe->script_dispatch) {
        probe->script_dispatch->lpVtbl->Release(probe->script_dispatch);
        probe->script_dispatch = NULL;
    }
    for (i = 0; i < EVT_COUNT; ++i) {
        probe->slots[i].script_dispid = DISPID_UNKNOWN;
    }

    if (!script_dispatch || !prefix || !*prefix) return;

    probe->script_dispatch = script_dispatch;
    probe->script_dispatch->lpVtbl->AddRef(probe->script_dispatch);

    for (i = 0; i < EVT_COUNT; ++i) {
        WCHAR handler[96];
        LPOLESTR names[1];
        HRESULT hr;

        handler[0] = L'\0';
        lstrcpynW(handler, prefix, (int)(sizeof(handler) / sizeof(handler[0])));
        lstrcpynW(
            handler + lstrlenW(handler),
            probe->slots[i].name,
            (int)(sizeof(handler) / sizeof(handler[0])) - lstrlenW(handler));
        names[0] = handler;
        hr = probe->script_dispatch->lpVtbl->GetIDsOfNames(
            probe->script_dispatch, &IID_NULL, names, 1, LOCALE_USER_DEFAULT,
            &probe->slots[i].script_dispid);
        if (FAILED(hr)) {
            probe->slots[i].script_dispid = DISPID_UNKNOWN;
        }
    }
}

static void event_probe_invoke_script_handler(
    EventProbe *probe, EventSlot *slot, DISPPARAMS *pDispParams)
{
    DISPPARAMS dp_local;
    VARIANT args_copy[8];
    VARIANT scratch[8];
    int wrapped[8];
    UINT i;
    EXCEPINFO ei;
    UINT arg_err = 0;
    HRESULT hr;

    if (!probe || !slot || !probe->script_dispatch) return;
    if (slot->script_dispid == DISPID_UNKNOWN) return;
    if (!pDispParams || pDispParams->cArgs > 8) return;

    memset(wrapped, 0, sizeof(wrapped));
    memset(&dp_local, 0, sizeof(dp_local));
    for (i = 0; i < pDispParams->cArgs; ++i) {
        VARIANT *src = &pDispParams->rgvarg[i];
        VariantInit(&args_copy[i]);
        VariantInit(&scratch[i]);
        switch (src->vt) {
        case VT_BYREF | VT_BOOL:
            if (src->pboolVal) {
                scratch[i].vt = VT_BOOL;
                scratch[i].boolVal = *src->pboolVal;
                args_copy[i].vt = VT_BYREF | VT_VARIANT;
                args_copy[i].pvarVal = &scratch[i];
                wrapped[i] = 1;
            }
            break;
        case VT_BYREF | VT_I2:
            if (src->piVal) {
                scratch[i].vt = VT_I2;
                scratch[i].iVal = *src->piVal;
                args_copy[i].vt = VT_BYREF | VT_VARIANT;
                args_copy[i].pvarVal = &scratch[i];
                wrapped[i] = 1;
            }
            break;
        case VT_BYREF | VT_I4:
            if (src->plVal) {
                scratch[i].vt = VT_I4;
                scratch[i].lVal = *src->plVal;
                args_copy[i].vt = VT_BYREF | VT_VARIANT;
                args_copy[i].pvarVal = &scratch[i];
                wrapped[i] = 1;
            }
            break;
        default:
            VariantCopy(&args_copy[i], src);
            break;
        }
    }

    dp_local = *pDispParams;
    dp_local.rgvarg = args_copy;

    memset(&ei, 0, sizeof(ei));
    hr = probe->script_dispatch->lpVtbl->Invoke(
        probe->script_dispatch,
        slot->script_dispid,
        &IID_NULL,
        LOCALE_USER_DEFAULT,
        DISPATCH_METHOD,
        &dp_local,
        NULL,
        &ei,
        &arg_err);
    for (i = 0; i < pDispParams->cArgs; ++i) {
        VARIANT *src = &pDispParams->rgvarg[i];
        if (wrapped[i]) {
            VARIANT converted;
            VariantInit(&converted);
            if (src->vt == (VT_BYREF | VT_BOOL) && src->pboolVal &&
                SUCCEEDED(VariantChangeType(&converted, &scratch[i], 0, VT_BOOL))) {
                *src->pboolVal = converted.boolVal;
            } else if (src->vt == (VT_BYREF | VT_I2) && src->piVal &&
                SUCCEEDED(VariantChangeType(&converted, &scratch[i], 0, VT_I2))) {
                *src->piVal = converted.iVal;
            } else if (src->vt == (VT_BYREF | VT_I4) && src->plVal &&
                SUCCEEDED(VariantChangeType(&converted, &scratch[i], 0, VT_I4))) {
                *src->plVal = converted.lVal;
            }
            VariantClear(&converted);
        }
        VariantClear(&args_copy[i]);
        VariantClear(&scratch[i]);
    }
    if (FAILED(hr) && ei.bstrDescription) {
        printf("  Script handler %ls failed: %ls\n", slot->name, ei.bstrDescription);
    }
    SysFreeString(ei.bstrSource);
    SysFreeString(ei.bstrDescription);
    SysFreeString(ei.bstrHelpFile);
}

static HRESULT STDMETHODCALLTYPE eps_qi(IDispatch *This, REFIID riid, void **ppv) {
    if (IsEqualGUID(riid, &IID_IUnknown) || IsEqualGUID(riid, &IID_IDispatch)) {
        *ppv = This;
        This->lpVtbl->AddRef(This);
        return S_OK;
    }
    *ppv = NULL;
    return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE eps_addref(IDispatch *This) {
    return InterlockedIncrement(&((EventProbe *)This)->ref);
}

static ULONG STDMETHODCALLTYPE eps_release(IDispatch *This) {
    return InterlockedDecrement(&((EventProbe *)This)->ref);
}

static HRESULT STDMETHODCALLTYPE eps_get_type_info_count(IDispatch *This, UINT *pctinfo) {
    (void)This;
    if (pctinfo) *pctinfo = 0;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE eps_get_type_info(IDispatch *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo) {
    (void)This;
    (void)iTInfo;
    (void)lcid;
    if (ppTInfo) *ppTInfo = NULL;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE eps_get_ids_of_names(
    IDispatch *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId)
{
    (void)This;
    (void)riid;
    (void)rgszNames;
    (void)cNames;
    (void)lcid;
    (void)rgDispId;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE eps_invoke(
    IDispatch *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags,
    DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr)
{
    EventProbe *probe = (EventProbe *)This;
    EventSlot *slot = event_probe_slot_by_dispid(probe, dispIdMember);
    (void)riid;
    (void)lcid;
    (void)wFlags;
    if (pVarResult) VariantInit(pVarResult);
    if (pExcepInfo) memset(pExcepInfo, 0, sizeof(*pExcepInfo));
    if (puArgErr) *puArgErr = 0;

    if (slot) {
        slot->count++;
        event_probe_apply_mutation(slot, pDispParams);
        event_probe_invoke_script_handler(probe, slot, pDispParams);
    }
    return S_OK;
}

static IDispatchVtbl g_event_probe_vtbl = {
    eps_qi,
    eps_addref,
    eps_release,
    eps_get_type_info_count,
    eps_get_type_info,
    eps_get_ids_of_names,
    eps_invoke
};

static void event_probe_lookup_dispid(EventProbe *probe, LPCOLESTR name, DISPID *pDispid) {
    HRESULT hr;
    LPOLESTR names[1];
    if (!pDispid) return;
    *pDispid = DISPID_UNKNOWN;
    if (!probe || !probe->typeinfo || !name) return;
    names[0] = (LPOLESTR)name;
    hr = probe->typeinfo->lpVtbl->GetIDsOfNames(probe->typeinfo, names, 1, pDispid);
    if (FAILED(hr)) *pDispid = DISPID_UNKNOWN;
}

static EventProbe *event_probe_attach(IDispatch *disp) {
    IProvideClassInfo2 *pci2 = NULL;
    IProvideClassInfo *pci = NULL;
    ITypeInfo *class_info = NULL;
    ITypeLib *type_lib = NULL;
    IConnectionPointContainer *cpc = NULL;
    IEnumConnectionPoints *enum_cp = NULL;
    IConnectionPoint *cp = NULL;
    EventProbe *probe = NULL;
    GUID source_guid;
    UINT type_index = 0;
    ULONG fetched = 0;
    HRESULT hr;

    if (!disp) return NULL;

    memset(&source_guid, 0, sizeof(source_guid));
    hr = disp->lpVtbl->QueryInterface(disp, &IID_IConnectionPointContainer, (void **)&cpc);
    if (FAILED(hr) || !cpc) goto done;

    hr = disp->lpVtbl->QueryInterface(disp, &IID_IProvideClassInfo2, (void **)&pci2);
    if (SUCCEEDED(hr) && pci2) {
        hr = pci2->lpVtbl->GetGUID(pci2, GUIDKIND_DEFAULT_SOURCE_DISP_IID, &source_guid);
    }

    if (FAILED(hr) || IsEqualGUID(&source_guid, &GUID_NULL)) {
        hr = cpc->lpVtbl->EnumConnectionPoints(cpc, &enum_cp);
        if (SUCCEEDED(hr) && enum_cp) {
            hr = enum_cp->lpVtbl->Next(enum_cp, 1, &cp, &fetched);
            if (hr == S_OK && cp && fetched == 1) {
                hr = cp->lpVtbl->GetConnectionInterface(cp, &source_guid);
            }
        }
    }
    if (FAILED(hr) || IsEqualGUID(&source_guid, &GUID_NULL)) goto done;

    if (pci2) {
        hr = pci2->lpVtbl->QueryInterface(pci2, &IID_IProvideClassInfo, (void **)&pci);
    } else {
        hr = disp->lpVtbl->QueryInterface(disp, &IID_IProvideClassInfo, (void **)&pci);
    }
    if (SUCCEEDED(hr) && pci) {
        hr = pci->lpVtbl->GetClassInfo(pci, &class_info);
        if (SUCCEEDED(hr) && class_info) {
            hr = class_info->lpVtbl->GetContainingTypeLib(class_info, &type_lib, &type_index);
        }
    }

    probe = (EventProbe *)calloc(1, sizeof(*probe));
    if (!probe) goto done;
    probe->lpVtbl = &g_event_probe_vtbl;
    probe->ref = 1;
    event_probe_init_slots(probe);
    if (type_lib) {
        hr = type_lib->lpVtbl->GetTypeInfoOfGuid(type_lib, &source_guid, &probe->typeinfo);
        if (FAILED(hr)) probe->typeinfo = NULL;
    }

    {
        int i;
        for (i = 0; i < EVT_COUNT; ++i) {
            event_probe_lookup_dispid(probe, probe->slots[i].name, &probe->slots[i].dispid);
        }
    }

    if (!cp) {
        hr = cpc->lpVtbl->FindConnectionPoint(cpc, &source_guid, &cp);
        if (FAILED(hr) || !cp) goto done;
    }
    hr = cp->lpVtbl->Advise(cp, (IUnknown *)probe, &probe->cookie);
    if (FAILED(hr)) goto done;
    probe->cp = cp;
    cp = NULL;

done:
    if (cp) cp->lpVtbl->Release(cp);
    if (enum_cp) enum_cp->lpVtbl->Release(enum_cp);
    if (cpc) cpc->lpVtbl->Release(cpc);
    if (type_lib) type_lib->lpVtbl->Release(type_lib);
    if (class_info) class_info->lpVtbl->Release(class_info);
    if (pci) pci->lpVtbl->Release(pci);
    if (pci2) pci2->lpVtbl->Release(pci2);
    if (probe && !probe->cp) {
        if (probe->typeinfo) probe->typeinfo->lpVtbl->Release(probe->typeinfo);
        free(probe);
        probe = NULL;
    }
    return probe;
}

static void event_probe_detach(EventProbe **ppProbe) {
    EventProbe *probe;
    if (!ppProbe || !*ppProbe) return;
    probe = *ppProbe;
    if (probe->cp && probe->cookie) {
        probe->cp->lpVtbl->Unadvise(probe->cp, probe->cookie);
    }
    if (probe->cp) {
        probe->cp->lpVtbl->Release(probe->cp);
    }
    if (probe->script_dispatch) {
        probe->script_dispatch->lpVtbl->Release(probe->script_dispatch);
    }
    if (probe->typeinfo) {
        probe->typeinfo->lpVtbl->Release(probe->typeinfo);
    }
    free(probe);
    *ppProbe = NULL;
}

static void dump_event_probe_snapshot(const EventProbe *probe, const char *tag, int test_no) {
    if (!probe) return;
    printf(
        "  EventProbe[%s][%02d]: "
        "BE=%d |SE=%d |AE=%d |BRC=%d |ARC=%d |BSC=%d |ASC=%d |BS=%d |AS=%d |"
        "BC=%d |AC=%d |BSCr=%d |ASCr=%d |BST=%d |BUR=%d |AUR=%d |AUF=%d |"
        "BMC=%d |AMC=%d |BMR=%d |AMR=%d |BMD=%d |BDR=%d |ADR=%d |BPB=%d |CLK=%d |DBL=%d |CBC=%d\n",
        tag,
        test_no,
        event_probe_count(probe, EVT_BEFORE_EDIT),
        event_probe_count(probe, EVT_START_EDIT),
        event_probe_count(probe, EVT_AFTER_EDIT),
        event_probe_count(probe, EVT_BEFORE_ROW_COL_CHANGE),
        event_probe_count(probe, EVT_AFTER_ROW_COL_CHANGE),
        event_probe_count(probe, EVT_BEFORE_SEL_CHANGE),
        event_probe_count(probe, EVT_AFTER_SEL_CHANGE),
        event_probe_count(probe, EVT_BEFORE_SORT),
        event_probe_count(probe, EVT_AFTER_SORT),
        event_probe_count(probe, EVT_BEFORE_COLLAPSE),
        event_probe_count(probe, EVT_AFTER_COLLAPSE),
        event_probe_count(probe, EVT_BEFORE_SCROLL),
        event_probe_count(probe, EVT_AFTER_SCROLL),
        event_probe_count(probe, EVT_BEFORE_SCROLL_TIP),
        event_probe_count(probe, EVT_BEFORE_USER_RESIZE),
        event_probe_count(probe, EVT_AFTER_USER_RESIZE),
        event_probe_count(probe, EVT_AFTER_USER_FREEZE),
        event_probe_count(probe, EVT_BEFORE_MOVE_COLUMN),
        event_probe_count(probe, EVT_AFTER_MOVE_COLUMN),
        event_probe_count(probe, EVT_BEFORE_MOVE_ROW),
        event_probe_count(probe, EVT_AFTER_MOVE_ROW),
        event_probe_count(probe, EVT_BEFORE_MOUSE_DOWN),
        event_probe_count(probe, EVT_BEFORE_DATA_REFRESH),
        event_probe_count(probe, EVT_AFTER_DATA_REFRESH),
        event_probe_count(probe, EVT_BEFORE_PAGE_BREAK),
        event_probe_count(probe, EVT_CLICK),
        event_probe_count(probe, EVT_DBLCLICK),
        event_probe_count(probe, EVT_CELL_BUTTON_CLICK));
}

static HWND find_visible_combo_popup_window(void) {
    HWND hwnd = NULL;
    while ((hwnd = FindWindowExW(NULL, hwnd, L"ComboLBox", NULL)) != NULL) {
        if (IsWindowVisible(hwnd)) return hwnd;
    }
    return NULL;
}

static int blit_host_client_from_screen(const HostedGrid *hg, HDC hdcMem, int w, int h) {
    HDC hdcScreen;
    POINT origin = {0, 0};
    HWND hwndTarget;
    BOOL ok;

    if (!hg || !hdcMem || !hg->hwnd_host || !IsWindow(hg->hwnd_host)) return -1;

    hwndTarget = (hg->hwnd_ctrl && IsWindow(hg->hwnd_ctrl)) ? hg->hwnd_ctrl : hg->hwnd_host;
    SetForegroundWindow(hg->hwnd_host);
    BringWindowToTop(hg->hwnd_host);
    SetFocus(hwndTarget);
    RedrawWindow(
        hg->hwnd_host,
        NULL,
        NULL,
        RDW_INVALIDATE | RDW_UPDATENOW | RDW_ALLCHILDREN | RDW_FRAME);
    pump_messages_ms(80);

    if (!ClientToScreen(hg->hwnd_host, &origin)) return -1;

    hdcScreen = GetDC(NULL);
    if (!hdcScreen) return -1;

    ok = BitBlt(hdcMem, 0, 0, w, h, hdcScreen, origin.x, origin.y, SRCCOPY | CAPTUREBLT);
    if (!ok) ok = BitBlt(hdcMem, 0, 0, w, h, hdcScreen, origin.x, origin.y, SRCCOPY);
    ReleaseDC(NULL, hdcScreen);

    if (ok) return 0;

    ok = PrintWindow(hwndTarget, hdcMem, PW_CLIENTONLY);
    if (!ok && hwndTarget != hg->hwnd_host) {
        ok = PrintWindow(hg->hwnd_host, hdcMem, PW_CLIENTONLY);
    }
    if (!ok && hwndTarget != hg->hwnd_host) {
        ok = PrintWindow(hg->hwnd_host, hdcMem, 0);
    }

    return ok ? 0 : -1;
}

static void overlay_visible_combo_popup(HDC hdcMem, const HostedGrid *hg) {
    HDC hdcScreen;
    HWND popup;

    if (!hdcMem || !hg || !hg->hwnd_host || !IsWindow(hg->hwnd_host)) return;

    popup = find_visible_combo_popup_window();
    if (!popup) return;

    hdcScreen = GetDC(NULL);
    if (!hdcScreen) return;

    {
        RECT pr;
        POINT origin = {0, 0};
        if (GetWindowRect(popup, &pr) && ClientToScreen(hg->hwnd_host, &origin)) {
            int dx = pr.left - origin.x;
            int dy = pr.top - origin.y;
            int pw = pr.right - pr.left;
            int ph = pr.bottom - pr.top;
            if (pw > 0 && ph > 0) {
                HDC hdcPopup = CreateCompatibleDC(hdcMem);
                HBITMAP hbmPopup = CreateCompatibleBitmap(hdcMem, pw, ph);
                HGDIOBJ hOldPopup = NULL;
                BOOL drawn = FALSE;

                if (hdcPopup && hbmPopup) {
                    RECT z = {0, 0, pw, ph};
                    HBRUSH b = CreateSolidBrush(RGB(255, 255, 255));
                    hOldPopup = SelectObject(hdcPopup, hbmPopup);
                    FillRect(hdcPopup, &z, b);
                    DeleteObject(b);
                }

                if (hdcPopup && hbmPopup && hOldPopup) {
                    drawn = PrintWindow(popup, hdcPopup, PW_CLIENTONLY);
                    if (!drawn) drawn = PrintWindow(popup, hdcPopup, 0);
                }

                if (drawn) {
                    BitBlt(hdcMem, dx, dy, pw, ph, hdcPopup, 0, 0, SRCCOPY);
                } else {
                    if (!BitBlt(hdcMem, dx, dy, pw, ph, hdcScreen, pr.left, pr.top, SRCCOPY | CAPTUREBLT)) {
                        BitBlt(hdcMem, dx, dy, pw, ph, hdcScreen, pr.left, pr.top, SRCCOPY);
                    }
                }

                if (hOldPopup) SelectObject(hdcPopup, hOldPopup);
                if (hbmPopup) DeleteObject(hbmPopup);
                if (hdcPopup) DeleteDC(hdcPopup);
            }
        }
    }

    ReleaseDC(NULL, hdcScreen);
}

/* Capture the live hosted control client area, then overlay a visible
 * ComboLBox popup (if any) from the desktop so dropdown lists are included.
 * Falls back to IViewObject::Draw if the live capture path is unavailable. */
static int render_to_bmp_with_popup(
    IDispatch *pGrid, const HostedGrid *hg, const char *filename, int w, int h)
{
    HDC hdcScreen, hdcMem;
    HBITMAP hbm;
    HGDIOBJ hOld;
    RECT rc;
    HBRUSH hBrush;
    int rc_capture;

    hdcScreen = GetDC(NULL);
    if (!hdcScreen) {
        return render_to_bmp(pGrid, filename, w, h);
    }
    hdcMem = CreateCompatibleDC(hdcScreen);
    hbm = CreateCompatibleBitmap(hdcScreen, w, h);
    hOld = SelectObject(hdcMem, hbm);

    rc.left = 0; rc.top = 0; rc.right = w; rc.bottom = h;
    hBrush = CreateSolidBrush(RGB(255, 255, 255));
    FillRect(hdcMem, &rc, hBrush);
    DeleteObject(hBrush);

    rc_capture = blit_host_client_from_screen(hg, hdcMem, w, h);
    if (rc_capture == 0) {
        overlay_visible_combo_popup(hdcMem, hg);
        save_bmp(hdcMem, hbm, w, h, filename);

        SelectObject(hdcMem, hOld);
        DeleteObject(hbm);
        DeleteDC(hdcMem);
        ReleaseDC(NULL, hdcScreen);
        return 0;
    }

    SelectObject(hdcMem, hOld);
    DeleteObject(hbm);
    DeleteDC(hdcMem);
    ReleaseDC(NULL, hdcScreen);
    return render_to_bmp(pGrid, filename, w, h);
}

static void hosted_grid_destroy(HostedGrid *hg) {
    if (!hg) return;

    if (hg->event_probe) {
        event_probe_detach(&hg->event_probe);
    }

    /* Properly deactivate in-place before releasing interfaces.
     * Without this, the control's Release triggers cleanup that calls back
     * into our site while still in-place active, crashing in Wine. */
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

    /* Clear site's copy BEFORE releasing to avoid double-release in host_release. */
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
    hg->hwnd_ctrl = NULL;
}

static int hosted_grid_create(HostedGrid *hg, const WCHAR *progid, const WCHAR *title, int width, int height, int x_offset) {
    CLSID clsid;
    HRESULT hr;
    RECT rc;
    IOleWindow *ole_window = NULL;

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
        /* Control doesn't support IOleObject (e.g. VolvoxGrid).
         * Fall back to dispatch-only mode: VBS + IViewObject capture. */
        hg->ole_obj = NULL;
        hr = CoCreateInstance(&clsid, NULL, CLSCTX_INPROC_SERVER, &IID_IDispatch, (void **)&hg->disp);
        if (FAILED(hr) || !hg->disp) {
            printf("  CoCreateInstance(IDispatch) failed: 0x%08lx\n", hr);
            hosted_grid_destroy(hg);
            return -1;
        }
        hg->event_probe = event_probe_attach(hg->disp);
        hg->dispatch_only = 1;
        hg->render_width = width;
        hg->render_height = height;
        return 0;
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
    hg->event_probe = event_probe_attach(hg->disp);

    hr = hg->ole_obj->lpVtbl->QueryInterface(hg->ole_obj, &IID_IOleWindow, (void **)&ole_window);
    if (SUCCEEDED(hr) && ole_window) {
        HWND h = NULL;
        if (SUCCEEDED(ole_window->lpVtbl->GetWindow(ole_window, &h)) && h) {
            hg->hwnd_ctrl = h;
        }
        ole_window->lpVtbl->Release(ole_window);
    }
    if (!hg->hwnd_ctrl) hg->hwnd_ctrl = hg->hwnd_host;

    hg->render_width = width;
    hg->render_height = height;
    SetForegroundWindow(hg->hwnd_host);
    SetFocus(hg->hwnd_ctrl);
    pump_messages_ms(120);

    return 0;
}

/* ════════════════════════════════════════════════════════════ */
/* VBScript engine via IActiveScript                            */
/* ════════════════════════════════════════════════════════════ */

typedef struct {
    IActiveScriptSiteVtbl *lpVtbl;
    LONG ref;
    IDispatch *grid;
    IDispatch *host_object;
    ITypeInfo *typeinfo;
} ScriptSite;

typedef struct {
    ScriptSite site;
    IActiveScript *script;
    IActiveScriptParse *parser;
    IDispatch *script_disp;
    EventProbe *event_probe;
} ScriptRuntime;

typedef struct {
    IDispatchVtbl *lpVtbl;
    LONG ref;
} ScriptHostHelper;

#define DISPID_HOST_CREATEOBJECT 1

static HRESULT STDMETHODCALLTYPE sh_qi(IDispatch *This, REFIID riid, void **ppv) {
    if (IsEqualGUID(riid, &IID_IUnknown) || IsEqualGUID(riid, &IID_IDispatch)) {
        *ppv = This;
        This->lpVtbl->AddRef(This);
        return S_OK;
    }
    *ppv = NULL;
    return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE sh_addref(IDispatch *This) {
    return InterlockedIncrement(&((ScriptHostHelper *)This)->ref);
}

static ULONG STDMETHODCALLTYPE sh_release(IDispatch *This) {
    ULONG ref = InterlockedDecrement(&((ScriptHostHelper *)This)->ref);
    if (ref == 0) free(This);
    return ref;
}

static HRESULT STDMETHODCALLTYPE sh_get_type_info_count(IDispatch *This, UINT *pctinfo) {
    (void)This;
    if (pctinfo) *pctinfo = 0;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE sh_get_type_info(
    IDispatch *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo)
{
    (void)This;
    (void)iTInfo;
    (void)lcid;
    if (ppTInfo) *ppTInfo = NULL;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE sh_get_ids_of_names(
    IDispatch *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId)
{
    UINT i;
    (void)This;
    (void)riid;
    (void)lcid;
    if (!rgszNames || !rgDispId) return E_POINTER;
    for (i = 0; i < cNames; ++i) {
        if (lstrcmpiW(rgszNames[i], L"CreateObject") == 0) {
            rgDispId[i] = DISPID_HOST_CREATEOBJECT;
        } else {
            rgDispId[i] = DISPID_UNKNOWN;
            return DISP_E_UNKNOWNNAME;
        }
    }
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE sh_invoke(
    IDispatch *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags,
    DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr)
{
    VARIANT arg_bstr;
    BSTR progid = NULL;
    CLSID clsid;
    IDispatch *disp = NULL;
    HRESULT hr;

    (void)This;
    (void)riid;
    (void)lcid;
    if (pVarResult) VariantInit(pVarResult);
    if (pExcepInfo) memset(pExcepInfo, 0, sizeof(*pExcepInfo));
    if (puArgErr) *puArgErr = 0;

    if (dispIdMember != DISPID_HOST_CREATEOBJECT || !(wFlags & DISPATCH_METHOD)) {
        return DISP_E_MEMBERNOTFOUND;
    }
    if (!pDispParams || pDispParams->cArgs < 1) return DISP_E_BADPARAMCOUNT;

    VariantInit(&arg_bstr);
    hr = VariantChangeType(&arg_bstr, &pDispParams->rgvarg[0], 0, VT_BSTR);
    if (FAILED(hr)) return hr;
    progid = V_BSTR(&arg_bstr);

    hr = CLSIDFromProgID(progid, &clsid);
    if (SUCCEEDED(hr)) {
        hr = CoCreateInstance(&clsid, NULL, CLSCTX_INPROC_SERVER, &IID_IDispatch, (void **)&disp);
    }
    if (SUCCEEDED(hr) && pVarResult) {
        V_VT(pVarResult) = VT_DISPATCH;
        V_DISPATCH(pVarResult) = disp;
        disp = NULL;
    }

    if (disp) disp->lpVtbl->Release(disp);
    VariantClear(&arg_bstr);
    return hr;
}

static IDispatchVtbl g_script_host_helper_vtbl = {
    sh_qi,
    sh_addref,
    sh_release,
    sh_get_type_info_count,
    sh_get_type_info,
    sh_get_ids_of_names,
    sh_invoke
};

static IDispatch *script_host_helper_create(void) {
    ScriptHostHelper *helper = (ScriptHostHelper *)calloc(1, sizeof(*helper));
    if (!helper) return NULL;
    helper->lpVtbl = &g_script_host_helper_vtbl;
    helper->ref = 1;
    return (IDispatch *)helper;
}

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
    (void)This;
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
        if ((mask & SCRIPTINFO_ITYPEINFO) && ppTI && ss->typeinfo) {
            *ppTI = ss->typeinfo;
            ss->typeinfo->lpVtbl->AddRef(ss->typeinfo);
        }
        return S_OK;
    }
    if (wcscmp(name, L"host") == 0) {
        if ((mask & SCRIPTINFO_IUNKNOWN) && ppUnk && ss->host_object) {
            *ppUnk = (IUnknown *)ss->host_object;
            ss->host_object->lpVtbl->AddRef(ss->host_object);
        }
        return S_OK;
    }
    return TYPE_E_ELEMENTNOTFOUND;
}
static HRESULT STDMETHODCALLTYPE ss_docver(IActiveScriptSite *This, BSTR *p) {
    (void)This;
    *p = SysAllocString(L"1.0");
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE ss_onterm(IActiveScriptSite *This,
    const VARIANT *pv, const EXCEPINFO *pe) { (void)This; (void)pv; (void)pe; return S_OK; }
static HRESULT STDMETHODCALLTYPE ss_onstate(IActiveScriptSite *This,
    SCRIPTSTATE st) { (void)This; (void)st; return S_OK; }
static HRESULT STDMETHODCALLTYPE ss_onerror(IActiveScriptSite *This,
    IActiveScriptError *pErr)
{
    EXCEPINFO ei;
    DWORD ctx;
    ULONG line;
    LONG ch;
    (void)This;

    memset(&ei, 0, sizeof(ei));
    if (SUCCEEDED(pErr->lpVtbl->GetExceptionInfo(pErr, &ei))) {
        if (ei.bstrDescription)
            printf("  VBS error: %ls\n", ei.bstrDescription);
        SysFreeString(ei.bstrSource);
        SysFreeString(ei.bstrDescription);
        SysFreeString(ei.bstrHelpFile);
    }
    if (SUCCEEDED(pErr->lpVtbl->GetSourcePosition(pErr, &ctx, &line, &ch)))
        printf("  at line %lu, char %ld\n", (unsigned long)(line + 1), (long)ch);
    return S_OK;
}
static HRESULT STDMETHODCALLTYPE ss_enter(IActiveScriptSite *This) { (void)This; return S_OK; }
static HRESULT STDMETHODCALLTYPE ss_leave(IActiveScriptSite *This) { (void)This; return S_OK; }

static IActiveScriptSiteVtbl g_ss_vtbl = {
    ss_qi, ss_addref, ss_release,
    ss_getlcid, ss_getiteminfo, ss_docver,
    ss_onterm, ss_onstate, ss_onerror,
    ss_enter, ss_leave
};

static HRESULT get_named_item_typeinfo(IDispatch *disp, ITypeInfo **ppTI) {
    IProvideClassInfo *pci = NULL;
    HRESULT hr;

    if (!ppTI) return E_POINTER;
    *ppTI = NULL;
    if (!disp) return E_INVALIDARG;

    hr = disp->lpVtbl->QueryInterface(disp, &IID_IProvideClassInfo, (void **)&pci);
    if (SUCCEEDED(hr) && pci) {
        hr = pci->lpVtbl->GetClassInfo(pci, ppTI);
        pci->lpVtbl->Release(pci);
        if (SUCCEEDED(hr) && *ppTI) return hr;
    }

    return disp->lpVtbl->GetTypeInfo(disp, 0, LOCALE_USER_DEFAULT, ppTI);
}

/* VBS preamble: defines helper arrays and compatibility helpers. */
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
    L"Sub SortColumn(order, col)\r\n"
    L"    fg.Col = col\r\n"
    L"    fg.ColSel = col\r\n"
    L"    fg.Sort = order\r\n"
    L"End Sub\r\n"
    L"\r\n"
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

static WCHAR *load_file_wide(const char *path) {
    FILE *f = fopen(path, "rb");
    long sz;
    char *buf;
    WCHAR *wbuf;
    int wlen;

    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    sz = ftell(f);
    fseek(f, 0, SEEK_SET);

    buf = (char *)malloc(sz + 1);
    if (!buf) {
        fclose(f);
        return NULL;
    }
    fread(buf, 1, sz, f);
    buf[sz] = '\0';
    fclose(f);

    wlen = MultiByteToWideChar(CP_UTF8, 0, buf, -1, NULL, 0);
    wbuf = (WCHAR *)malloc(wlen * sizeof(WCHAR));
    if (!wbuf) {
        free(buf);
        return NULL;
    }
    MultiByteToWideChar(CP_UTF8, 0, buf, -1, wbuf, wlen);
    free(buf);
    return wbuf;
}

static WCHAR *build_full_vbs(const WCHAR *code) {
    int preamble_len;
    int code_len;
    WCHAR *full;

    if (!code) return NULL;

    preamble_len = (int)wcslen(g_vbs_preamble);
    code_len = (int)wcslen(code);
    full = (WCHAR *)malloc((preamble_len + code_len + 1) * sizeof(WCHAR));
    if (!full) return NULL;

    memcpy(full, g_vbs_preamble, preamble_len * sizeof(WCHAR));
    memcpy(full + preamble_len, code, (code_len + 1) * sizeof(WCHAR));
    return full;
}

static int save_utf8_from_wide(const char *path, const WCHAR *text) {
    FILE *f;
    int bytes;
    char *buf;

    if (!path || !text) return -1;

    bytes = WideCharToMultiByte(CP_UTF8, 0, text, -1, NULL, 0, NULL, NULL);
    if (bytes <= 0) return -1;

    buf = (char *)malloc((size_t)bytes);
    if (!buf) return -1;

    if (WideCharToMultiByte(CP_UTF8, 0, text, -1, buf, bytes, NULL, NULL) <= 0) {
        free(buf);
        return -1;
    }

    f = fopen(path, "wb");
    if (!f) {
        free(buf);
        return -1;
    }

    fwrite(buf, 1, (size_t)(bytes - 1), f);
    fclose(f);
    free(buf);
    return 0;
}

static void close_script_runtime(ScriptRuntime *rt) {
    if (!rt) return;
    if (rt->event_probe) {
        event_probe_bind_script_dispatch(rt->event_probe, NULL, NULL);
        rt->event_probe = NULL;
    }
    if (rt->script_disp) {
        rt->script_disp->lpVtbl->Release(rt->script_disp);
        rt->script_disp = NULL;
    }
    if (rt->site.typeinfo) {
        rt->site.typeinfo->lpVtbl->Release(rt->site.typeinfo);
        rt->site.typeinfo = NULL;
    }
    if (rt->site.host_object) {
        rt->site.host_object->lpVtbl->Release(rt->site.host_object);
        rt->site.host_object = NULL;
    }
    if (rt->script) {
        rt->script->lpVtbl->Close(rt->script);
    }
    if (rt->parser) {
        rt->parser->lpVtbl->Release(rt->parser);
        rt->parser = NULL;
    }
    if (rt->script) {
        rt->script->lpVtbl->Release(rt->script);
        rt->script = NULL;
    }
}

static HRESULT start_vbs_runtime(ScriptRuntime *rt, const HostedGrid *hg, const WCHAR *code) {
    HRESULT hr;
    WCHAR *full;
    IDispatch *grid = hg ? hg->disp : NULL;

    if (!rt) return E_POINTER;
    memset(rt, 0, sizeof(*rt));

    rt->site.lpVtbl = &g_ss_vtbl;
    rt->site.ref = 1;
    rt->site.grid = grid;
    rt->site.host_object = script_host_helper_create();
    get_named_item_typeinfo(grid, &rt->site.typeinfo);

    hr = CoCreateInstance(&CLSID_VBScript, NULL, CLSCTX_INPROC_SERVER,
                                   &IID_IActiveScript, (void **)&rt->script);
    if (FAILED(hr)) {
        printf("  CoCreateInstance(VBScript) failed: 0x%08lx\n", hr);
        return hr;
    }

    hr = rt->script->lpVtbl->QueryInterface(rt->script, &MY_IID_IActiveScriptParse, (void **)&rt->parser);
    if (FAILED(hr)) {
        printf("  QI(IActiveScriptParse) failed: 0x%08lx\n", hr);
        close_script_runtime(rt);
        return hr;
    }

    rt->parser->lpVtbl->InitNew(rt->parser);
    rt->script->lpVtbl->SetScriptSite(rt->script, (IActiveScriptSite *)&rt->site);
    rt->script->lpVtbl->AddNamedItem(rt->script, L"fg", SCRIPTITEM_ISVISIBLE | SCRIPTITEM_ISSOURCE);
    rt->script->lpVtbl->AddNamedItem(rt->script, L"host", SCRIPTITEM_ISVISIBLE);

    full = build_full_vbs(code);
    if (!full) {
        close_script_runtime(rt);
        return E_OUTOFMEMORY;
    }

    {
        EXCEPINFO ei;
        memset(&ei, 0, sizeof(ei));
        hr = rt->parser->lpVtbl->ParseScriptText(rt->parser, full, NULL, NULL, NULL,
                                           0, 0, 0, NULL, &ei);
    }

    free(full);

    if (SUCCEEDED(hr)) {
        rt->script->lpVtbl->SetScriptState(rt->script, SCRIPTSTATE_CONNECTED);
        if (hg && hg->event_probe) {
            hr = rt->script->lpVtbl->GetScriptDispatch(rt->script, NULL, &rt->script_disp);
            if (SUCCEEDED(hr) && rt->script_disp) {
                rt->event_probe = hg->event_probe;
                event_probe_bind_script_dispatch(rt->event_probe, rt->script_disp, L"fg_");
            } else {
                rt->script_disp = NULL;
            }
        }
    } else {
        close_script_runtime(rt);
    }

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
    { "row_state_marks",    800, 350 },
    { "col_combo_lists",    800, 380 },
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
    { "interaction_props", 780, 320 },
    { "event_rowcolchange", 820, 320 },
    { "event_selchange", 820, 320 },
    { "event_edit", 820, 360 },
    { "event_sort", 820, 320 },
    { "event_collapse", 820, 360 },
    { "event_scroll", 820, 360 },
    { "event_user_resize", 820, 320 },
    { "event_move_column", 820, 320 },
    { "event_move_row", 820, 340 },
    { "event_mouse_down", 820, 320 },
    { "event_data_refresh", 840, 380 },
    { "event_scroll_tip", 820, 360 },
    { "event_user_freeze", 820, 320 },
    { "event_page_break", 840, 420 },
    { NULL, 0, 0 }
};

/* ── Pixel diff between two BMPs ─────────────────────────── */

static BYTE *load_bmp_pixels(const char *filename, int *out_w, int *out_h) {
    FILE *f = fopen(filename, "rb");
    BITMAPFILEHEADER bf;
    BITMAPINFOHEADER bi;
    int stride;
    int dataSize;
    BYTE *pixels;

    if (!f) return NULL;
    if (fread(&bf, sizeof(bf), 1, f) != 1 || bf.bfType != 0x4D42) {
        fclose(f);
        return NULL;
    }
    if (fread(&bi, sizeof(bi), 1, f) != 1) {
        fclose(f);
        return NULL;
    }
    if (bi.biBitCount != 24) {
        fclose(f);
        return NULL;
    }

    *out_w = bi.biWidth;
    *out_h = abs(bi.biHeight);
    stride = ((bi.biWidth * 3 + 3) & ~3);
    dataSize = stride * (*out_h);
    pixels = (BYTE *)malloc(dataSize);
    if (!pixels) {
        fclose(f);
        return NULL;
    }

    fseek(f, bf.bfOffBits, SEEK_SET);
    fread(pixels, dataSize, 1, f);
    fclose(f);
    return pixels;
}

static double compare_bmps(const char *file_vs, const char *file_vv,
                            const char *diff_file) {
    int w1, h1, w2, h2;
    BYTE *px1 = load_bmp_pixels(file_vs, &w1, &h1);
    BYTE *px2 = load_bmp_pixels(file_vv, &w2, &h2);
    int w, h;
    int stride1, stride2, strideD;
    long long total_pixels;
    long long matching = 0;
    BYTE *diff;
    int y, x;

    if (!px1 || !px2) {
        free(px1);
        free(px2);
        return -1.0;
    }

    w = (w1 < w2) ? w1 : w2;
    h = (h1 < h2) ? h1 : h2;
    stride1 = ((w1 * 3 + 3) & ~3);
    stride2 = ((w2 * 3 + 3) & ~3);
    strideD = ((w * 3 + 3) & ~3);

    total_pixels = (long long)w * h;
    diff = (BYTE *)malloc(strideD * h);
    if (!diff) {
        free(px1);
        free(px2);
        return -1.0;
    }
    memset(diff, 0xFF, strideD * h);

    for (y = 0; y < h; y++) {
        BYTE *row1 = px1 + y * stride1;
        BYTE *row2 = px2 + y * stride2;
        BYTE *rowD = diff + y * strideD;
        for (x = 0; x < w; x++) {
            int b1 = row1[x*3+0], g1 = row1[x*3+1], r1 = row1[x*3+2];
            int b2 = row2[x*3+0], g2 = row2[x*3+1], r2 = row2[x*3+2];
            int dr = abs(r1-r2), dg = abs(g1-g2), db = abs(b1-b2);
            int d = dr + dg + db;
            if (d <= 12) {
                matching++;
                rowD[x*3+0] = (BYTE)((b1 + b2) / 2);
                rowD[x*3+1] = (BYTE)((g1 + g2) / 2);
                rowD[x*3+2] = (BYTE)((r1 + r2) / 2);
            } else {
                int intensity = (d * 255) / (3 * 255);
                if (intensity > 255) intensity = 255;
                rowD[x*3+0] = 0;
                rowD[x*3+1] = 0;
                rowD[x*3+2] = (BYTE)(128 + intensity / 2);
            }
        }
    }

    if (diff_file) {
        FILE *f = fopen(diff_file, "wb");
        if (f) {
            BITMAPINFOHEADER bi = {0};
            BITMAPFILEHEADER bf = {0};
            bi.biSize = sizeof(bi);
            bi.biWidth = w;
            bi.biHeight = h;
            bi.biPlanes = 1;
            bi.biBitCount = 24;
            bi.biCompression = BI_RGB;
            bi.biSizeImage = strideD * h;
            bf.bfType = 0x4D42;
            bf.bfOffBits = sizeof(bf) + sizeof(bi);
            bf.bfSize = bf.bfOffBits + bi.biSizeImage;
            fwrite(&bf, sizeof(bf), 1, f);
            fwrite(&bi, sizeof(bi), 1, f);
            fwrite(diff, bi.biSizeImage, 1, f);
            fclose(f);
        }
    }

    free(px1);
    free(px2);
    free(diff);

    if (total_pixels == 0) return 0.0;
    return (double)matching * 100.0 / (double)total_pixels;
}

/* ── UI action playback (tests/NN_name.ux) ───────────────── */

static int parse_vk_token(const char *tok) {
    if (!tok || !*tok) return 0;

    if (isdigit((unsigned char)tok[0])) {
        return atoi(tok);
    }

    if (_stricmp(tok, "F2") == 0) return VK_F2;
    if (_stricmp(tok, "F4") == 0) return VK_F4;
    if (_stricmp(tok, "SPACE") == 0) return VK_SPACE;
    if (_stricmp(tok, "ENTER") == 0) return VK_RETURN;
    if (_stricmp(tok, "ESC") == 0 || _stricmp(tok, "ESCAPE") == 0) return VK_ESCAPE;
    if (_stricmp(tok, "UP") == 0) return VK_UP;
    if (_stricmp(tok, "DOWN") == 0) return VK_DOWN;
    if (_stricmp(tok, "LEFT") == 0) return VK_LEFT;
    if (_stricmp(tok, "RIGHT") == 0) return VK_RIGHT;
    if (_stricmp(tok, "TAB") == 0) return VK_TAB;

    if (strlen(tok) == 1) {
        SHORT v = VkKeyScanA(tok[0]);
        if (v != -1) return (v & 0xFF);
    }
    return 0;
}

static int get_col_width_px(IDispatch *disp, int col, int dpi_x) {
    int w = get_indexed_int(disp, L"ColWidth", col, 0);
    w = units_to_px(w, dpi_x, 64);
    if (w < 8) w = 8;
    return w;
}

static int get_row_height_px(IDispatch *disp, int row, int dpi_y) {
    int h = get_indexed_int(disp, L"RowHeight", row, 0);
    h = units_to_px(h, dpi_y, 20);
    if (h < 8) h = 8;
    return h;
}

static int grid_cell_rect_px(IDispatch *disp, int row, int col, RECT *rc_out) {
    int rows = get_int(disp, L"Rows", 0);
    int cols = get_int(disp, L"Cols", 0);
    int fixed_rows = get_int(disp, L"FixedRows", 1);
    int fixed_cols = get_int(disp, L"FixedCols", 0);
    int top_row = get_int(disp, L"TopRow", fixed_rows);
    int left_col = get_int(disp, L"LeftCol", fixed_cols);
    HDC hdc = GetDC(NULL);
    int dpi_x = GetDeviceCaps(hdc, LOGPIXELSX);
    int dpi_y = GetDeviceCaps(hdc, LOGPIXELSY);
    int x = 1;
    int y = 1;
    int c;
    int r;

    ReleaseDC(NULL, hdc);

    if (!rc_out) return -1;
    if (row < 0 || col < 0 || row >= rows || col >= cols) return -1;

    if (left_col < fixed_cols) left_col = fixed_cols;
    if (top_row < fixed_rows) top_row = fixed_rows;

    if (col < fixed_cols) {
        for (c = 0; c < col; c++) x += get_col_width_px(disp, c, dpi_x);
    } else {
        for (c = 0; c < fixed_cols; c++) x += get_col_width_px(disp, c, dpi_x);
        for (c = left_col; c < col; c++) x += get_col_width_px(disp, c, dpi_x);
    }

    if (row < fixed_rows) {
        for (r = 0; r < row; r++) y += get_row_height_px(disp, r, dpi_y);
    } else {
        for (r = 0; r < fixed_rows; r++) y += get_row_height_px(disp, r, dpi_y);
        for (r = top_row; r < row; r++) y += get_row_height_px(disp, r, dpi_y);
    }

    rc_out->left = x;
    rc_out->top = y;
    rc_out->right = x + get_col_width_px(disp, col, dpi_x);
    rc_out->bottom = y + get_row_height_px(disp, row, dpi_y);
    return 0;
}

static void send_key_to_control(const HostedGrid *hg, int vk) {
    HWND hwndTarget = hg->hwnd_ctrl ? hg->hwnd_ctrl : hg->hwnd_host;
    if (!hwndTarget || vk == 0) return;

    SetForegroundWindow(hg->hwnd_host);
    SetFocus(hwndTarget);
    PostMessage(hwndTarget, WM_KEYDOWN, (WPARAM)vk, 1);
    PostMessage(hwndTarget, WM_KEYUP, (WPARAM)vk, (LPARAM)(1u << 31) | (1u << 30));
    pump_messages_ms(60);
}

static void click_host_client_point(const HostedGrid *hg, int x_host, int y_host, int dbl_click) {
    HWND hwndTarget = hg->hwnd_ctrl ? hg->hwnd_ctrl : hg->hwnd_host;
    POINT pt;
    int i;
    int clicks = dbl_click ? 2 : 1;

    if (!hwndTarget) return;

    pt.x = x_host;
    pt.y = y_host;
    MapWindowPoints(hg->hwnd_host, hwndTarget, &pt, 1);

    SetForegroundWindow(hg->hwnd_host);
    SetFocus(hwndTarget);

    for (i = 0; i < clicks; i++) {
        PostMessage(hwndTarget, WM_MOUSEMOVE, 0, MAKELPARAM(pt.x, pt.y));
        PostMessage(hwndTarget, WM_LBUTTONDOWN, MK_LBUTTON, MAKELPARAM(pt.x, pt.y));
        PostMessage(hwndTarget, WM_LBUTTONUP, 0, MAKELPARAM(pt.x, pt.y));
        pump_messages_ms(40);
    }
}

typedef struct {
    HWND owner;
    DWORD timeout_ms;
    volatile LONG done;
} AutoDialogOkContext;

static HWND find_visible_dialog_window(HWND owner) {
    HWND hwnd = NULL;
    while ((hwnd = FindWindowExW(NULL, hwnd, L"#32770", NULL)) != NULL) {
        HWND hwnd_owner;
        if (!IsWindowVisible(hwnd)) continue;
        if (!owner) return hwnd;
        hwnd_owner = GetWindow(hwnd, GW_OWNER);
        if (hwnd_owner == owner || hwnd == GetLastActivePopup(owner)) {
            return hwnd;
        }
    }
    return NULL;
}

static DWORD WINAPI auto_dialog_ok_thread(LPVOID param) {
    AutoDialogOkContext *ctx = (AutoDialogOkContext *)param;
    DWORD start = GetTickCount();

    if (!ctx) return 0;

    while (InterlockedCompareExchange(&ctx->done, 0, 0) == 0) {
        HWND hwnd = find_visible_dialog_window(ctx->owner);
        if (hwnd) {
            HWND ok = GetDlgItem(hwnd, IDOK);
            if (ok) {
                SendMessageW(ok, BM_CLICK, 0, 0);
                break;
            }
            PostMessageW(hwnd, WM_COMMAND, MAKEWPARAM(IDOK, BN_CLICKED), 0);
            break;
        }
        if (GetTickCount() - start >= ctx->timeout_ms) {
            break;
        }
        Sleep(50);
    }
    return 0;
}

static HRESULT call_method0_named_utf8_auto_dialog_ok(
    IDispatch *pDisp, const char *name_utf8, HWND owner, DWORD timeout_ms)
{
    AutoDialogOkContext ctx;
    HANDLE thread = NULL;
    HRESULT hr;

    ZeroMemory(&ctx, sizeof(ctx));
    ctx.owner = owner;
    ctx.timeout_ms = timeout_ms > 0 ? timeout_ms : 3000;
    ctx.done = 0;

    thread = CreateThread(NULL, 0, auto_dialog_ok_thread, &ctx, 0, NULL);
    hr = call_method0_named_utf8(pDisp, name_utf8);
    InterlockedExchange(&ctx.done, 1);
    if (thread) {
        WaitForSingleObject(thread, ctx.timeout_ms);
        CloseHandle(thread);
    }
    return hr;
}

static void drag_host_client_points(
    const HostedGrid *hg, int x1_host, int y1_host, int x2_host, int y2_host, int steps)
{
    HWND hwndTarget = hg->hwnd_ctrl ? hg->hwnd_ctrl : hg->hwnd_host;
    POINT pt1;
    POINT pt2;
    int i;

    if (!hwndTarget) return;
    if (steps < 1) steps = 1;

    pt1.x = x1_host;
    pt1.y = y1_host;
    pt2.x = x2_host;
    pt2.y = y2_host;
    MapWindowPoints(hg->hwnd_host, hwndTarget, &pt1, 1);
    MapWindowPoints(hg->hwnd_host, hwndTarget, &pt2, 1);

    SetForegroundWindow(hg->hwnd_host);
    SetFocus(hwndTarget);

    PostMessage(hwndTarget, WM_MOUSEMOVE, 0, MAKELPARAM(pt1.x, pt1.y));
    PostMessage(hwndTarget, WM_LBUTTONDOWN, MK_LBUTTON, MAKELPARAM(pt1.x, pt1.y));
    pump_messages_ms(50);

    for (i = 1; i <= steps; i++) {
        int xi = pt1.x + ((pt2.x - pt1.x) * i) / steps;
        int yi = pt1.y + ((pt2.y - pt1.y) * i) / steps;
        PostMessage(hwndTarget, WM_MOUSEMOVE, MK_LBUTTON, MAKELPARAM(xi, yi));
        pump_messages_ms(30);
    }

    PostMessage(hwndTarget, WM_LBUTTONUP, 0, MAKELPARAM(pt2.x, pt2.y));
    pump_messages_ms(80);
}

static void drag_internal_points(
    IDispatch *disp, int x1, int y1, int x2, int y2, int steps)
{
    int i;
    if (!disp) return;
    if (steps < 1) steps = 1;

    call_method4_r4_r4_i4_i4_named_utf8(
        disp, "PointerDown", (float)x1, (float)y1, 1, 0);
    pump_messages_ms(50);

    for (i = 1; i <= steps; ++i) {
        int xi = x1 + ((x2 - x1) * i) / steps;
        int yi = y1 + ((y2 - y1) * i) / steps;
        call_method4_r4_r4_i4_i4_named_utf8(
            disp, "PointerMove", (float)xi, (float)yi, 1, 0);
        pump_messages_ms(30);
    }

    call_method4_r4_r4_i4_i4_named_utf8(
        disp, "PointerUp", (float)x2, (float)y2, 1, 0);
    pump_messages_ms(80);
}

static int cell_anchor_point_px(const RECT *rc, const char *anchor, int *out_x, int *out_y) {
    if (!rc || !anchor || !out_x || !out_y) return -1;

    *out_x = (rc->left + rc->right) / 2;
    *out_y = (rc->top + rc->bottom) / 2;

    if (_stricmp(anchor, "left") == 0) {
        *out_x = rc->left + 1;
    } else if (_stricmp(anchor, "right") == 0) {
        *out_x = rc->right - 2;
    } else if (_stricmp(anchor, "top") == 0) {
        *out_y = rc->top + 1;
    } else if (_stricmp(anchor, "bottom") == 0) {
        *out_y = rc->bottom - 2;
    } else if (_stricmp(anchor, "center") != 0) {
        return -1;
    }

    return 0;
}

static void apply_ux_actions(const HostedGrid *hg, IDispatch *disp, int test_no, const char *test_name) {
    char path[320];
    FILE *f;
    char line[256];

    snprintf(path, sizeof(path), "tests/%02d_%s.ux", test_no, test_name);
    if (!file_exists(path)) return;

    f = fopen(path, "rb");
    if (!f) return;

    printf("  UX actions: %s\n", path);

    while (fgets(line, sizeof(line), f)) {
        char *p;
        char *cmd;
        rstrip_inplace(line);
        p = lstrip_ptr(line);
        if (*p == '\0' || *p == '#') continue;

        cmd = strtok(p, " \t");
        if (!cmd) continue;

        if (_stricmp(cmd, "sleep") == 0) {
            char *ms_s = strtok(NULL, " \t");
            int ms = ms_s ? atoi(ms_s) : 80;
            if (ms < 0) ms = 0;
            pump_messages_ms((DWORD)ms);
            continue;
        }

        if (_stricmp(cmd, "set_cell") == 0) {
            char *r_s = strtok(NULL, " \t");
            char *c_s = strtok(NULL, " \t");
            if (r_s && c_s) {
                int r = atoi(r_s);
                int c = atoi(c_s);
                put_int(disp, L"Row", r);
                put_int(disp, L"Col", c);
                pump_messages_ms(80);
            }
            continue;
        }

        if (_stricmp(cmd, "set_prop_i4") == 0) {
            char *name_s = strtok(NULL, " \t");
            char *val_s = strtok(NULL, " \t");
            if (name_s && val_s) {
                put_int_named_utf8(disp, name_s, atoi(val_s));
                pump_messages_ms(80);
            }
            continue;
        }

        if (_stricmp(cmd, "set_indexed_prop_i4") == 0) {
            char *name_s = strtok(NULL, " \t");
            char *idx_s = strtok(NULL, " \t");
            char *val_s = strtok(NULL, " \t");
            if (name_s && idx_s && val_s) {
                put_indexed_int_named_utf8(disp, name_s, atoi(idx_s), atoi(val_s));
                pump_messages_ms(80);
            }
            continue;
        }

        if (_stricmp(cmd, "call_method0") == 0) {
            char *name_s = strtok(NULL, " \t");
            if (name_s) {
                call_method0_named_utf8(disp, name_s);
                pump_messages_ms(80);
            }
            continue;
        }

        if (_stricmp(cmd, "call_method0_autodialog_ok") == 0) {
            char *name_s = strtok(NULL, " \t");
            char *timeout_s = strtok(NULL, " \t");
            DWORD timeout_ms = timeout_s ? (DWORD)atoi(timeout_s) : 3000;
            if (name_s) {
                call_method0_named_utf8_auto_dialog_ok(
                    disp, name_s, hg ? hg->hwnd_host : NULL, timeout_ms);
                pump_messages_ms(120);
            }
            continue;
        }

        if (_stricmp(cmd, "call_method2_i4") == 0) {
            char *name_s = strtok(NULL, " \t");
            char *arg0_s = strtok(NULL, " \t");
            char *arg1_s = strtok(NULL, " \t");
            if (name_s && arg0_s && arg1_s) {
                WCHAR wname[128];
                if (MultiByteToWideChar(CP_UTF8, 0, name_s, -1, wname, 128) > 0) {
                    call_method2_i4(disp, wname, atoi(arg0_s), atoi(arg1_s));
                    pump_messages_ms(80);
                }
            }
            continue;
        }

        if (_stricmp(cmd, "call_method2_r4") == 0) {
            char *name_s = strtok(NULL, " \t");
            char *arg0_s = strtok(NULL, " \t");
            char *arg1_s = strtok(NULL, " \t");
            if (name_s && arg0_s && arg1_s) {
                call_method2_r4_named_utf8(
                    disp, name_s, (float)atof(arg0_s), (float)atof(arg1_s));
                pump_messages_ms(80);
            }
            continue;
        }

        if (_stricmp(cmd, "click_cell") == 0 || _stricmp(cmd, "dblclick_cell") == 0 || _stricmp(cmd, "click_combo") == 0) {
            char *r_s = strtok(NULL, " \t");
            char *c_s = strtok(NULL, " \t");
            RECT rc;
            int is_dbl = (_stricmp(cmd, "dblclick_cell") == 0);
            int is_combo = (_stricmp(cmd, "click_combo") == 0);

            if (r_s && c_s) {
                int r = atoi(r_s);
                int c = atoi(c_s);
                if (hg->dispatch_only) {
                    put_int(disp, L"Row", r);
                    put_int(disp, L"Col", c);
                    if (is_dbl || is_combo) {
                        call_method2_i4(disp, L"EditCell", r, c);
                    }
                    pump_messages_ms(120);
                    continue;
                }
                if (grid_cell_rect_px(disp, r, c, &rc) == 0) {
                    int cx = (rc.left + rc.right) / 2;
                    int cy = (rc.top + rc.bottom) / 2;
                    click_host_client_point(hg, cx, cy, is_dbl);
                    if (is_combo) {
                        int arrow_x = rc.right - 8;
                        int arrow_y = (rc.top + rc.bottom) / 2;
                        pump_messages_ms(80);
                        click_host_client_point(hg, arrow_x, arrow_y, 0);
                    }
                    pump_messages_ms(120);
                }
            }
            continue;
        }

        if (_stricmp(cmd, "drag_cell") == 0) {
            char *r1_s = strtok(NULL, " \t");
            char *c1_s = strtok(NULL, " \t");
            char *r2_s = strtok(NULL, " \t");
            char *c2_s = strtok(NULL, " \t");
            RECT rc1;
            RECT rc2;

            if (r1_s && c1_s && r2_s && c2_s) {
                int r1 = atoi(r1_s);
                int c1 = atoi(c1_s);
                int r2 = atoi(r2_s);
                int c2 = atoi(c2_s);
                if (hg->dispatch_only) {
                    put_int(disp, L"Row", r2);
                    put_int(disp, L"Col", c2);
                    pump_messages_ms(120);
                    continue;
                }
                if (grid_cell_rect_px(disp, r1, c1, &rc1) == 0 &&
                    grid_cell_rect_px(disp, r2, c2, &rc2) == 0) {
                    drag_host_client_points(
                        hg,
                        (rc1.left + rc1.right) / 2,
                        (rc1.top + rc1.bottom) / 2,
                        (rc2.left + rc2.right) / 2,
                        (rc2.top + rc2.bottom) / 2,
                        8);
                }
            }
            continue;
        }

        if (_stricmp(cmd, "drag_cell_edge") == 0) {
            char *r1_s = strtok(NULL, " \t");
            char *c1_s = strtok(NULL, " \t");
            char *edge_s = strtok(NULL, " \t");
            char *r2_s = strtok(NULL, " \t");
            char *c2_s = strtok(NULL, " \t");
            RECT rc1;
            RECT rc2;

            if (r1_s && c1_s && edge_s && r2_s && c2_s) {
                int r1 = atoi(r1_s);
                int c1 = atoi(c1_s);
                int r2 = atoi(r2_s);
                int c2 = atoi(c2_s);
                int x1 = 0;
                int y1 = 0;

                if (hg->dispatch_only) {
                    put_int(disp, L"Row", r2);
                    put_int(disp, L"Col", c2);
                    pump_messages_ms(120);
                    continue;
                }
                if (grid_cell_rect_px(disp, r1, c1, &rc1) == 0 &&
                    grid_cell_rect_px(disp, r2, c2, &rc2) == 0 &&
                    cell_anchor_point_px(&rc1, edge_s, &x1, &y1) == 0) {
                    drag_host_client_points(
                        hg,
                        x1,
                        y1,
                        (rc2.left + rc2.right) / 2,
                        (rc2.top + rc2.bottom) / 2,
                        8);
                }
            }
            continue;
        }

        if (_stricmp(cmd, "drag_cell_edge_internal") == 0) {
            char *r1_s = strtok(NULL, " \t");
            char *c1_s = strtok(NULL, " \t");
            char *edge_s = strtok(NULL, " \t");
            char *r2_s = strtok(NULL, " \t");
            char *c2_s = strtok(NULL, " \t");
            char *steps_s = strtok(NULL, " \t");
            RECT rc1;
            RECT rc2;

            if (r1_s && c1_s && edge_s && r2_s && c2_s) {
                int r1 = atoi(r1_s);
                int c1 = atoi(c1_s);
                int r2 = atoi(r2_s);
                int c2 = atoi(c2_s);
                int x1 = 0;
                int y1 = 0;
                int steps = steps_s ? atoi(steps_s) : 8;

                if (grid_cell_rect_px(disp, r1, c1, &rc1) == 0 &&
                    grid_cell_rect_px(disp, r2, c2, &rc2) == 0 &&
                    cell_anchor_point_px(&rc1, edge_s, &x1, &y1) == 0) {
                    drag_internal_points(
                        disp,
                        x1,
                        y1,
                        (rc2.left + rc2.right) / 2,
                        (rc2.top + rc2.bottom) / 2,
                        steps);
                }
            }
            continue;
        }

        if (_stricmp(cmd, "key") == 0) {
            char *tok = strtok(NULL, " \t");
            int vk = parse_vk_token(tok);
            if (vk) {
                if (hg->dispatch_only) {
                    if (vk == VK_F4) {
                        int r = get_int(disp, L"Row", 0);
                        int c = get_int(disp, L"Col", 0);
                        call_method2_i4(disp, L"EditCell", r, c);
                        pump_messages_ms(120);
                    }
                } else {
                    send_key_to_control(hg, vk);
                }
            }
            continue;
        }
    }

    fclose(f);
}

static int has_ux_actions(int test_no, const char *test_name) {
    char path[320];
    snprintf(path, sizeof(path), "tests/%02d_%s.ux", test_no, test_name);
    return file_exists(path);
}

static int is_event_test_name(const char *name) {
    return name && strncmp(name, "event_", 6) == 0;
}

static void configure_event_probe_for_test(EventProbe *probe, const char *name) {
    (void)probe;
    (void)name;
}

static int event_expect_min(
    const EventProbe *probe, EventId id, int min_count, const char *label, int *ok)
{
    int count = event_probe_count(probe, id);
    if (!event_probe_has_event(probe, id)) {
        printf("  ASSERT FAIL: %s is not exposed by the source interface\n", label);
        *ok = 0;
        return count;
    }
    if (count < min_count) {
        printf("  ASSERT FAIL: %s count=%d expected >= %d\n", label, count, min_count);
        *ok = 0;
    }
    return count;
}

static int event_expect_eq(
    const EventProbe *probe, EventId id, int exact_count, const char *label, int *ok)
{
    int count = event_probe_count(probe, id);
    if (!event_probe_has_event(probe, id)) {
        printf("  ASSERT FAIL: %s is not exposed by the source interface\n", label);
        *ok = 0;
        return count;
    }
    if (count != exact_count) {
        printf("  ASSERT FAIL: %s count=%d expected %d\n", label, count, exact_count);
        *ok = 0;
    }
    return count;
}

static int evaluate_event_test(const HostedGrid *hg, IDispatch *disp, int test_no, const char *name) {
    int ok = 1;
    EventProbe *probe;

    (void)test_no;
    if (!hg || !disp || !name || !is_event_test_name(name)) return 1;
    probe = hg->event_probe;
    if (!probe) {
        printf("  ASSERT FAIL: missing event probe\n");
        return 0;
    }

    if (strcmp(name, "event_rowcolchange") == 0) {
        int row = get_int(disp, L"Row", -1);
        int col = get_int(disp, L"Col", -1);
        event_expect_min(probe, EVT_BEFORE_ROW_COL_CHANGE, 2, "BeforeRowColChange", &ok);
        event_expect_eq(probe, EVT_AFTER_ROW_COL_CHANGE, 1, "AfterRowColChange", &ok);
        if (row != 2 || col != 1) {
            printf("  ASSERT FAIL: final cell=%d,%d expected 2,1\n", row, col);
            ok = 0;
        }
    } else if (strcmp(name, "event_selchange") == 0) {
        int row = get_int(disp, L"Row", -1);
        int col = get_int(disp, L"Col", -1);
        int row_sel = get_int(disp, L"RowSel", -1);
        int col_sel = get_int(disp, L"ColSel", -1);
        event_expect_min(probe, EVT_BEFORE_SEL_CHANGE, 2, "BeforeSelChange", &ok);
        event_expect_eq(probe, EVT_AFTER_SEL_CHANGE, 1, "AfterSelChange", &ok);
        if (row != 1 || col != 1 || row_sel != 2 || col_sel != 1) {
            printf(
                "  ASSERT FAIL: cursor=%d,%d sel=%d,%d expected cursor 1,1 sel 2,1\n",
                row, col, row_sel, col_sel);
            ok = 0;
        }
    } else if (strcmp(name, "event_edit") == 0) {
        event_expect_min(probe, EVT_BEFORE_EDIT, 2, "BeforeEdit", &ok);
        event_expect_eq(probe, EVT_AFTER_EDIT, 1, "AfterEdit", &ok);
    } else if (strcmp(name, "event_sort") == 0) {
        char *cell = get_text_matrix_utf8_alloc(disp, 1, 1);
        event_expect_min(probe, EVT_BEFORE_SORT, 2, "BeforeSort", &ok);
        event_expect_min(probe, EVT_AFTER_SORT, 2, "AfterSort", &ok);
        if (!cell || strcmp(cell, "C") != 0) {
            printf("  ASSERT FAIL: first sorted value=%s expected C\n", cell ? cell : "(null)");
            ok = 0;
        }
        free(cell);
    } else if (strcmp(name, "event_collapse") == 0) {
        event_expect_min(probe, EVT_BEFORE_COLLAPSE, 2, "BeforeCollapse", &ok);
        event_expect_eq(probe, EVT_AFTER_COLLAPSE, 1, "AfterCollapse", &ok);
    } else if (strcmp(name, "event_scroll") == 0) {
        int top = get_int(disp, L"TopRow", -1);
        event_expect_min(probe, EVT_BEFORE_SCROLL, 2, "BeforeScroll", &ok);
        event_expect_eq(probe, EVT_AFTER_SCROLL, 1, "AfterScroll", &ok);
        if (top != 4) {
            printf("  ASSERT FAIL: TopRow=%d expected 4\n", top);
            ok = 0;
        }
    } else if (strcmp(name, "event_scroll_tip") == 0) {
        char *tip = get_bstr_prop_utf8_alloc(disp, L"ScrollTipText");
        event_expect_min(probe, EVT_BEFORE_SCROLL_TIP, 1, "BeforeScrollTip", &ok);
        if (!tip || !*tip) {
            printf("  ASSERT FAIL: ScrollTipText is empty\n");
            ok = 0;
        }
        free(tip);
    } else if (strcmp(name, "event_user_resize") == 0) {
        event_expect_min(probe, EVT_BEFORE_USER_RESIZE, 2, "BeforeUserResize", &ok);
        event_expect_eq(probe, EVT_AFTER_USER_RESIZE, 1, "AfterUserResize", &ok);
    } else if (strcmp(name, "event_user_freeze") == 0) {
        int frozen_cols = get_int(disp, L"FrozenCols", -1);
        event_expect_min(probe, EVT_AFTER_USER_FREEZE, 1, "AfterUserFreeze", &ok);
        if (frozen_cols != 2) {
            printf("  ASSERT FAIL: FrozenCols=%d expected 2\n", frozen_cols);
            ok = 0;
        }
    } else if (strcmp(name, "event_move_column") == 0) {
        int pos = get_indexed_int(disp, L"ColPosition", 2, -1);
        event_expect_min(probe, EVT_BEFORE_MOVE_COLUMN, 2, "BeforeMoveColumn", &ok);
        event_expect_min(probe, EVT_AFTER_MOVE_COLUMN, 2, "AfterMoveColumn", &ok);
        if (pos != 0) {
            printf("  ASSERT FAIL: ColPosition(2)=%d expected 0\n", pos);
            ok = 0;
        }
    } else if (strcmp(name, "event_move_row") == 0) {
        int pos = get_indexed_int(disp, L"RowPosition", 4, -1);
        event_expect_min(probe, EVT_BEFORE_MOVE_ROW, 2, "BeforeMoveRow", &ok);
        event_expect_min(probe, EVT_AFTER_MOVE_ROW, 2, "AfterMoveRow", &ok);
        if (pos != 1) {
            printf("  ASSERT FAIL: RowPosition(4)=%d expected 1\n", pos);
            ok = 0;
        }
    } else if (strcmp(name, "event_mouse_down") == 0) {
        int row = get_int(disp, L"Row", -1);
        int col = get_int(disp, L"Col", -1);
        event_expect_min(probe, EVT_BEFORE_MOUSE_DOWN, 2, "BeforeMouseDown", &ok);
        if (row != 3 || col != 1) {
            printf("  ASSERT FAIL: final cell=%d,%d expected 3,1\n", row, col);
            ok = 0;
        }
    } else if (strcmp(name, "event_data_refresh") == 0) {
        char *cell0 = get_text_matrix_utf8_alloc(disp, 0, 0);
        if (cell0 && strcmp(cell0, "ERR") == 0) {
            char *err_code = get_text_matrix_utf8_alloc(disp, 0, 1);
            char *err_desc = get_text_matrix_utf8_alloc(disp, 1, 1);
            printf("  ASSERT SKIP: ADO unavailable in this environment\n");
            if (err_code || err_desc) {
                printf(
                    "  ADO detail: code=%s desc=%s\n",
                    err_code ? err_code : "(null)",
                    err_desc ? err_desc : "(null)");
            }
            free(err_code);
            free(err_desc);
            free(cell0);
            return 1;
        }
        free(cell0);
        event_expect_min(probe, EVT_BEFORE_DATA_REFRESH, 2, "BeforeDataRefresh", &ok);
        event_expect_eq(probe, EVT_AFTER_DATA_REFRESH, 1, "AfterDataRefresh", &ok);
    } else if (strcmp(name, "event_page_break") == 0) {
        event_expect_min(probe, EVT_BEFORE_PAGE_BREAK, 1, "BeforePageBreak", &ok);
    }

    if (ok) {
        printf("  ASSERT PASS: %s\n", name);
    }
    return ok;
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
    int only_test = 0;
    char test_filter[256] = {0};
    int pass = 0, fail = 0, compared = 0;
    double total_similarity = 0.0;
    int i;

    /* Keep tests non-interactive/silent on faults in CI/Wine runs. */
    SetErrorMode(SEM_FAILCRITICALERRORS | SEM_NOGPFAULTERRORBOX | SEM_NOOPENFILEERRORBOX);

    for (i = 1; i < argc; i++) {
        if (strcmp(argv[i], "--only-vv") == 0) only_vv = 1;
        else if (strcmp(argv[i], "--no-diff") == 0) skip_diff = 1;
        else if (strcmp(argv[i], "--test") == 0 && i + 1 < argc) only_test = atoi(argv[++i]);
        else if (strcmp(argv[i], "--tests") == 0 && i + 1 < argc) {
            snprintf(test_filter, sizeof(test_filter), "%s", argv[++i]);
        }
        else if ((strcmp(argv[i], "--ref-progid") == 0 || strcmp(argv[i], "--legacy-progid") == 0) && i + 1 < argc) {
            i++;
            MultiByteToWideChar(CP_ACP, 0, argv[i], -1, g_ref_progid, 256);
        }
    }

    if (!g_ref_progid[0]) only_vv = 1;

    printf("=== FlexGrid vs VolvoxGrid — UI+UX Interaction Comparison ===\n");
    printf("    %d test scenarios\n\n", (int)(sizeof(g_tests)/sizeof(g_tests[0])) - 1);

    {
        HRESULT hr = CoInitializeEx(NULL, COINIT_APARTMENTTHREADED);
        if (FAILED(hr)) {
            printf("CoInitializeEx failed: 0x%08lx\n", hr);
            return 1;
        }
    }

    for (i = 0; g_tests[i].name; i++) {
        TestCase *tc = &g_tests[i];
        char bmp_lg[128], bmp_vv[128], bmp_diff[128], vbs_path[256], script_out[256];
        WCHAR *vbs_code;
        WCHAR *full_vbs;
        int has_lg = 0;

        if (!test_selected(i + 1, only_test, test_filter)) {
            continue;
        }

        snprintf(bmp_lg, sizeof(bmp_lg), "test_%02d_%s_lg.bmp", i + 1, tc->name);
        snprintf(bmp_vv, sizeof(bmp_vv), "test_%02d_%s_vv.bmp", i + 1, tc->name);
        snprintf(bmp_diff, sizeof(bmp_diff), "test_%02d_%s_diff.bmp", i + 1, tc->name);

        printf("[%02d] %s\n", i + 1, tc->name);

        snprintf(vbs_path, sizeof(vbs_path), "tests/%02d_%s.vbs", i + 1, tc->name);
        vbs_code = load_file_wide(vbs_path);
        if (!vbs_code) {
            printf("  SKIP: cannot load %s\n", vbs_path);
            fail++;
            continue;
        }

        snprintf(script_out, sizeof(script_out), "test_%02d_%s_script.vbs", i + 1, tc->name);
        full_vbs = build_full_vbs(vbs_code);
        if (full_vbs) {
            if (save_utf8_from_wide(script_out, full_vbs) != 0) {
                printf("  WARN: cannot save %s\n", script_out);
            }
            free(full_vbs);
        } else {
            printf("  WARN: cannot build full script for %s\n", script_out);
        }

        if (!only_vv) {
            HostedGrid lg;
            if (hosted_grid_create(&lg, g_ref_progid, L"FlexGrid Host", tc->width, tc->height, 0) == 0) {
                ScriptRuntime lg_script;
                start_vbs_runtime(&lg_script, &lg, vbs_code);
                pump_messages_ms(120);
                apply_ux_actions(&lg, lg.disp, i + 1, tc->name);
                pump_messages_ms(120);
                if (has_ux_actions(i + 1, tc->name)) {
                    dump_top_row_snapshot(lg.disp, "LG", i + 1);
                    dump_event_probe_snapshot(lg.event_probe, "LG", i + 1);
                }
                if (!lg.dispatch_only) {
                    render_to_bmp_with_popup(lg.disp, &lg, bmp_lg, lg.render_width, lg.render_height);
                } else {
                    render_to_bmp(lg.disp, bmp_lg, lg.render_width, lg.render_height);
                }
                close_script_runtime(&lg_script);
                hosted_grid_destroy(&lg);
                has_lg = 1;
            } else {
                printf("  LG: host/create failed\n");
            }
        }

        {
            HostedGrid vv;
            if (hosted_grid_create(&vv, PROGID_VOLVOXGRID, L"VolvoxGrid Host", tc->width, tc->height, 80) == 0) {
                ScriptRuntime vv_script;
                int vv_ok = 1;
                start_vbs_runtime(&vv_script, &vv, vbs_code);
                pump_messages_ms(120);
                event_probe_reset(vv.event_probe);
                configure_event_probe_for_test(vv.event_probe, tc->name);
                apply_ux_actions(&vv, vv.disp, i + 1, tc->name);
                pump_messages_ms(120);
                if (has_ux_actions(i + 1, tc->name)) {
                    dump_top_row_snapshot(vv.disp, "VV", i + 1);
                    dump_event_probe_snapshot(vv.event_probe, "VV", i + 1);
                }
                if (is_event_test_name(tc->name)) {
                    vv_ok = evaluate_event_test(&vv, vv.disp, i + 1, tc->name);
                }
                if (!vv.dispatch_only) {
                    render_to_bmp_with_popup(vv.disp, &vv, bmp_vv, vv.render_width, vv.render_height);
                } else {
                    render_to_bmp(vv.disp, bmp_vv, vv.render_width, vv.render_height);
                }
                close_script_runtime(&vv_script);
                hosted_grid_destroy(&vv);
                if (vv_ok) {
                    pass++;
                } else {
                    fail++;
                }

                if (has_lg && !skip_diff) {
                    double sim = compare_bmps(bmp_lg, bmp_vv, bmp_diff);
                    if (sim >= 0) {
                        printf("  Similarity: %.1f%%  -> %s\n", sim, bmp_diff);
                        total_similarity += sim;
                        compared++;
                    }
                }
            } else {
                printf("  VV: host/create failed\n");
                fail++;
            }
        }

        free(vbs_code);
    }

    CoUninitialize();

    printf("\n");
    printf("══════════════════════════════════════════════════\n");
    printf("  Results: %d rendered, %d failed\n", pass, fail);
    if (compared > 0) {
        printf("  Compared: %d pairs, avg similarity: %.1f%%\n", compared, total_similarity / compared);
    }
    printf("══════════════════════════════════════════════════\n");

    return (fail == 0) ? 0 : 1;
}
