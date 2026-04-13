/* activex_demo_host.c -- Old-Windows-style VolvoxGrid ActiveX demo host.
 *
 * The VolvoxGrid OCX is still a dispatch-driven control, so this shell uses
 * IDispatch for configuration/input forwarding and IViewObject::Draw for paint.
 * The surrounding UI mirrors the .NET demo layout: demo switchers, sort
 * buttons, runtime toggles, selection chooser, and a live status bar.
 */

#define WIN32_LEAN_AND_MEAN
#define COBJMACROS

#include <windows.h>
#include <windowsx.h>
#include <imm.h>
#include <ole2.h>
#include <oleauto.h>
#include <olectl.h>
#include <stdint.h>
#include <stdarg.h>
#include <stdio.h>
#include <string.h>

#define ID_BTN_SALES            1001
#define ID_BTN_HIERARCHY        1002
#define ID_BTN_STRESS           1003
#define ID_BTN_SORT_UP          1004
#define ID_BTN_SORT_DOWN        1005
#define ID_CHK_EDITABLE         1006
#define ID_CHK_HOVER            1007
#define ID_CHK_DEBUG            1008
#define ID_CHK_SCROLL_BLIT      1009
#define ID_BTN_SELECTION        1010

#define ID_MENU_SELECTION_FREE       1101
#define ID_MENU_SELECTION_BY_ROW     1102
#define ID_MENU_SELECTION_BY_COLUMN  1103
#define ID_MENU_SELECTION_LISTBOX    1104

#define WINDOW_WIDTH            1200
#define WINDOW_HEIGHT            800
#define TOOLBAR_HEIGHT            44
#define STATUS_HEIGHT             28
#define MARGIN                     8
#define CONTROL_HEIGHT            28
#define CHECKBOX_HEIGHT           22
#define DEMO_BUTTON_WIDTH        110
#define SORT_BUTTON_WIDTH         40
#define SELECTION_BUTTON_WIDTH   120

static const WCHAR MAIN_WND_CLASS[] = L"VolvoxGridActiveXDemoMain";
static const WCHAR VIEW_WND_CLASS[] = L"VolvoxGridActiveXDemoView";
static const WCHAR OCX_PROGID[] = L"VolvoxGrid.VolvoxGridCtrl";

typedef struct DemoApp {
    HWND hwnd_main;
    HWND hwnd_view;
    HWND hwnd_status;
    HWND hwnd_btn_sales;
    HWND hwnd_btn_hierarchy;
    HWND hwnd_btn_stress;
    HWND hwnd_btn_sort_up;
    HWND hwnd_btn_sort_down;
    HWND hwnd_chk_editable;
    HWND hwnd_chk_hover;
    HWND hwnd_chk_debug;
    HWND hwnd_chk_scroll_blit;
    HWND hwnd_label_selection;
    HWND hwnd_btn_selection;
    HMENU selection_menu;
    IDispatch *grid;
    WCHAR current_demo[16];
    int selection_mode;
    BOOL editable;
    BOOL hover_enabled;
    BOOL debug_overlay;
    BOOL scroll_blit_enabled;
    WCHAR initial_font_name[128];
} DemoApp;

static void copy_wstr(WCHAR *dst, size_t cap, const WCHAR *src) {
    if (!dst || cap == 0) return;
    lstrcpynW(dst, src ? src : L"", (int)cap);
}

static const WCHAR *normalize_demo_name(const WCHAR *demo) {
    if (demo) {
        if (_wcsicmp(demo, L"hierarchy") == 0) return L"hierarchy";
        if (_wcsicmp(demo, L"stress") == 0) return L"stress";
    }
    return L"sales";
}

static const WCHAR *demo_title(const WCHAR *demo) {
    if (_wcsicmp(demo, L"hierarchy") == 0) return L"Hierarchy";
    if (_wcsicmp(demo, L"stress") == 0) return L"Stress";
    return L"Sales";
}

static UINT demo_hover_mode(const WCHAR *demo) {
    if (_wcsicmp(demo, L"hierarchy") == 0) return 4; /* HOVER_CELL */
    if (_wcsicmp(demo, L"stress") == 0) return 1;    /* HOVER_ROW */
    return 7; /* HOVER_ROW | HOVER_COLUMN | HOVER_CELL */
}

static const WCHAR *selection_mode_title(int mode) {
    switch (mode) {
    case 1: return L"By Row";
    case 2: return L"By Column";
    case 3: return L"Listbox";
    default: return L"Free";
    }
}

static void set_statusf(DemoApp *app, const WCHAR *fmt, ...) {
    WCHAR buf[256];
    va_list args;
    if (!app || !app->hwnd_status || !fmt) return;
    va_start(args, fmt);
    _vsnwprintf(buf, (sizeof(buf) / sizeof(buf[0])) - 1, fmt, args);
    va_end(args);
    buf[(sizeof(buf) / sizeof(buf[0])) - 1] = L'\0';
    SetWindowTextW(app->hwnd_status, buf);
}

static HRESULT get_dispid(IDispatch *disp, LPCOLESTR name, DISPID *out) {
    LPOLESTR names[1];
    if (!disp || !name || !out) return E_POINTER;
    names[0] = (LPOLESTR)name;
    return disp->lpVtbl->GetIDsOfNames(disp, &IID_NULL, names, 1, LOCALE_USER_DEFAULT, out);
}

static HRESULT variant_to_i4(VARIANT *pv, LONG *out) {
    VARIANT tmp;
    HRESULT hr;
    if (!pv || !out) return E_POINTER;
    if (V_VT(pv) == VT_I4) {
        *out = V_I4(pv);
        return S_OK;
    }
    VariantInit(&tmp);
    hr = VariantChangeType(&tmp, pv, 0, VT_I4);
    if (SUCCEEDED(hr)) {
        *out = V_I4(&tmp);
    }
    VariantClear(&tmp);
    return hr;
}

static HRESULT get_i4_property(IDispatch *disp, LPCOLESTR name, LONG *out) {
    DISPID dispid;
    DISPPARAMS dp;
    VARIANT result;
    HRESULT hr;

    if (!disp || !name || !out) return E_POINTER;
    hr = get_dispid(disp, name, &dispid);
    if (FAILED(hr)) return hr;

    VariantInit(&result);
    dp.rgvarg = NULL;
    dp.rgdispidNamedArgs = NULL;
    dp.cArgs = 0;
    dp.cNamedArgs = 0;

    hr = disp->lpVtbl->Invoke(
        disp,
        dispid,
        &IID_NULL,
        LOCALE_USER_DEFAULT,
        DISPATCH_PROPERTYGET,
        &dp,
        &result,
        NULL,
        NULL);
    if (SUCCEEDED(hr)) {
        hr = variant_to_i4(&result, out);
    }
    VariantClear(&result);
    return hr;
}

static HRESULT put_i4_property(IDispatch *disp, LPCOLESTR name, LONG value) {
    DISPID dispid;
    DISPID putid = DISPID_PROPERTYPUT;
    VARIANT arg;
    DISPPARAMS dp;
    HRESULT hr;

    hr = get_dispid(disp, name, &dispid);
    if (FAILED(hr)) return hr;

    VariantInit(&arg);
    V_VT(&arg) = VT_I4;
    V_I4(&arg) = value;
    dp.rgvarg = &arg;
    dp.rgdispidNamedArgs = &putid;
    dp.cArgs = 1;
    dp.cNamedArgs = 1;
    return disp->lpVtbl->Invoke(
        disp,
        dispid,
        &IID_NULL,
        LOCALE_USER_DEFAULT,
        DISPATCH_PROPERTYPUT,
        &dp,
        NULL,
        NULL,
        NULL);
}

static HRESULT put_bstr_property(IDispatch *disp, LPCOLESTR name, LPCWSTR value) {
    DISPID dispid;
    DISPID putid = DISPID_PROPERTYPUT;
    VARIANT arg;
    DISPPARAMS dp;
    HRESULT hr;

    hr = get_dispid(disp, name, &dispid);
    if (FAILED(hr)) return hr;

    VariantInit(&arg);
    V_VT(&arg) = VT_BSTR;
    V_BSTR(&arg) = SysAllocString(value ? value : L"");
    if (!V_BSTR(&arg)) return E_OUTOFMEMORY;
    dp.rgvarg = &arg;
    dp.rgdispidNamedArgs = &putid;
    dp.cArgs = 1;
    dp.cNamedArgs = 1;
    hr = disp->lpVtbl->Invoke(
        disp,
        dispid,
        &IID_NULL,
        LOCALE_USER_DEFAULT,
        DISPATCH_PROPERTYPUT,
        &dp,
        NULL,
        NULL,
        NULL);
    VariantClear(&arg);
    return hr;
}

static HRESULT invoke_method_variants(IDispatch *disp, LPCOLESTR name, VARIANT *args, UINT argc) {
    DISPID dispid;
    DISPPARAMS dp;
    HRESULT hr;

    hr = get_dispid(disp, name, &dispid);
    if (FAILED(hr)) return hr;

    dp.rgvarg = args;
    dp.rgdispidNamedArgs = NULL;
    dp.cArgs = argc;
    dp.cNamedArgs = 0;
    return disp->lpVtbl->Invoke(
        disp,
        dispid,
        &IID_NULL,
        LOCALE_USER_DEFAULT,
        DISPATCH_METHOD,
        &dp,
        NULL,
        NULL,
        NULL);
}

static HRESULT invoke_method0(IDispatch *disp, LPCOLESTR name) {
    return invoke_method_variants(disp, name, NULL, 0);
}

static HRESULT invoke_method_bstr(IDispatch *disp, LPCOLESTR name, LPCWSTR value) {
    VARIANT arg;
    HRESULT hr;
    VariantInit(&arg);
    V_VT(&arg) = VT_BSTR;
    V_BSTR(&arg) = SysAllocString(value ? value : L"");
    if (!V_BSTR(&arg)) return E_OUTOFMEMORY;
    hr = invoke_method_variants(disp, name, &arg, 1);
    VariantClear(&arg);
    return hr;
}

static HRESULT invoke_method_i4_1(IDispatch *disp, LPCOLESTR name, LONG a0) {
    VARIANT args[1];
    VariantInit(&args[0]);
    V_VT(&args[0]) = VT_I4;
    V_I4(&args[0]) = a0;
    return invoke_method_variants(disp, name, args, 1);
}

static HRESULT invoke_method_i4_2(IDispatch *disp, LPCOLESTR name, LONG a0, LONG a1) {
    VARIANT args[2];
    VariantInit(&args[0]);
    VariantInit(&args[1]);
    V_VT(&args[1]) = VT_I4;
    V_I4(&args[1]) = a0;
    V_VT(&args[0]) = VT_I4;
    V_I4(&args[0]) = a1;
    return invoke_method_variants(disp, name, args, 2);
}

static HRESULT invoke_method_bstr_i4_i4(IDispatch *disp, LPCOLESTR name, BSTR text, LONG cursor, LONG commit) {
    VARIANT args[3];
    HRESULT hr;
    VariantInit(&args[0]);
    VariantInit(&args[1]);
    VariantInit(&args[2]);
    V_VT(&args[2]) = VT_BSTR;
    V_BSTR(&args[2]) = SysAllocStringLen(text ? text : L"", text ? SysStringLen(text) : 0);
    if (!V_BSTR(&args[2])) return E_OUTOFMEMORY;
    V_VT(&args[1]) = VT_I4;
    V_I4(&args[1]) = cursor;
    V_VT(&args[0]) = VT_I4;
    V_I4(&args[0]) = commit;
    hr = invoke_method_variants(disp, name, args, 3);
    VariantClear(&args[2]);
    return hr;
}

static HRESULT invoke_method_i4_4(
    IDispatch *disp,
    LPCOLESTR name,
    LONG a0,
    LONG a1,
    LONG a2,
    LONG a3)
{
    VARIANT args[4];
    VariantInit(&args[0]);
    VariantInit(&args[1]);
    VariantInit(&args[2]);
    VariantInit(&args[3]);
    V_VT(&args[3]) = VT_I4;
    V_I4(&args[3]) = a0;
    V_VT(&args[2]) = VT_I4;
    V_I4(&args[2]) = a1;
    V_VT(&args[1]) = VT_I4;
    V_I4(&args[1]) = a2;
    V_VT(&args[0]) = VT_I4;
    V_I4(&args[0]) = a3;
    return invoke_method_variants(disp, name, args, 4);
}

static HRESULT invoke_method_i4_5(
    IDispatch *disp,
    LPCOLESTR name,
    LONG a0,
    LONG a1,
    LONG a2,
    LONG a3,
    LONG a4)
{
    VARIANT args[5];
    VariantInit(&args[0]);
    VariantInit(&args[1]);
    VariantInit(&args[2]);
    VariantInit(&args[3]);
    VariantInit(&args[4]);
    V_VT(&args[4]) = VT_I4;
    V_I4(&args[4]) = a0;
    V_VT(&args[3]) = VT_I4;
    V_I4(&args[3]) = a1;
    V_VT(&args[2]) = VT_I4;
    V_I4(&args[2]) = a2;
    V_VT(&args[1]) = VT_I4;
    V_I4(&args[1]) = a3;
    V_VT(&args[0]) = VT_I4;
    V_I4(&args[0]) = a4;
    return invoke_method_variants(disp, name, args, 5);
}

static HRESULT invoke_method_r4_2(IDispatch *disp, LPCOLESTR name, float a0, float a1) {
    VARIANT args[2];
    VariantInit(&args[0]);
    VariantInit(&args[1]);
    V_VT(&args[1]) = VT_R4;
    V_R4(&args[1]) = a0;
    V_VT(&args[0]) = VT_R4;
    V_R4(&args[0]) = a1;
    return invoke_method_variants(disp, name, args, 2);
}

static BOOL is_checked(HWND hwnd) {
    return SendMessageW(hwnd, BM_GETCHECK, 0, 0) == BST_CHECKED;
}

static void set_checked(HWND hwnd, BOOL checked) {
    SendMessageW(hwnd, BM_SETCHECK, checked ? BST_CHECKED : BST_UNCHECKED, 0);
}

static HRESULT create_grid_object(DemoApp *app) {
    CLSID clsid;
    if (!app) return E_POINTER;
    if (app->grid) return S_OK;
    if (FAILED(CLSIDFromProgID(OCX_PROGID, &clsid))) {
        return REGDB_E_CLASSNOTREG;
    }
    return CoCreateInstance(
        &clsid,
        NULL,
        CLSCTX_INPROC_SERVER,
        &IID_IDispatch,
        (void **)&app->grid);
}

static void destroy_grid_object(DemoApp *app) {
    if (!app || !app->grid) return;
    app->grid->lpVtbl->Release(app->grid);
    app->grid = NULL;
}

static void update_demo_button_styles(DemoApp *app) {
    if (!app) return;
    SendMessageW(
        app->hwnd_btn_sales,
        BM_SETSTYLE,
        (WPARAM)(_wcsicmp(app->current_demo, L"sales") == 0 ? BS_DEFPUSHBUTTON : BS_PUSHBUTTON),
        TRUE);
    SendMessageW(
        app->hwnd_btn_hierarchy,
        BM_SETSTYLE,
        (WPARAM)(_wcsicmp(app->current_demo, L"hierarchy") == 0 ? BS_DEFPUSHBUTTON : BS_PUSHBUTTON),
        TRUE);
    SendMessageW(
        app->hwnd_btn_stress,
        BM_SETSTYLE,
        (WPARAM)(_wcsicmp(app->current_demo, L"stress") == 0 ? BS_DEFPUSHBUTTON : BS_PUSHBUTTON),
        TRUE);
}

static void update_selection_ui(DemoApp *app) {
    if (!app) return;
    if (app->selection_menu) {
        CheckMenuRadioItem(
            app->selection_menu,
            ID_MENU_SELECTION_FREE,
            ID_MENU_SELECTION_LISTBOX,
            ID_MENU_SELECTION_FREE + app->selection_mode,
            MF_BYCOMMAND);
    }
    if (app->hwnd_btn_selection) {
        SetWindowTextW(app->hwnd_btn_selection, selection_mode_title(app->selection_mode));
    }
}

static HRESULT sync_viewport(DemoApp *app) {
    RECT rc;
    if (!app || !app->grid || !app->hwnd_view) return E_POINTER;
    GetClientRect(app->hwnd_view, &rc);
    if (rc.right <= rc.left || rc.bottom <= rc.top) return S_OK;
    return invoke_method_i4_2(app->grid, L"ResizeViewport", rc.right - rc.left, rc.bottom - rc.top);
}

static HRESULT sync_editable(DemoApp *app) {
    if (!app || !app->grid) return E_POINTER;
    return put_i4_property(app->grid, L"Editable", app->editable ? 2 : 0);
}

static HRESULT sync_selection_mode(DemoApp *app) {
    if (!app || !app->grid) return E_POINTER;
    return put_i4_property(app->grid, L"SelectionMode", app->selection_mode);
}

static HRESULT sync_hover(DemoApp *app) {
    LONG mode;
    if (!app || !app->grid) return E_POINTER;
    mode = app->hover_enabled ? (LONG)demo_hover_mode(app->current_demo) : 0;
    return invoke_method_i4_1(app->grid, L"SetHoverMode", mode);
}

static HRESULT sync_debug_overlay(DemoApp *app) {
    if (!app || !app->grid) return E_POINTER;
    return invoke_method_i4_1(app->grid, L"SetDebugOverlay", app->debug_overlay ? 1 : 0);
}

static HRESULT sync_scroll_blit(DemoApp *app) {
    if (!app || !app->grid) return E_POINTER;
    return invoke_method_i4_1(app->grid, L"SetScrollBlit", app->scroll_blit_enabled ? 1 : 0);
}

static HRESULT sync_font_name(DemoApp *app) {
    if (!app || !app->grid) return E_POINTER;
    if (!app->initial_font_name[0]) return S_OK;
    return put_bstr_property(app->grid, L"FontName", app->initial_font_name);
}

static HRESULT apply_runtime_options(DemoApp *app) {
    HRESULT hr;
    hr = sync_font_name(app);
    if (FAILED(hr)) return hr;
    hr = sync_editable(app);
    if (FAILED(hr)) return hr;
    hr = sync_selection_mode(app);
    if (FAILED(hr)) return hr;
    hr = sync_hover(app);
    if (FAILED(hr)) return hr;
    hr = sync_debug_overlay(app);
    if (FAILED(hr)) return hr;
    hr = sync_scroll_blit(app);
    if (FAILED(hr)) return hr;
    return invoke_method0(app->grid, L"Refresh");
}

static void invalidate_view(DemoApp *app) {
    if (!app || !app->hwnd_view) return;
    InvalidateRect(app->hwnd_view, NULL, FALSE);
}

static void set_focus_status(DemoApp *app, const WCHAR *prefix) {
    LONG row = 0;
    LONG col = 0;
    if (!app || !app->grid) return;
    if (SUCCEEDED(get_i4_property(app->grid, L"Row", &row)) &&
        SUCCEEDED(get_i4_property(app->grid, L"Col", &col))) {
        if (prefix && *prefix) {
            set_statusf(app, L"%ls Focus: row %ld, col %ld.", prefix, row, col);
        } else {
            set_statusf(app, L"Focus: row %ld, col %ld.", row, col);
        }
    } else if (prefix && *prefix) {
        set_statusf(app, L"%ls", prefix);
    }
}

static BOOL switch_demo(DemoApp *app, const WCHAR *demo) {
    const WCHAR *normalized = normalize_demo_name(demo);
    HRESULT hr;

    if (!app || !app->grid) return FALSE;

    hr = invoke_method_bstr(app->grid, L"LoadDemo", normalized);
    if (FAILED(hr)) {
        set_statusf(app, L"LoadDemo(%ls) failed: 0x%08lx", normalized, (unsigned long)hr);
        return FALSE;
    }

    copy_wstr(app->current_demo, sizeof(app->current_demo) / sizeof(app->current_demo[0]), normalized);
    update_demo_button_styles(app);
    update_selection_ui(app);

    hr = sync_viewport(app);
    if (FAILED(hr)) {
        set_statusf(app, L"ResizeViewport failed: 0x%08lx", (unsigned long)hr);
        return FALSE;
    }

    hr = apply_runtime_options(app);
    if (FAILED(hr)) {
        set_statusf(app, L"Runtime option sync failed: 0x%08lx", (unsigned long)hr);
        return FALSE;
    }

    invalidate_view(app);
    set_statusf(app, L"Loaded raw engine demo: %ls.", demo_title(normalized));
    return TRUE;
}

static HRESULT draw_grid_to_dc(DemoApp *app, HDC hdc, const RECT *rc) {
    IViewObject *view = NULL;
    RECTL bounds;
    HRESULT hr;

    if (!app || !app->grid || !hdc || !rc) return E_POINTER;

    hr = app->grid->lpVtbl->QueryInterface(app->grid, &IID_IViewObject, (void **)&view);
    if (FAILED(hr) || !view) return FAILED(hr) ? hr : E_NOINTERFACE;

    bounds.left = 0;
    bounds.top = 0;
    bounds.right = rc->right - rc->left;
    bounds.bottom = rc->bottom - rc->top;
    hr = view->lpVtbl->Draw(
        view,
        DVASPECT_CONTENT,
        -1,
        NULL,
        NULL,
        NULL,
        hdc,
        &bounds,
        NULL,
        NULL,
        0);
    view->lpVtbl->Release(view);
    return hr;
}

static void paint_view_window(DemoApp *app, HWND hwnd) {
    PAINTSTRUCT ps;
    RECT rc;
    HDC hdc = BeginPaint(hwnd, &ps);
    HDC memdc = NULL;
    HBITMAP membmp = NULL;
    HBITMAP oldbmp = NULL;
    HBRUSH bg = CreateSolidBrush(GetSysColor(COLOR_WINDOW));
    HRESULT hr = E_FAIL;
    int width;
    int height;

    GetClientRect(hwnd, &rc);
    width = rc.right - rc.left;
    height = rc.bottom - rc.top;

    if (width > 0 && height > 0) {
        memdc = CreateCompatibleDC(hdc);
        membmp = CreateCompatibleBitmap(hdc, width, height);
        if (memdc && membmp) {
            oldbmp = (HBITMAP)SelectObject(memdc, membmp);
            FillRect(memdc, &rc, bg);
        }
    }

    if (memdc && membmp) {
        if (app && app->grid) {
            hr = draw_grid_to_dc(app, memdc, &rc);
        }

        if (!app || !app->grid || FAILED(hr)) {
            RECT text_rc = rc;
            SetBkMode(memdc, TRANSPARENT);
            SetTextColor(memdc, GetSysColor(COLOR_WINDOWTEXT));
            DrawTextW(
                memdc,
                app && app->grid
                    ? L"VolvoxGrid.ocx could not render this frame."
                    : L"VolvoxGrid.ocx is not available. Register the OCX and relaunch.",
                -1,
                &text_rc,
                DT_CENTER | DT_VCENTER | DT_SINGLELINE);
        }

        BitBlt(hdc, 0, 0, width, height, memdc, 0, 0, SRCCOPY);
    } else {
        FillRect(hdc, &rc, bg);
        if (app && app->grid) {
            hr = draw_grid_to_dc(app, hdc, &rc);
        }
        if (!app || !app->grid || FAILED(hr)) {
            RECT text_rc = rc;
            SetBkMode(hdc, TRANSPARENT);
            SetTextColor(hdc, GetSysColor(COLOR_WINDOWTEXT));
            DrawTextW(
                hdc,
                app && app->grid
                    ? L"VolvoxGrid.ocx could not render this frame."
                    : L"VolvoxGrid.ocx is not available. Register the OCX and relaunch.",
                -1,
                &text_rc,
                DT_CENTER | DT_VCENTER | DT_SINGLELINE);
        }
    }

    if (oldbmp) {
        SelectObject(memdc, oldbmp);
    }
    if (membmp) {
        DeleteObject(membmp);
    }
    if (memdc) {
        DeleteDC(memdc);
    }
    DeleteObject(bg);

    EndPaint(hwnd, &ps);
}

static void layout_main_window(DemoApp *app) {
    RECT rc;
    int width;
    int height;
    int x;
    int y = 8;
    int status_top;
    int view_top = TOOLBAR_HEIGHT;
    int view_height;

    if (!app || !app->hwnd_main) return;
    GetClientRect(app->hwnd_main, &rc);
    width = rc.right - rc.left;
    height = rc.bottom - rc.top;
    x = MARGIN;

    MoveWindow(app->hwnd_btn_sales, x, y, DEMO_BUTTON_WIDTH, CONTROL_HEIGHT, TRUE);
    x += DEMO_BUTTON_WIDTH + MARGIN;
    MoveWindow(app->hwnd_btn_hierarchy, x, y, DEMO_BUTTON_WIDTH, CONTROL_HEIGHT, TRUE);
    x += DEMO_BUTTON_WIDTH + MARGIN;
    MoveWindow(app->hwnd_btn_stress, x, y, DEMO_BUTTON_WIDTH, CONTROL_HEIGHT, TRUE);
    x += DEMO_BUTTON_WIDTH + MARGIN;
    MoveWindow(app->hwnd_btn_sort_up, x, y, SORT_BUTTON_WIDTH, CONTROL_HEIGHT, TRUE);
    x += SORT_BUTTON_WIDTH + MARGIN;
    MoveWindow(app->hwnd_btn_sort_down, x, y, SORT_BUTTON_WIDTH, CONTROL_HEIGHT, TRUE);
    x += SORT_BUTTON_WIDTH + 12;

    MoveWindow(app->hwnd_chk_editable, x, y + 3, 84, CHECKBOX_HEIGHT, TRUE);
    x += 84;
    MoveWindow(app->hwnd_chk_hover, x, y + 3, 68, CHECKBOX_HEIGHT, TRUE);
    x += 68;
    MoveWindow(app->hwnd_chk_debug, x, y + 3, 118, CHECKBOX_HEIGHT, TRUE);
    x += 118;
    MoveWindow(app->hwnd_chk_scroll_blit, x, y + 3, 92, CHECKBOX_HEIGHT, TRUE);
    x += 92 + 8;

    MoveWindow(app->hwnd_label_selection, x, y + 6, 58, 18, TRUE);
    x += 58 + 8;
    MoveWindow(app->hwnd_btn_selection, x, y, SELECTION_BUTTON_WIDTH, CONTROL_HEIGHT, TRUE);

    status_top = height - STATUS_HEIGHT;
    view_height = status_top - view_top - MARGIN;
    if (view_height < 80) view_height = 80;

    MoveWindow(app->hwnd_view, MARGIN, view_top, width - (MARGIN * 2), view_height, TRUE);
    MoveWindow(app->hwnd_status, 0, status_top, width, STATUS_HEIGHT, TRUE);
}

static int current_modifiers(void) {
    int mod = 0;
    if (GetKeyState(VK_SHIFT) < 0) mod |= 1;
    if (GetKeyState(VK_CONTROL) < 0) mod |= 2;
    if (GetKeyState(VK_MENU) < 0) mod |= 4;
    return mod;
}

static int button_from_move_wparam(WPARAM wp) {
    if (wp & MK_LBUTTON) return 1;
    if (wp & MK_MBUTTON) return 2;
    if (wp & MK_RBUTTON) return 3;
    return 0;
}

static int button_from_message(UINT msg) {
    switch (msg) {
    case WM_LBUTTONDOWN:
    case WM_LBUTTONDBLCLK:
    case WM_LBUTTONUP:
        return 1;
    case WM_MBUTTONDOWN:
    case WM_MBUTTONUP:
        return 2;
    case WM_RBUTTONDOWN:
    case WM_RBUTTONUP:
        return 3;
    default:
        return 0;
    }
}

static void handle_pointer_down(DemoApp *app, HWND hwnd, UINT msg, LPARAM lp, BOOL dbl_click) {
    HRESULT hr;
    LONG x;
    LONG y;
    if (!app || !app->grid) return;
    x = GET_X_LPARAM(lp);
    y = GET_Y_LPARAM(lp);
    SetFocus(hwnd);
    SetCapture(hwnd);
    hr = invoke_method_i4_5(
        app->grid,
        L"PointerDown",
        x,
        y,
        button_from_message(msg),
        current_modifiers(),
        dbl_click ? 1 : 0);
    if (SUCCEEDED(hr)) {
        invalidate_view(app);
        set_focus_status(app, L"");
    } else {
        set_statusf(app, L"PointerDown failed: 0x%08lx", (unsigned long)hr);
    }
}

static void handle_pointer_up(DemoApp *app, UINT msg, LPARAM lp) {
    HRESULT hr;
    LONG x;
    LONG y;
    if (!app || !app->grid) return;
    x = GET_X_LPARAM(lp);
    y = GET_Y_LPARAM(lp);
    hr = invoke_method_i4_4(
        app->grid,
        L"PointerUp",
        x,
        y,
        button_from_message(msg),
        current_modifiers());
    if (GetCapture() == app->hwnd_view) {
        ReleaseCapture();
    }
    if (SUCCEEDED(hr)) {
        invalidate_view(app);
        set_focus_status(app, L"");
    } else {
        set_statusf(app, L"PointerUp failed: 0x%08lx", (unsigned long)hr);
    }
}

static void handle_pointer_move(DemoApp *app, WPARAM wp, LPARAM lp) {
    HRESULT hr;
    LONG x;
    LONG y;
    if (!app || !app->grid) return;
    x = GET_X_LPARAM(lp);
    y = GET_Y_LPARAM(lp);
    hr = invoke_method_i4_4(
        app->grid,
        L"PointerMove",
        x,
        y,
        button_from_move_wparam(wp),
        current_modifiers());
    if (SUCCEEDED(hr)) {
        invalidate_view(app);
    }
}

static void handle_mouse_wheel(DemoApp *app, HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    float dx = 0.0f;
    float dy = 0.0f;
    short delta;
    HRESULT hr;
    if (!app || !app->grid) return;
    (void)msg;
    (void)lp;
    delta = GET_WHEEL_DELTA_WPARAM(wp);
    if (current_modifiers() & 1) {
        dx = (float)delta / 120.0f * 3.0f;
    } else {
        dy = -(float)delta / 120.0f * 3.0f;
    }
    hr = invoke_method_r4_2(app->grid, L"Scroll", dx, dy);
    if (SUCCEEDED(hr)) {
        SetFocus(hwnd);
        invalidate_view(app);
    } else {
        set_statusf(app, L"Scroll failed: 0x%08lx", (unsigned long)hr);
    }
}

static void handle_key_down(DemoApp *app, WPARAM wp) {
    HRESULT hr;
    if (!app || !app->grid) return;
    hr = invoke_method_i4_2(app->grid, L"KeyDown", (LONG)wp, current_modifiers());
    if (SUCCEEDED(hr)) {
        invalidate_view(app);
        set_focus_status(app, L"");
    } else {
        set_statusf(app, L"KeyDown failed: 0x%08lx", (unsigned long)hr);
    }
}

static void handle_key_press(DemoApp *app, WPARAM wp) {
    HRESULT hr;
    if (!app || !app->grid) return;
    hr = invoke_method_i4_1(app->grid, L"KeyPress", (LONG)wp);
    if (SUCCEEDED(hr)) {
        invalidate_view(app);
        set_focus_status(app, L"");
    } else {
        set_statusf(app, L"KeyPress failed: 0x%08lx", (unsigned long)hr);
    }
}

static BSTR get_ime_string_bstr(HIMC hImc, DWORD index) {
    LONG byte_len;
    UINT char_len;
    BSTR text;

    if (!hImc) return NULL;

    byte_len = ImmGetCompositionStringW(hImc, index, NULL, 0);
    if (byte_len < 0) return NULL;
    if (byte_len == 0) return SysAllocStringLen(L"", 0);

    char_len = (UINT)(byte_len / (LONG)sizeof(WCHAR));
    text = SysAllocStringLen(NULL, char_len);
    if (!text) return NULL;

    if (ImmGetCompositionStringW(hImc, index, text, byte_len) < 0) {
        SysFreeString(text);
        return NULL;
    }
    text[char_len] = L'\0';
    return text;
}

static void handle_ime_composition(DemoApp *app, HWND hwnd, LPARAM lp) {
    HIMC hImc;
    HRESULT hr;
    BOOL updated = FALSE;

    if (!app || !app->grid) return;

    hImc = ImmGetContext(hwnd);
    if (!hImc) return;

    if (lp & GCS_RESULTSTR) {
        BSTR result = get_ime_string_bstr(hImc, GCS_RESULTSTR);
        if (result) {
            if (SysStringLen(result) > 0) {
                hr = invoke_method_bstr_i4_i4(app->grid, L"ImeComposition", result, (LONG)SysStringLen(result), 1);
                if (SUCCEEDED(hr)) {
                    updated = TRUE;
                } else {
                    set_statusf(app, L"ImeComposition commit failed: 0x%08lx", (unsigned long)hr);
                }
            }
            SysFreeString(result);
        }
    }

    if (lp & GCS_COMPSTR) {
        BSTR comp = get_ime_string_bstr(hImc, GCS_COMPSTR);
        if (comp) {
            hr = invoke_method_bstr_i4_i4(app->grid, L"ImeComposition", comp, (LONG)SysStringLen(comp), 0);
            if (SUCCEEDED(hr)) {
                updated = TRUE;
            } else {
                set_statusf(app, L"ImeComposition preedit failed: 0x%08lx", (unsigned long)hr);
            }
            SysFreeString(comp);
        }
    }

    ImmReleaseContext(hwnd, hImc);

    if (updated) {
        invalidate_view(app);
        set_focus_status(app, L"");
    }
}

static void sort_focused_column(DemoApp *app, BOOL ascending) {
    LONG col = 0;
    HRESULT hr;
    if (!app || !app->grid) return;
    hr = get_i4_property(app->grid, L"Col", &col);
    if (FAILED(hr) || col < 0) {
        set_statusf(app, L"Select a cell first to sort its column.");
        return;
    }
    hr = invoke_method_i4_2(app->grid, L"Sort", ascending ? 1 : 2, col);
    if (FAILED(hr)) {
        set_statusf(app, L"Sort failed: 0x%08lx", (unsigned long)hr);
        return;
    }
    invalidate_view(app);
    set_statusf(app, L"Applied sort on column %ld %ls.", col, ascending ? L"ascending" : L"descending");
}

static BOOL apply_selection_mode(DemoApp *app, int mode) {
    int old_mode;
    HRESULT hr;
    if (!app || !app->grid) return FALSE;
    old_mode = app->selection_mode;
    app->selection_mode = mode;
    hr = sync_selection_mode(app);
    if (FAILED(hr)) {
        app->selection_mode = old_mode;
        update_selection_ui(app);
        set_statusf(app, L"Selection mode change failed: 0x%08lx", (unsigned long)hr);
        return FALSE;
    }
    update_selection_ui(app);
    invalidate_view(app);
    set_statusf(app, L"Selection mode: %ls.", selection_mode_title(mode));
    return TRUE;
}

static BOOL apply_editable(DemoApp *app, BOOL enabled) {
    BOOL old_value;
    HRESULT hr;
    if (!app || !app->grid) return FALSE;
    old_value = app->editable;
    app->editable = enabled;
    hr = sync_editable(app);
    if (FAILED(hr)) {
        app->editable = old_value;
        set_checked(app->hwnd_chk_editable, old_value);
        set_statusf(app, L"Editable toggle failed: 0x%08lx", (unsigned long)hr);
        return FALSE;
    }
    invalidate_view(app);
    set_statusf(app, enabled ? L"Editing enabled." : L"Editing disabled.");
    return TRUE;
}

static BOOL apply_hover(DemoApp *app, BOOL enabled) {
    BOOL old_value;
    HRESULT hr;
    if (!app || !app->grid) return FALSE;
    old_value = app->hover_enabled;
    app->hover_enabled = enabled;
    hr = sync_hover(app);
    if (FAILED(hr)) {
        app->hover_enabled = old_value;
        set_checked(app->hwnd_chk_hover, old_value);
        set_statusf(app, L"Hover toggle failed: 0x%08lx", (unsigned long)hr);
        return FALSE;
    }
    invalidate_view(app);
    set_statusf(app, enabled ? L"Hover enabled." : L"Hover disabled.");
    return TRUE;
}

static BOOL apply_debug_overlay(DemoApp *app, BOOL enabled) {
    BOOL old_value;
    HRESULT hr;
    if (!app || !app->grid) return FALSE;
    old_value = app->debug_overlay;
    app->debug_overlay = enabled;
    hr = sync_debug_overlay(app);
    if (FAILED(hr)) {
        app->debug_overlay = old_value;
        set_checked(app->hwnd_chk_debug, old_value);
        set_statusf(app, L"Debug overlay toggle failed: 0x%08lx", (unsigned long)hr);
        return FALSE;
    }
    invalidate_view(app);
    set_statusf(app, enabled ? L"Debug overlay enabled." : L"Debug overlay disabled.");
    return TRUE;
}

static BOOL apply_scroll_blit(DemoApp *app, BOOL enabled) {
    BOOL old_value;
    HRESULT hr;
    if (!app || !app->grid) return FALSE;
    old_value = app->scroll_blit_enabled;
    app->scroll_blit_enabled = enabled;
    hr = sync_scroll_blit(app);
    if (FAILED(hr)) {
        app->scroll_blit_enabled = old_value;
        set_checked(app->hwnd_chk_scroll_blit, old_value);
        set_statusf(app, L"Scroll blit toggle failed: 0x%08lx", (unsigned long)hr);
        return FALSE;
    }
    invalidate_view(app);
    set_statusf(app, enabled ? L"Scroll blit enabled." : L"Scroll blit disabled.");
    return TRUE;
}

static void open_selection_menu(DemoApp *app) {
    RECT rc;
    UINT cmd;
    if (!app || !app->selection_menu || !app->hwnd_btn_selection) return;
    GetWindowRect(app->hwnd_btn_selection, &rc);
    cmd = TrackPopupMenu(
        app->selection_menu,
        TPM_LEFTALIGN | TPM_TOPALIGN | TPM_RETURNCMD,
        rc.left,
        rc.bottom,
        0,
        app->hwnd_main,
        NULL);
    if (cmd != 0) {
        SendMessageW(app->hwnd_main, WM_COMMAND, MAKEWPARAM(cmd, 0), 0);
    }
}

static LRESULT CALLBACK view_wnd_proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    DemoApp *app = (DemoApp *)GetWindowLongPtrW(hwnd, GWLP_USERDATA);

    switch (msg) {
    case WM_NCCREATE: {
        CREATESTRUCTW *cs = (CREATESTRUCTW *)lp;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)cs->lpCreateParams);
        return TRUE;
    }
    case WM_ERASEBKGND:
        return 1;
    case WM_PAINT:
        paint_view_window(app, hwnd);
        return 0;
    case WM_GETDLGCODE:
        return DLGC_WANTARROWS | DLGC_WANTCHARS | DLGC_WANTTAB;
    case WM_SETFOCUS:
    case WM_KILLFOCUS:
        InvalidateRect(hwnd, NULL, FALSE);
        return 0;
    case WM_LBUTTONDOWN:
    case WM_MBUTTONDOWN:
    case WM_RBUTTONDOWN:
        handle_pointer_down(app, hwnd, msg, lp, FALSE);
        return 0;
    case WM_LBUTTONDBLCLK:
        handle_pointer_down(app, hwnd, msg, lp, TRUE);
        return 0;
    case WM_LBUTTONUP:
    case WM_MBUTTONUP:
    case WM_RBUTTONUP:
        handle_pointer_up(app, msg, lp);
        return 0;
    case WM_MOUSEMOVE:
        handle_pointer_move(app, wp, lp);
        return 0;
    case WM_MOUSEWHEEL:
        handle_mouse_wheel(app, hwnd, msg, wp, lp);
        return 0;
    case WM_KEYDOWN:
        handle_key_down(app, wp);
        return 0;
    case WM_CHAR:
        handle_key_press(app, wp);
        return 0;
    case WM_IME_STARTCOMPOSITION:
        return DefWindowProcW(hwnd, msg, wp, lp);
    case WM_IME_COMPOSITION:
        handle_ime_composition(app, hwnd, lp);
        return DefWindowProcW(hwnd, msg, wp, lp);
    case WM_IME_ENDCOMPOSITION: {
        HRESULT hr = S_OK;
        if (app && app->grid) {
            hr = invoke_method_bstr_i4_i4(app->grid, L"ImeComposition", NULL, 0, 0);
            if (SUCCEEDED(hr)) {
                invalidate_view(app);
                set_focus_status(app, L"");
            } else {
                set_statusf(app, L"ImeComposition clear failed: 0x%08lx", (unsigned long)hr);
            }
        }
        return DefWindowProcW(hwnd, msg, wp, lp);
    }
    case WM_IME_CHAR:
        return 0;
    default:
        return DefWindowProcW(hwnd, msg, wp, lp);
    }
}

static LRESULT CALLBACK main_wnd_proc(HWND hwnd, UINT msg, WPARAM wp, LPARAM lp) {
    DemoApp *app = (DemoApp *)GetWindowLongPtrW(hwnd, GWLP_USERDATA);

    switch (msg) {
    case WM_NCCREATE: {
        CREATESTRUCTW *cs = (CREATESTRUCTW *)lp;
        app = (DemoApp *)cs->lpCreateParams;
        app->hwnd_main = hwnd;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)app);
        return TRUE;
    }
    case WM_CREATE: {
        HFONT gui_font = (HFONT)GetStockObject(DEFAULT_GUI_FONT);
        HRESULT hr;
        HINSTANCE inst = GetModuleHandleW(NULL);

        app->hwnd_btn_sales = CreateWindowW(
            L"BUTTON", L"Sales", WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
            0, 0, 0, 0, hwnd, (HMENU)(INT_PTR)ID_BTN_SALES, inst, NULL);
        app->hwnd_btn_hierarchy = CreateWindowW(
            L"BUTTON", L"Hierarchy", WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
            0, 0, 0, 0, hwnd, (HMENU)(INT_PTR)ID_BTN_HIERARCHY, inst, NULL);
        app->hwnd_btn_stress = CreateWindowW(
            L"BUTTON", L"Stress", WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
            0, 0, 0, 0, hwnd, (HMENU)(INT_PTR)ID_BTN_STRESS, inst, NULL);
        app->hwnd_btn_sort_up = CreateWindowW(
            L"BUTTON", L"\x2191", WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
            0, 0, 0, 0, hwnd, (HMENU)(INT_PTR)ID_BTN_SORT_UP, inst, NULL);
        app->hwnd_btn_sort_down = CreateWindowW(
            L"BUTTON", L"\x2193", WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
            0, 0, 0, 0, hwnd, (HMENU)(INT_PTR)ID_BTN_SORT_DOWN, inst, NULL);

        app->hwnd_chk_editable = CreateWindowW(
            L"BUTTON", L"Editable", WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_AUTOCHECKBOX,
            0, 0, 0, 0, hwnd, (HMENU)(INT_PTR)ID_CHK_EDITABLE, inst, NULL);
        app->hwnd_chk_hover = CreateWindowW(
            L"BUTTON", L"Hover", WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_AUTOCHECKBOX,
            0, 0, 0, 0, hwnd, (HMENU)(INT_PTR)ID_CHK_HOVER, inst, NULL);
        app->hwnd_chk_debug = CreateWindowW(
            L"BUTTON", L"Debug Overlay", WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_AUTOCHECKBOX,
            0, 0, 0, 0, hwnd, (HMENU)(INT_PTR)ID_CHK_DEBUG, inst, NULL);
        app->hwnd_chk_scroll_blit = CreateWindowW(
            L"BUTTON", L"Scroll Blit", WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_AUTOCHECKBOX,
            0, 0, 0, 0, hwnd, (HMENU)(INT_PTR)ID_CHK_SCROLL_BLIT, inst, NULL);

        app->hwnd_label_selection = CreateWindowW(
            L"STATIC", L"Selection", WS_CHILD | WS_VISIBLE,
            0, 0, 0, 0, hwnd, NULL, inst, NULL);
        app->hwnd_btn_selection = CreateWindowW(
            L"BUTTON", L"Free", WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
            0, 0, 0, 0, hwnd, (HMENU)(INT_PTR)ID_BTN_SELECTION, inst, NULL);

        app->hwnd_view = CreateWindowExW(
            WS_EX_CLIENTEDGE,
            VIEW_WND_CLASS,
            L"",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP,
            0, 0, 0, 0,
            hwnd,
            NULL,
            inst,
            app);

        app->hwnd_status = CreateWindowW(
            L"STATIC",
            L"Preparing VolvoxGrid.ocx...",
            WS_CHILD | WS_VISIBLE | SS_SUNKEN | SS_LEFTNOWORDWRAP,
            0, 0, 0, 0,
            hwnd,
            NULL,
            inst,
            NULL);

        app->selection_menu = CreatePopupMenu();
        AppendMenuW(app->selection_menu, MF_STRING, ID_MENU_SELECTION_FREE, L"Free");
        AppendMenuW(app->selection_menu, MF_STRING, ID_MENU_SELECTION_BY_ROW, L"By Row");
        AppendMenuW(app->selection_menu, MF_STRING, ID_MENU_SELECTION_BY_COLUMN, L"By Column");
        AppendMenuW(app->selection_menu, MF_STRING, ID_MENU_SELECTION_LISTBOX, L"Listbox");

        SendMessageW(app->hwnd_btn_sales, WM_SETFONT, (WPARAM)gui_font, TRUE);
        SendMessageW(app->hwnd_btn_hierarchy, WM_SETFONT, (WPARAM)gui_font, TRUE);
        SendMessageW(app->hwnd_btn_stress, WM_SETFONT, (WPARAM)gui_font, TRUE);
        SendMessageW(app->hwnd_btn_sort_up, WM_SETFONT, (WPARAM)gui_font, TRUE);
        SendMessageW(app->hwnd_btn_sort_down, WM_SETFONT, (WPARAM)gui_font, TRUE);
        SendMessageW(app->hwnd_chk_editable, WM_SETFONT, (WPARAM)gui_font, TRUE);
        SendMessageW(app->hwnd_chk_hover, WM_SETFONT, (WPARAM)gui_font, TRUE);
        SendMessageW(app->hwnd_chk_debug, WM_SETFONT, (WPARAM)gui_font, TRUE);
        SendMessageW(app->hwnd_chk_scroll_blit, WM_SETFONT, (WPARAM)gui_font, TRUE);
        SendMessageW(app->hwnd_label_selection, WM_SETFONT, (WPARAM)gui_font, TRUE);
        SendMessageW(app->hwnd_btn_selection, WM_SETFONT, (WPARAM)gui_font, TRUE);
        SendMessageW(app->hwnd_status, WM_SETFONT, (WPARAM)gui_font, TRUE);

        set_checked(app->hwnd_chk_editable, app->editable);
        set_checked(app->hwnd_chk_hover, app->hover_enabled);
        set_checked(app->hwnd_chk_debug, app->debug_overlay);
        set_checked(app->hwnd_chk_scroll_blit, app->scroll_blit_enabled);
        update_selection_ui(app);
        update_demo_button_styles(app);
        layout_main_window(app);

        hr = create_grid_object(app);
        if (FAILED(hr)) {
            MessageBoxW(
                hwnd,
                L"Failed to create VolvoxGrid.ocx. Run regsvr32 on the built OCX and try again.",
                L"VolvoxGrid ActiveX Demo",
                MB_OK | MB_ICONERROR);
            set_statusf(app, L"CoCreateInstance failed: 0x%08lx", (unsigned long)hr);
            return -1;
        }

        if (!switch_demo(app, app->current_demo)) {
            MessageBoxW(
                hwnd,
                L"The OCX loaded, but the ActiveX bridge methods are unavailable.",
                L"VolvoxGrid ActiveX Demo",
                MB_OK | MB_ICONERROR);
            return -1;
        }

        SetFocus(app->hwnd_view);
        return 0;
    }
    case WM_SIZE:
        layout_main_window(app);
        if (app && app->grid) {
            sync_viewport(app);
            invalidate_view(app);
        }
        return 0;
    case WM_COMMAND:
        if (!app) break;
        switch (LOWORD(wp)) {
        case ID_BTN_SALES:
            switch_demo(app, L"sales");
            return 0;
        case ID_BTN_HIERARCHY:
            switch_demo(app, L"hierarchy");
            return 0;
        case ID_BTN_STRESS:
            switch_demo(app, L"stress");
            return 0;
        case ID_BTN_SORT_UP:
            sort_focused_column(app, TRUE);
            return 0;
        case ID_BTN_SORT_DOWN:
            sort_focused_column(app, FALSE);
            return 0;
        case ID_CHK_EDITABLE:
            apply_editable(app, is_checked(app->hwnd_chk_editable));
            return 0;
        case ID_CHK_HOVER:
            apply_hover(app, is_checked(app->hwnd_chk_hover));
            return 0;
        case ID_CHK_DEBUG:
            apply_debug_overlay(app, is_checked(app->hwnd_chk_debug));
            return 0;
        case ID_CHK_SCROLL_BLIT:
            apply_scroll_blit(app, is_checked(app->hwnd_chk_scroll_blit));
            return 0;
        case ID_BTN_SELECTION:
            open_selection_menu(app);
            return 0;
        case ID_MENU_SELECTION_FREE:
            apply_selection_mode(app, 0);
            return 0;
        case ID_MENU_SELECTION_BY_ROW:
            apply_selection_mode(app, 1);
            return 0;
        case ID_MENU_SELECTION_BY_COLUMN:
            apply_selection_mode(app, 2);
            return 0;
        case ID_MENU_SELECTION_LISTBOX:
            apply_selection_mode(app, 3);
            return 0;
        default:
            break;
        }
        break;
    case WM_DESTROY:
        destroy_grid_object(app);
        if (app && app->selection_menu) {
            DestroyMenu(app->selection_menu);
            app->selection_menu = NULL;
        }
        PostQuitMessage(0);
        return 0;
    case WM_NCDESTROY:
        if (app) {
            SetWindowLongPtrW(hwnd, GWLP_USERDATA, 0);
            HeapFree(GetProcessHeap(), 0, app);
        }
        return DefWindowProcW(hwnd, msg, wp, lp);
    default:
        break;
    }

    return DefWindowProcW(hwnd, msg, wp, lp);
}

static BOOL register_window_class(const WCHAR *name, WNDPROC proc, HBRUSH brush, UINT style) {
    WNDCLASSW wc;
    memset(&wc, 0, sizeof(wc));
    wc.style = style;
    wc.lpfnWndProc = proc;
    wc.hInstance = GetModuleHandleW(NULL);
    wc.hCursor = LoadCursor(NULL, IDC_ARROW);
    wc.hIcon = LoadIcon(NULL, IDI_APPLICATION);
    wc.hbrBackground = brush;
    wc.lpszClassName = name;
    if (RegisterClassW(&wc)) return TRUE;
    return GetLastError() == ERROR_CLASS_ALREADY_EXISTS;
}

static const char *skip_cli_ws(const char *p) {
    while (p && (*p == ' ' || *p == '\t')) ++p;
    return p;
}

static const char *scan_cli_token(const char *p) {
    int quoted = 0;
    while (p && *p) {
        if (*p == '"') {
            quoted = !quoted;
            ++p;
            continue;
        }
        if (!quoted && (*p == ' ' || *p == '\t')) break;
        ++p;
    }
    return p;
}

static BOOL parse_font_name_arg(const char *cmdline, WCHAR *out, size_t out_cap) {
    const char *p = cmdline;
    const char *value;
    const char *end;
    char tmp[256];
    int len;
    int wlen;

    if (!out || out_cap == 0) return FALSE;
    out[0] = L'\0';
    if (!p) return FALSE;

    for (;;) {
        p = skip_cli_ws(p);
        if (!*p) return FALSE;
        if (strncmp(p, "--font-name=", 12) == 0) {
            value = p + 12;
        } else if (strncmp(p, "--font-name", 11) == 0 &&
                   (p[11] == '\0' || p[11] == ' ' || p[11] == '\t')) {
            p = skip_cli_ws(p + 11);
            if (!*p) return FALSE;
            value = p;
        } else {
            p = scan_cli_token(p);
            continue;
        }

        value = skip_cli_ws(value);
        if (*value == '"') {
            ++value;
            end = value;
            while (*end && *end != '"') ++end;
        } else {
            end = scan_cli_token(value);
        }

        len = (int)(end - value);
        if (len <= 0) return FALSE;
        if (len >= (int)sizeof(tmp)) len = (int)sizeof(tmp) - 1;
        memcpy(tmp, value, (size_t)len);
        tmp[len] = '\0';
        wlen = MultiByteToWideChar(CP_UTF8, 0, tmp, -1, out, (int)out_cap);
        if (wlen <= 0) {
            wlen = MultiByteToWideChar(CP_ACP, 0, tmp, -1, out, (int)out_cap);
        }
        if (wlen <= 0) {
            out[0] = L'\0';
            return FALSE;
        }
        out[out_cap - 1] = L'\0';
        return TRUE;
    }
}

int WINAPI WinMain(HINSTANCE instance, HINSTANCE prev, LPSTR cmdline, int show) {
    DemoApp *app;
    HWND hwnd;
    RECT rc;
    MSG msg;
    HRESULT hr;

    (void)instance;
    (void)prev;
    (void)cmdline;

    hr = OleInitialize(NULL);
    if (FAILED(hr)) {
        MessageBoxW(NULL, L"OleInitialize failed.", L"VolvoxGrid ActiveX Demo", MB_OK | MB_ICONERROR);
        return 1;
    }

    if (!register_window_class(MAIN_WND_CLASS, main_wnd_proc, (HBRUSH)(COLOR_BTNFACE + 1), 0) ||
        !register_window_class(VIEW_WND_CLASS, view_wnd_proc, (HBRUSH)(COLOR_WINDOW + 1), CS_DBLCLKS)) {
        MessageBoxW(NULL, L"Failed to register Win32 window classes.", L"VolvoxGrid ActiveX Demo", MB_OK | MB_ICONERROR);
        OleUninitialize();
        return 1;
    }

    app = (DemoApp *)HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*app));
    if (!app) {
        OleUninitialize();
        return 1;
    }

    copy_wstr(app->current_demo, sizeof(app->current_demo) / sizeof(app->current_demo[0]), L"sales");
    app->selection_mode = 0;
    app->editable = TRUE;
    app->hover_enabled = TRUE;
    app->debug_overlay = FALSE;
    app->scroll_blit_enabled = FALSE;
    parse_font_name_arg(cmdline, app->initial_font_name, sizeof(app->initial_font_name) / sizeof(app->initial_font_name[0]));

    rc.left = 0;
    rc.top = 0;
    rc.right = WINDOW_WIDTH;
    rc.bottom = WINDOW_HEIGHT;
    AdjustWindowRect(&rc, WS_OVERLAPPEDWINDOW, FALSE);

    hwnd = CreateWindowW(
        MAIN_WND_CLASS,
        L"VolvoxGrid ActiveX Demo",
        WS_OVERLAPPEDWINDOW | WS_VISIBLE,
        CW_USEDEFAULT,
        CW_USEDEFAULT,
        rc.right - rc.left,
        rc.bottom - rc.top,
        NULL,
        NULL,
        GetModuleHandleW(NULL),
        app);

    if (!hwnd) {
        HeapFree(GetProcessHeap(), 0, app);
        OleUninitialize();
        return 1;
    }

    ShowWindow(hwnd, show ? show : SW_SHOWDEFAULT);
    UpdateWindow(hwnd);

    while (GetMessageW(&msg, NULL, 0, 0) > 0) {
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    OleUninitialize();
    return (int)msg.wParam;
}
