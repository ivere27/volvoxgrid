#define COBJMACROS
#include <windows.h>
#include <ole2.h>
#include <oleauto.h>
#include <ocidl.h>
#include <olectl.h>
#include <stdio.h>
#include <string.h>

static const GUID CLSID_VolvoxGrid =
    {0xA7E3B4D1,0x5C2F,0x4E8A,{0xB9,0xD6,0x1F,0x3C,0x7E,0x2A,0x4B,0x5D}};

static const GUID DIID__DVolvoxGridEvents =
    {0xB8F4C5D2,0x9E3F,0x4A6B,{0xAD,0x7C,0x2E,0x4F,0x6A,0x8B,0x9C,0x0D}};

#define DISPID_VFG_EVT_SELCHANGE          1
#define DISPID_VFG_EVT_ROWCOLCHANGE       2
#define DISPID_VFG_EVT_BEFOREROWCOLCHANGE 6
#define DISPID_VFG_EVT_AFTERROWCOLCHANGE  7
#define DISPID_VFG_EVT_BEFORESELCHANGE    8
#define DISPID_VFG_EVT_AFTERSELCHANGE     9
#define DISPID_VFG_EVT_BEFORESCROLL       10
#define DISPID_VFG_EVT_AFTERSCROLL        11
#define DISPID_VFG_EVT_BEFORESORT         13
#define DISPID_VFG_EVT_AFTERSORT          14
#define DISPID_VFG_EVT_BEFOREMOVECOLUMN   15
#define DISPID_VFG_EVT_AFTERMOVECOLUMN    16
#define DISPID_VFG_EVT_BEFOREUSERRESIZE   17
#define DISPID_VFG_EVT_AFTERUSERRESIZE    18
#define DISPID_VFG_EVT_BEFORECOLLAPSE     19
#define DISPID_VFG_EVT_AFTERCOLLAPSE      20
#define DISPID_VFG_EVT_BEFOREEDIT         21
#define DISPID_VFG_EVT_STARTEDIT          22
#define DISPID_VFG_EVT_AFTEREDIT          24
#define DISPID_VFG_EVT_DRAWCELL           32
#define DISPID_VFG_EVT_ERROR              33
#define DISPID_VFG_EVT_AFTERUSERFREEZE    36
#define DISPID_VFG_EVT_OLESTARTDRAG       37
#define DISPID_VFG_EVT_OLEGIVEFEEDBACK    38
#define DISPID_VFG_EVT_OLESETDATA         39
#define DISPID_VFG_EVT_OLECOMPLETEDRAG    40
#define DISPID_VFG_EVT_OLEDRAGOVER        41
#define DISPID_VFG_EVT_OLEDRAGDROP        42
#define DISPID_VFG_EVT_CELLCHANGED        43
#define DISPID_VFG_EVT_BEFOREMOVEROW      44
#define DISPID_VFG_EVT_AFTERMOVEROW       45
#define DISPID_VFG_EVT_BEFOREDATAREFRESH  81
#define DISPID_VFG_EVT_AFTERDATAREFRESH   82

#define PROBE_OWNER_DRAW_COLOR RGB(0x16, 0x7a, 0xc8)

typedef HRESULT (STDAPICALLTYPE *DllGetClassObjectFn)(REFCLSID, REFIID, LPVOID *);

typedef struct ProbeEventSink {
    IDispatchVtbl *lpVtbl;
    LONG refs;
    int before_row_col;
    int after_row_col;
    int row_col_change;
    int before_sel;
    int after_sel;
    int sel_change;
    int before_scroll;
    int after_scroll;
    int before_sort;
    int after_sort;
    int before_move_col;
    int after_move_col;
    int before_move_row;
    int after_move_row;
    int before_resize;
    int after_resize;
    int before_collapse;
    int after_collapse;
    int before_edit;
    int start_edit;
    int after_edit;
    int after_user_freeze;
    int cell_changed;
    int before_data_refresh;
    int after_data_refresh;
    int error_event;
    int ole_start_drag;
    int ole_give_feedback;
    int ole_complete_drag;
    int ole_drag_over;
    int ole_drag_drop;
    int ole_drag_enter_state;
    int ole_drag_over_state;
    int ole_drag_leave_state;
    int draw_cell;
    int draw_done_count;
    LONG draw_first_row;
    LONG draw_first_col;
    LONG draw_first_left;
    LONG draw_first_top;
    LONG draw_first_right;
    LONG draw_first_bottom;
    DISPID cancel_dispid;
    int arg_mismatch;
} ProbeEventSink;

static void print_hr(const char *label, HRESULT hr) {
    printf("%s: 0x%08lx\n", label, (unsigned long)hr);
}

static HRESULT load_factory(const char *ocx_path_utf8, IClassFactory **out) {
    WCHAR path[MAX_PATH];
    HMODULE module;
    DllGetClassObjectFn get_class_object;

    if (!out) return E_POINTER;
    *out = NULL;
    MultiByteToWideChar(CP_UTF8, 0, ocx_path_utf8, -1, path, MAX_PATH);
    module = LoadLibraryW(path);
    if (!module) return HRESULT_FROM_WIN32(GetLastError());
    get_class_object = (DllGetClassObjectFn)GetProcAddress(module, "DllGetClassObject");
    if (!get_class_object) return HRESULT_FROM_WIN32(GetLastError());
    return get_class_object(&CLSID_VolvoxGrid, &IID_IClassFactory, (void **)out);
}

static HRESULT create_grid(IClassFactory *factory, IDispatch **out) {
    if (!out) return E_POINTER;
    *out = NULL;
    return IClassFactory_CreateInstance(
        factory, NULL, &IID_IDispatch, (void **)out);
}

static HRESULT get_dispid(IDispatch *disp, LPCOLESTR name, DISPID *out) {
    LPOLESTR names[1] = { (LPOLESTR)name };
    return IDispatch_GetIDsOfNames(disp, &IID_NULL, names, 1, LOCALE_USER_DEFAULT, out);
}

static HRESULT put_i4(IDispatch *disp, LPCOLESTR name, LONG value) {
    DISPID dispid;
    DISPID named = DISPID_PROPERTYPUT;
    VARIANT arg;
    DISPPARAMS dp;
    HRESULT hr = get_dispid(disp, name, &dispid);
    if (FAILED(hr)) return hr;
    VariantInit(&arg);
    V_VT(&arg) = VT_I4;
    V_I4(&arg) = value;
    dp.rgvarg = &arg;
    dp.rgdispidNamedArgs = &named;
    dp.cArgs = 1;
    dp.cNamedArgs = 1;
    return IDispatch_Invoke(
        disp, dispid, &IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_PROPERTYPUT,
        &dp, NULL, NULL, NULL);
}

static HRESULT putref_dispatch(IDispatch *disp, LPCOLESTR name, IDispatch *value) {
    DISPID dispid;
    DISPID named = DISPID_PROPERTYPUT;
    VARIANT arg;
    DISPPARAMS dp;
    HRESULT hr = get_dispid(disp, name, &dispid);
    if (FAILED(hr)) return hr;
    VariantInit(&arg);
    V_VT(&arg) = VT_DISPATCH;
    V_DISPATCH(&arg) = value;
    dp.rgvarg = &arg;
    dp.rgdispidNamedArgs = &named;
    dp.cArgs = 1;
    dp.cNamedArgs = 1;
    return IDispatch_Invoke(
        disp, dispid, &IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_PROPERTYPUTREF,
        &dp, NULL, NULL, NULL);
}

static HRESULT get_i4(IDispatch *disp, LPCOLESTR name, LONG *out) {
    DISPID dispid;
    VARIANT result;
    VARIANT tmp;
    DISPPARAMS dp;
    HRESULT hr;

    if (!out) return E_POINTER;
    *out = 0;
    hr = get_dispid(disp, name, &dispid);
    if (FAILED(hr)) return hr;
    memset(&dp, 0, sizeof(dp));
    VariantInit(&result);
    VariantInit(&tmp);
    hr = IDispatch_Invoke(
        disp, dispid, &IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_PROPERTYGET,
        &dp, &result, NULL, NULL);
    if (SUCCEEDED(hr)) hr = VariantChangeType(&tmp, &result, 0, VT_I4);
    if (SUCCEEDED(hr)) *out = V_I4(&tmp);
    VariantClear(&result);
    VariantClear(&tmp);
    return hr;
}

static HRESULT put_indexed_i4(IDispatch *disp, LPCOLESTR name, LONG index, LONG value) {
    DISPID dispid;
    DISPID named = DISPID_PROPERTYPUT;
    VARIANT args[2];
    DISPPARAMS dp;
    HRESULT hr = get_dispid(disp, name, &dispid);
    if (FAILED(hr)) return hr;
    VariantInit(&args[0]);
    VariantInit(&args[1]);
    V_VT(&args[0]) = VT_I4;
    V_I4(&args[0]) = value;
    V_VT(&args[1]) = VT_I4;
    V_I4(&args[1]) = index;
    dp.rgvarg = args;
    dp.rgdispidNamedArgs = &named;
    dp.cArgs = 2;
    dp.cNamedArgs = 1;
    return IDispatch_Invoke(
        disp, dispid, &IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_PROPERTYPUT,
        &dp, NULL, NULL, NULL);
}

static HRESULT get_indexed_i4(IDispatch *disp, LPCOLESTR name, LONG index, LONG *out) {
    DISPID dispid;
    VARIANT args[1];
    VARIANT result;
    VARIANT tmp;
    DISPPARAMS dp;
    HRESULT hr;

    if (!out) return E_POINTER;
    *out = 0;
    hr = get_dispid(disp, name, &dispid);
    if (FAILED(hr)) return hr;
    VariantInit(&args[0]);
    VariantInit(&result);
    VariantInit(&tmp);
    V_VT(&args[0]) = VT_I4;
    V_I4(&args[0]) = index;
    dp.rgvarg = args;
    dp.rgdispidNamedArgs = NULL;
    dp.cArgs = 1;
    dp.cNamedArgs = 0;
    hr = IDispatch_Invoke(
        disp, dispid, &IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_PROPERTYGET,
        &dp, &result, NULL, NULL);
    if (SUCCEEDED(hr)) hr = VariantChangeType(&tmp, &result, 0, VT_I4);
    if (SUCCEEDED(hr)) *out = V_I4(&tmp);
    VariantClear(&result);
    VariantClear(&tmp);
    return hr;
}

static HRESULT put_ui1_array(IDispatch *disp, LPCOLESTR name, const BYTE *data, LONG len) {
    DISPID dispid;
    DISPID named = DISPID_PROPERTYPUT;
    VARIANT arg;
    DISPPARAMS dp;
    SAFEARRAYBOUND bound;
    void *dst = NULL;
    HRESULT hr;

    if (!data && len > 0) return E_POINTER;
    hr = get_dispid(disp, name, &dispid);
    if (FAILED(hr)) return hr;
    VariantInit(&arg);
    bound.lLbound = 0;
    bound.cElements = len > 0 ? (ULONG)len : 0;
    V_ARRAY(&arg) = SafeArrayCreate(VT_UI1, 1, &bound);
    if (!V_ARRAY(&arg)) return E_OUTOFMEMORY;
    V_VT(&arg) = VT_ARRAY | VT_UI1;
    if (len > 0) {
        hr = SafeArrayAccessData(V_ARRAY(&arg), &dst);
        if (FAILED(hr)) {
            VariantClear(&arg);
            return hr;
        }
        memcpy(dst, data, (size_t)len);
        SafeArrayUnaccessData(V_ARRAY(&arg));
    }
    dp.rgvarg = &arg;
    dp.rgdispidNamedArgs = &named;
    dp.cArgs = 1;
    dp.cNamedArgs = 1;
    hr = IDispatch_Invoke(
        disp, dispid, &IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_PROPERTYPUT,
        &dp, NULL, NULL, NULL);
    VariantClear(&arg);
    return hr;
}

static HRESULT get_ui1_array_len(IDispatch *disp, LPCOLESTR name, LONG *out) {
    DISPID dispid;
    VARIANT result;
    DISPPARAMS dp;
    LONG lower = 0;
    LONG upper = -1;
    HRESULT hr;

    if (!out) return E_POINTER;
    *out = 0;
    hr = get_dispid(disp, name, &dispid);
    if (FAILED(hr)) return hr;
    memset(&dp, 0, sizeof(dp));
    VariantInit(&result);
    hr = IDispatch_Invoke(
        disp, dispid, &IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_PROPERTYGET,
        &dp, &result, NULL, NULL);
    if (SUCCEEDED(hr)) {
        if (V_VT(&result) != (VT_ARRAY | VT_UI1) || !V_ARRAY(&result)) {
            hr = DISP_E_TYPEMISMATCH;
        } else if (SafeArrayGetDim(V_ARRAY(&result)) != 1) {
            hr = DISP_E_TYPEMISMATCH;
        } else {
            hr = SafeArrayGetLBound(V_ARRAY(&result), 1, &lower);
            if (SUCCEEDED(hr)) hr = SafeArrayGetUBound(V_ARRAY(&result), 1, &upper);
            if (SUCCEEDED(hr)) *out = upper >= lower ? upper - lower + 1 : 0;
        }
    }
    VariantClear(&result);
    return hr;
}

static HRESULT call_method0(IDispatch *disp, LPCOLESTR name) {
    DISPID dispid;
    DISPPARAMS dp;
    HRESULT hr = get_dispid(disp, name, &dispid);
    if (FAILED(hr)) return hr;
    memset(&dp, 0, sizeof(dp));
    return IDispatch_Invoke(
        disp, dispid, &IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_METHOD,
        &dp, NULL, NULL, NULL);
}

static HRESULT call_method_i4(IDispatch *disp, LPCOLESTR name, LONG value) {
    DISPID dispid;
    VARIANT arg;
    DISPPARAMS dp;
    HRESULT hr = get_dispid(disp, name, &dispid);
    if (FAILED(hr)) return hr;
    VariantInit(&arg);
    V_VT(&arg) = VT_I4;
    V_I4(&arg) = value;
    dp.rgvarg = &arg;
    dp.rgdispidNamedArgs = NULL;
    dp.cArgs = 1;
    dp.cNamedArgs = 0;
    return IDispatch_Invoke(
        disp, dispid, &IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_METHOD,
        &dp, NULL, NULL, NULL);
}

static HRESULT call_method_i4_i4(IDispatch *disp, LPCOLESTR name, LONG first, LONG second) {
    DISPID dispid;
    VARIANT args[2];
    DISPPARAMS dp;
    HRESULT hr = get_dispid(disp, name, &dispid);
    if (FAILED(hr)) return hr;
    VariantInit(&args[0]);
    VariantInit(&args[1]);
    V_VT(&args[0]) = VT_I4;
    V_I4(&args[0]) = second;
    V_VT(&args[1]) = VT_I4;
    V_I4(&args[1]) = first;
    dp.rgvarg = args;
    dp.rgdispidNamedArgs = NULL;
    dp.cArgs = 2;
    dp.cNamedArgs = 0;
    return IDispatch_Invoke(
        disp, dispid, &IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_METHOD,
        &dp, NULL, NULL, NULL);
}

static HRESULT put_bstr(IDispatch *disp, LPCOLESTR name, LPCOLESTR value) {
    DISPID dispid;
    DISPID named = DISPID_PROPERTYPUT;
    VARIANT arg;
    DISPPARAMS dp;
    HRESULT hr = get_dispid(disp, name, &dispid);
    if (FAILED(hr)) return hr;
    VariantInit(&arg);
    V_VT(&arg) = VT_BSTR;
    V_BSTR(&arg) = SysAllocString(value);
    if (!V_BSTR(&arg)) return E_OUTOFMEMORY;
    dp.rgvarg = &arg;
    dp.rgdispidNamedArgs = &named;
    dp.cArgs = 1;
    dp.cNamedArgs = 1;
    hr = IDispatch_Invoke(
        disp, dispid, &IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_PROPERTYPUT,
        &dp, NULL, NULL, NULL);
    VariantClear(&arg);
    return hr;
}

static HRESULT get_bstr(IDispatch *disp, LPCOLESTR name, BSTR *out) {
    DISPID dispid;
    VARIANT result;
    VARIANT tmp;
    DISPPARAMS dp;
    HRESULT hr;

    if (!out) return E_POINTER;
    *out = NULL;
    hr = get_dispid(disp, name, &dispid);
    if (FAILED(hr)) return hr;
    memset(&dp, 0, sizeof(dp));
    VariantInit(&result);
    VariantInit(&tmp);
    hr = IDispatch_Invoke(
        disp, dispid, &IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_PROPERTYGET,
        &dp, &result, NULL, NULL);
    if (SUCCEEDED(hr)) hr = VariantChangeType(&tmp, &result, 0, VT_BSTR);
    if (SUCCEEDED(hr)) {
        BSTR value = V_BSTR(&tmp);
        UINT len = value ? SysStringLen(value) : 0;
        *out = SysAllocStringLen(value ? value : L"", len);
        if (!*out && len > 0) hr = E_OUTOFMEMORY;
    }
    VariantClear(&result);
    VariantClear(&tmp);
    return hr;
}

static HRESULT put_text_matrix(IDispatch *disp, LONG row, LONG col, LPCOLESTR value) {
    DISPID dispid;
    DISPID named = DISPID_PROPERTYPUT;
    VARIANT args[3];
    DISPPARAMS dp;
    HRESULT hr = get_dispid(disp, L"TextMatrix", &dispid);
    if (FAILED(hr)) return hr;
    VariantInit(&args[0]);
    VariantInit(&args[1]);
    VariantInit(&args[2]);
    V_VT(&args[0]) = VT_BSTR;
    V_BSTR(&args[0]) = SysAllocString(value);
    V_VT(&args[1]) = VT_I4;
    V_I4(&args[1]) = col;
    V_VT(&args[2]) = VT_I4;
    V_I4(&args[2]) = row;
    if (!V_BSTR(&args[0])) return E_OUTOFMEMORY;
    dp.rgvarg = args;
    dp.rgdispidNamedArgs = &named;
    dp.cArgs = 3;
    dp.cNamedArgs = 1;
    hr = IDispatch_Invoke(
        disp, dispid, &IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_PROPERTYPUT,
        &dp, NULL, NULL, NULL);
    VariantClear(&args[0]);
    return hr;
}

static HRESULT get_text_matrix(IDispatch *disp, LONG row, LONG col, BSTR *out) {
    DISPID dispid;
    VARIANT args[2];
    VARIANT result;
    VARIANT tmp;
    DISPPARAMS dp;
    HRESULT hr = get_dispid(disp, L"TextMatrix", &dispid);
    if (!out) return E_POINTER;
    *out = NULL;
    if (FAILED(hr)) return hr;
    VariantInit(&args[0]);
    VariantInit(&args[1]);
    V_VT(&args[0]) = VT_I4;
    V_I4(&args[0]) = col;
    V_VT(&args[1]) = VT_I4;
    V_I4(&args[1]) = row;
    dp.rgvarg = args;
    dp.rgdispidNamedArgs = NULL;
    dp.cArgs = 2;
    dp.cNamedArgs = 0;
    VariantInit(&result);
    VariantInit(&tmp);
    hr = IDispatch_Invoke(
        disp, dispid, &IID_NULL, LOCALE_USER_DEFAULT, DISPATCH_PROPERTYGET,
        &dp, &result, NULL, NULL);
    if (FAILED(hr)) return hr;
    hr = VariantChangeType(&tmp, &result, 0, VT_BSTR);
    if (SUCCEEDED(hr)) {
        *out = SysAllocString(V_BSTR(&tmp) ? V_BSTR(&tmp) : L"");
        hr = *out ? S_OK : E_OUTOFMEMORY;
    }
    VariantClear(&result);
    VariantClear(&tmp);
    return hr;
}

typedef struct ProbeAdoRecordset ProbeAdoRecordset;

typedef struct ProbeAdoFields {
    IDispatchVtbl *lpVtbl;
    LONG refs;
    LONG count;
    LONG current_index;
    ProbeAdoRecordset *recordset;
} ProbeAdoFields;

struct ProbeAdoRecordset {
    IDispatchVtbl *lpVtbl;
    LONG refs;
    ProbeAdoFields *fields;
    LONG absolute_position;
    LONG record_count;
    LONG move_first_calls;
    LONG move_next_calls;
    int fail_fields;
    int fail_move_next;
};

typedef struct ProbeAdoSource {
    IDispatchVtbl *lpVtbl;
    LONG refs;
    ProbeAdoFields *fields;
    ProbeAdoRecordset *recordset;
} ProbeAdoSource;

#define PROBE_ADO_DISPID_FIELDS            1
#define PROBE_ADO_DISPID_COUNT             2
#define PROBE_ADO_DISPID_RECORDCOUNT       3
#define PROBE_ADO_DISPID_EOF               4
#define PROBE_ADO_DISPID_MOVEFIRST         5
#define PROBE_ADO_DISPID_MOVENEXT          6
#define PROBE_ADO_DISPID_ABSOLUTEPOSITION  7
#define PROBE_ADO_DISPID_RECORDSET         8
#define PROBE_ADO_DISPID_ITEM              9
#define PROBE_ADO_DISPID_NAME              10
#define PROBE_ADO_DISPID_TYPE              11
#define PROBE_ADO_DISPID_VALUE             12

static IDispatchVtbl g_probe_ado_recordset_vtbl;
static IDispatchVtbl g_probe_ado_fields_vtbl;
static IDispatchVtbl g_probe_ado_source_vtbl;

static HRESULT probe_ado_name_to_dispid(LPOLESTR name, DISPID *out) {
    if (!name || !out) return E_POINTER;
    if (lstrcmpiW(name, L"Fields") == 0) {
        *out = PROBE_ADO_DISPID_FIELDS;
    } else if (lstrcmpiW(name, L"Count") == 0) {
        *out = PROBE_ADO_DISPID_COUNT;
    } else if (lstrcmpiW(name, L"RecordCount") == 0) {
        *out = PROBE_ADO_DISPID_RECORDCOUNT;
    } else if (lstrcmpiW(name, L"EOF") == 0) {
        *out = PROBE_ADO_DISPID_EOF;
    } else if (lstrcmpiW(name, L"MoveFirst") == 0) {
        *out = PROBE_ADO_DISPID_MOVEFIRST;
    } else if (lstrcmpiW(name, L"MoveNext") == 0) {
        *out = PROBE_ADO_DISPID_MOVENEXT;
    } else if (lstrcmpiW(name, L"AbsolutePosition") == 0) {
        *out = PROBE_ADO_DISPID_ABSOLUTEPOSITION;
    } else if (lstrcmpiW(name, L"Recordset") == 0) {
        *out = PROBE_ADO_DISPID_RECORDSET;
    } else if (lstrcmpiW(name, L"Item") == 0) {
        *out = PROBE_ADO_DISPID_ITEM;
    } else if (lstrcmpiW(name, L"Name") == 0) {
        *out = PROBE_ADO_DISPID_NAME;
    } else if (lstrcmpiW(name, L"Type") == 0) {
        *out = PROBE_ADO_DISPID_TYPE;
    } else if (lstrcmpiW(name, L"Value") == 0) {
        *out = PROBE_ADO_DISPID_VALUE;
    } else {
        *out = DISPID_UNKNOWN;
        return DISP_E_UNKNOWNNAME;
    }
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE probe_ado_qi(IDispatch *This, REFIID riid, void **ppv) {
    if (!ppv) return E_POINTER;
    if (IsEqualIID(riid, &IID_IUnknown) || IsEqualIID(riid, &IID_IDispatch)) {
        *ppv = This;
        IDispatch_AddRef(This);
        return S_OK;
    }
    *ppv = NULL;
    return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE probe_ado_recordset_addref(IDispatch *This) {
    return InterlockedIncrement(&((ProbeAdoRecordset *)This)->refs);
}

static ULONG STDMETHODCALLTYPE probe_ado_recordset_release(IDispatch *This) {
    ProbeAdoRecordset *rs = (ProbeAdoRecordset *)This;
    LONG refs = InterlockedDecrement(&rs->refs);
    if (refs == 0) {
        if (rs->fields) IDispatch_Release((IDispatch *)rs->fields);
        HeapFree(GetProcessHeap(), 0, rs);
    }
    return refs;
}

static ULONG STDMETHODCALLTYPE probe_ado_fields_addref(IDispatch *This) {
    return InterlockedIncrement(&((ProbeAdoFields *)This)->refs);
}

static ULONG STDMETHODCALLTYPE probe_ado_fields_release(IDispatch *This) {
    ProbeAdoFields *fields = (ProbeAdoFields *)This;
    LONG refs = InterlockedDecrement(&fields->refs);
    if (refs == 0) HeapFree(GetProcessHeap(), 0, fields);
    return refs;
}

static ULONG STDMETHODCALLTYPE probe_ado_source_addref(IDispatch *This) {
    return InterlockedIncrement(&((ProbeAdoSource *)This)->refs);
}

static ULONG STDMETHODCALLTYPE probe_ado_source_release(IDispatch *This) {
    ProbeAdoSource *source = (ProbeAdoSource *)This;
    LONG refs = InterlockedDecrement(&source->refs);
    if (refs == 0) {
        if (source->fields) IDispatch_Release((IDispatch *)source->fields);
        if (source->recordset) IDispatch_Release((IDispatch *)source->recordset);
        HeapFree(GetProcessHeap(), 0, source);
    }
    return refs;
}

static HRESULT STDMETHODCALLTYPE probe_ado_get_type_info_count(IDispatch *This, UINT *pctinfo) {
    (void)This;
    if (pctinfo) *pctinfo = 0;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE probe_ado_get_type_info(
    IDispatch *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo)
{
    (void)This;
    (void)iTInfo;
    (void)lcid;
    if (ppTInfo) *ppTInfo = NULL;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE probe_ado_get_ids_of_names(
    IDispatch *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid,
    DISPID *rgDispId)
{
    (void)This;
    (void)riid;
    (void)lcid;
    if (!rgszNames || !rgDispId || cNames == 0) return E_POINTER;
    return probe_ado_name_to_dispid(rgszNames[0], rgDispId);
}

static HRESULT STDMETHODCALLTYPE probe_ado_recordset_invoke(
    IDispatch *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags,
    DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo,
    UINT *puArgErr)
{
    ProbeAdoRecordset *rs = (ProbeAdoRecordset *)This;
    (void)riid;
    (void)lcid;
    if (pExcepInfo) memset(pExcepInfo, 0, sizeof(*pExcepInfo));
    if (puArgErr) *puArgErr = 0;
    if (pVarResult) VariantInit(pVarResult);

    switch (dispIdMember) {
    case PROBE_ADO_DISPID_FIELDS:
        if (rs->fail_fields) return E_FAIL;
        if (!(wFlags & DISPATCH_PROPERTYGET) || !pVarResult || !rs->fields) return DISP_E_MEMBERNOTFOUND;
        V_VT(pVarResult) = VT_DISPATCH;
        V_DISPATCH(pVarResult) = (IDispatch *)rs->fields;
        IDispatch_AddRef(V_DISPATCH(pVarResult));
        return S_OK;
    case PROBE_ADO_DISPID_RECORDCOUNT:
        if (!(wFlags & DISPATCH_PROPERTYGET) || !pVarResult) return DISP_E_MEMBERNOTFOUND;
        V_VT(pVarResult) = VT_I4;
        V_I4(pVarResult) = rs->record_count;
        return S_OK;
    case PROBE_ADO_DISPID_EOF:
        if (!(wFlags & DISPATCH_PROPERTYGET) || !pVarResult) return DISP_E_MEMBERNOTFOUND;
        V_VT(pVarResult) = VT_BOOL;
        V_BOOL(pVarResult) =
            (rs->record_count <= 0 || rs->absolute_position > rs->record_count)
                ? VARIANT_TRUE
                : VARIANT_FALSE;
        return S_OK;
    case PROBE_ADO_DISPID_ABSOLUTEPOSITION:
        if (wFlags & DISPATCH_PROPERTYGET) {
            if (!pVarResult) return E_POINTER;
            V_VT(pVarResult) = VT_I4;
            V_I4(pVarResult) = rs->absolute_position;
            return S_OK;
        }
        if (wFlags & (DISPATCH_PROPERTYPUT | DISPATCH_PROPERTYPUTREF)) {
            VARIANT tmp;
            HRESULT hr;
            if (!pDispParams || pDispParams->cArgs < 1 || !pDispParams->rgvarg) return DISP_E_BADPARAMCOUNT;
            VariantInit(&tmp);
            hr = VariantChangeType(&tmp, &pDispParams->rgvarg[0], 0, VT_I4);
            if (SUCCEEDED(hr)) rs->absolute_position = V_I4(&tmp);
            VariantClear(&tmp);
            return hr;
        }
        return DISP_E_MEMBERNOTFOUND;
    case PROBE_ADO_DISPID_MOVEFIRST:
        if (!(wFlags & DISPATCH_METHOD)) return DISP_E_MEMBERNOTFOUND;
        rs->move_first_calls++;
        rs->absolute_position = rs->record_count > 0 ? 1 : 0;
        return S_OK;
    case PROBE_ADO_DISPID_MOVENEXT:
        if (!(wFlags & DISPATCH_METHOD)) return DISP_E_MEMBERNOTFOUND;
        rs->move_next_calls++;
        if (rs->fail_move_next) return E_FAIL;
        if (rs->absolute_position > 0) rs->absolute_position++;
        return S_OK;
    default:
        return DISP_E_MEMBERNOTFOUND;
    }
}

static HRESULT STDMETHODCALLTYPE probe_ado_fields_invoke(
    IDispatch *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags,
    DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo,
    UINT *puArgErr)
{
    ProbeAdoFields *fields = (ProbeAdoFields *)This;
    (void)riid;
    (void)lcid;
    if (pExcepInfo) memset(pExcepInfo, 0, sizeof(*pExcepInfo));
    if (puArgErr) *puArgErr = 0;
    if (pVarResult) VariantInit(pVarResult);
    if (dispIdMember == PROBE_ADO_DISPID_COUNT && (wFlags & DISPATCH_PROPERTYGET)) {
        if (!pVarResult) return E_POINTER;
        V_VT(pVarResult) = VT_I4;
        V_I4(pVarResult) = fields->count;
        return S_OK;
    }
    if (dispIdMember == PROBE_ADO_DISPID_ITEM && (wFlags & DISPATCH_PROPERTYGET)) {
        VARIANT tmp;
        HRESULT hr;
        if (!pVarResult || !pDispParams || pDispParams->cArgs < 1 || !pDispParams->rgvarg) {
            return DISP_E_BADPARAMCOUNT;
        }
        VariantInit(&tmp);
        hr = VariantChangeType(&tmp, &pDispParams->rgvarg[0], 0, VT_I4);
        if (SUCCEEDED(hr)) fields->current_index = V_I4(&tmp);
        VariantClear(&tmp);
        if (FAILED(hr)) return hr;
        V_VT(pVarResult) = VT_DISPATCH;
        V_DISPATCH(pVarResult) = This;
        IDispatch_AddRef(This);
        return S_OK;
    }
    if (dispIdMember == PROBE_ADO_DISPID_NAME && (wFlags & DISPATCH_PROPERTYGET)) {
        WCHAR name[32];
        if (!pVarResult) return E_POINTER;
        wsprintfW(name, L"F%ld", fields->current_index);
        V_VT(pVarResult) = VT_BSTR;
        V_BSTR(pVarResult) = SysAllocString(name);
        return V_BSTR(pVarResult) ? S_OK : E_OUTOFMEMORY;
    }
    if (dispIdMember == PROBE_ADO_DISPID_TYPE && (wFlags & DISPATCH_PROPERTYGET)) {
        if (!pVarResult) return E_POINTER;
        V_VT(pVarResult) = VT_I4;
        V_I4(pVarResult) = 8;
        return S_OK;
    }
    if (dispIdMember == PROBE_ADO_DISPID_VALUE && (wFlags & DISPATCH_PROPERTYGET)) {
        WCHAR value[64];
        LONG pos = fields->recordset ? fields->recordset->absolute_position : 0;
        if (!pVarResult) return E_POINTER;
        wsprintfW(value, L"R%ldC%ld", pos, fields->current_index);
        V_VT(pVarResult) = VT_BSTR;
        V_BSTR(pVarResult) = SysAllocString(value);
        return V_BSTR(pVarResult) ? S_OK : E_OUTOFMEMORY;
    }
    return DISP_E_MEMBERNOTFOUND;
}

static HRESULT STDMETHODCALLTYPE probe_ado_source_invoke(
    IDispatch *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags,
    DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo,
    UINT *puArgErr)
{
    ProbeAdoSource *source = (ProbeAdoSource *)This;
    (void)riid;
    (void)lcid;
    (void)pDispParams;
    if (pExcepInfo) memset(pExcepInfo, 0, sizeof(*pExcepInfo));
    if (puArgErr) *puArgErr = 0;
    if (pVarResult) VariantInit(pVarResult);
    if (!(wFlags & DISPATCH_PROPERTYGET) || !pVarResult) return DISP_E_MEMBERNOTFOUND;
    switch (dispIdMember) {
    case PROBE_ADO_DISPID_FIELDS:
        if (!source->fields) return E_FAIL;
        V_VT(pVarResult) = VT_DISPATCH;
        V_DISPATCH(pVarResult) = (IDispatch *)source->fields;
        IDispatch_AddRef(V_DISPATCH(pVarResult));
        return S_OK;
    case PROBE_ADO_DISPID_RECORDSET:
        if (!source->recordset) return E_FAIL;
        V_VT(pVarResult) = VT_DISPATCH;
        V_DISPATCH(pVarResult) = (IDispatch *)source->recordset;
        IDispatch_AddRef(V_DISPATCH(pVarResult));
        return S_OK;
    default:
        return DISP_E_MEMBERNOTFOUND;
    }
}

static IDispatchVtbl g_probe_ado_recordset_vtbl = {
    probe_ado_qi,
    probe_ado_recordset_addref,
    probe_ado_recordset_release,
    probe_ado_get_type_info_count,
    probe_ado_get_type_info,
    probe_ado_get_ids_of_names,
    probe_ado_recordset_invoke
};

static IDispatchVtbl g_probe_ado_fields_vtbl = {
    probe_ado_qi,
    probe_ado_fields_addref,
    probe_ado_fields_release,
    probe_ado_get_type_info_count,
    probe_ado_get_type_info,
    probe_ado_get_ids_of_names,
    probe_ado_fields_invoke
};

static IDispatchVtbl g_probe_ado_source_vtbl = {
    probe_ado_qi,
    probe_ado_source_addref,
    probe_ado_source_release,
    probe_ado_get_type_info_count,
    probe_ado_get_type_info,
    probe_ado_get_ids_of_names,
    probe_ado_source_invoke
};

static IDispatch *probe_ado_recordset_create_config(
    int fail_fields,
    LONG record_count,
    LONG fields_count,
    int fail_move_next,
    ProbeAdoRecordset **out_recordset)
{
    ProbeAdoRecordset *rs = (ProbeAdoRecordset *)HeapAlloc(
        GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*rs));
    ProbeAdoFields *fields = (ProbeAdoFields *)HeapAlloc(
        GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*fields));
    if (out_recordset) *out_recordset = NULL;
    if (!rs || !fields) {
        if (rs) HeapFree(GetProcessHeap(), 0, rs);
        if (fields) HeapFree(GetProcessHeap(), 0, fields);
        return NULL;
    }
    rs->lpVtbl = &g_probe_ado_recordset_vtbl;
    rs->refs = 1;
    rs->fields = fields;
    rs->absolute_position = 0;
    rs->record_count = record_count;
    rs->fail_fields = fail_fields ? 1 : 0;
    rs->fail_move_next = fail_move_next ? 1 : 0;
    fields->lpVtbl = &g_probe_ado_fields_vtbl;
    fields->refs = 1;
    fields->count = fields_count;
    fields->current_index = 0;
    fields->recordset = rs;
    if (out_recordset) *out_recordset = rs;
    return (IDispatch *)rs;
}

static IDispatch *probe_ado_recordset_create(void) {
    return probe_ado_recordset_create_config(0, 0, 0, 0, NULL);
}

static IDispatch *probe_ado_virtual_recordset_create(ProbeAdoRecordset **out_recordset) {
    return probe_ado_recordset_create_config(0, 20000, 1, 1, out_recordset);
}

static IDispatch *probe_ado_failing_source_create(void) {
    ProbeAdoSource *source = (ProbeAdoSource *)HeapAlloc(
        GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*source));
    ProbeAdoFields *fields = (ProbeAdoFields *)HeapAlloc(
        GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*fields));
    IDispatch *failing_rs = probe_ado_recordset_create_config(1, 0, 0, 0, NULL);
    if (!source || !fields || !failing_rs) {
        if (source) HeapFree(GetProcessHeap(), 0, source);
        if (fields) HeapFree(GetProcessHeap(), 0, fields);
        if (failing_rs) IDispatch_Release(failing_rs);
        return NULL;
    }
    source->lpVtbl = &g_probe_ado_source_vtbl;
    source->refs = 1;
    source->fields = fields;
    source->recordset = (ProbeAdoRecordset *)failing_rs;
    fields->lpVtbl = &g_probe_ado_fields_vtbl;
    fields->refs = 1;
    fields->count = 0;
    return (IDispatch *)source;
}

static HRESULT STDMETHODCALLTYPE event_sink_qi(IDispatch *This, REFIID riid, void **ppv) {
    if (!ppv) return E_POINTER;
    if (IsEqualIID(riid, &IID_IUnknown) || IsEqualIID(riid, &IID_IDispatch)) {
        *ppv = This;
        IDispatch_AddRef(This);
        return S_OK;
    }
    *ppv = NULL;
    return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE event_sink_addref(IDispatch *This) {
    return InterlockedIncrement(&((ProbeEventSink *)This)->refs);
}

static ULONG STDMETHODCALLTYPE event_sink_release(IDispatch *This) {
    return InterlockedDecrement(&((ProbeEventSink *)This)->refs);
}

static HRESULT STDMETHODCALLTYPE event_sink_get_type_info_count(IDispatch *This, UINT *pctinfo) {
    (void)This;
    if (pctinfo) *pctinfo = 0;
    return S_OK;
}

static HRESULT STDMETHODCALLTYPE event_sink_get_type_info(
    IDispatch *This, UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo)
{
    (void)This;
    (void)iTInfo;
    (void)lcid;
    if (ppTInfo) *ppTInfo = NULL;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE event_sink_get_ids_of_names(
    IDispatch *This, REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid,
    DISPID *rgDispId)
{
    (void)This;
    (void)riid;
    (void)rgszNames;
    (void)cNames;
    (void)lcid;
    (void)rgDispId;
    return E_NOTIMPL;
}

static HRESULT STDMETHODCALLTYPE event_sink_invoke(
    IDispatch *This, DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags,
    DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo,
    UINT *puArgErr)
{
    ProbeEventSink *sink = (ProbeEventSink *)This;
    (void)riid;
    (void)lcid;
    (void)wFlags;
    if (pVarResult) VariantInit(pVarResult);
    if (pExcepInfo) memset(pExcepInfo, 0, sizeof(*pExcepInfo));
    if (puArgErr) *puArgErr = 0;

    switch (dispIdMember) {
    case DISPID_VFG_EVT_SELCHANGE:
        sink->sel_change++;
        if (pDispParams && pDispParams->cArgs != 0) sink->arg_mismatch++;
        break;
    case DISPID_VFG_EVT_BEFOREROWCOLCHANGE:
        sink->before_row_col++;
        if (!pDispParams || pDispParams->cArgs != 5 || !pDispParams->rgvarg ||
            pDispParams->rgvarg[0].vt != (VT_BYREF | VT_BOOL) ||
            !pDispParams->rgvarg[0].pboolVal) {
            sink->arg_mismatch++;
            break;
        }
        if (sink->cancel_dispid == dispIdMember) {
            *pDispParams->rgvarg[0].pboolVal = VARIANT_TRUE;
            sink->cancel_dispid = DISPID_UNKNOWN;
        }
        break;
    case DISPID_VFG_EVT_AFTERROWCOLCHANGE:
        sink->after_row_col++;
        if (!pDispParams || pDispParams->cArgs != 4 || !pDispParams->rgvarg) {
            sink->arg_mismatch++;
        }
        break;
    case DISPID_VFG_EVT_ROWCOLCHANGE:
        sink->row_col_change++;
        if (pDispParams && pDispParams->cArgs != 0) sink->arg_mismatch++;
        break;
    case DISPID_VFG_EVT_BEFORESELCHANGE:
        sink->before_sel++;
        if (!pDispParams || pDispParams->cArgs != 5 || !pDispParams->rgvarg ||
            pDispParams->rgvarg[0].vt != (VT_BYREF | VT_BOOL) ||
            !pDispParams->rgvarg[0].pboolVal) {
            sink->arg_mismatch++;
            break;
        }
        if (sink->cancel_dispid == dispIdMember) {
            *pDispParams->rgvarg[0].pboolVal = VARIANT_TRUE;
            sink->cancel_dispid = DISPID_UNKNOWN;
        }
        break;
    case DISPID_VFG_EVT_AFTERSELCHANGE:
        sink->after_sel++;
        if (!pDispParams || pDispParams->cArgs != 4 || !pDispParams->rgvarg) {
            sink->arg_mismatch++;
        }
        break;
    case DISPID_VFG_EVT_BEFORESCROLL:
        sink->before_scroll++;
        if (!pDispParams || pDispParams->cArgs != 5 || !pDispParams->rgvarg ||
            pDispParams->rgvarg[0].vt != (VT_BYREF | VT_BOOL) ||
            !pDispParams->rgvarg[0].pboolVal) {
            sink->arg_mismatch++;
            break;
        }
        if (sink->cancel_dispid == dispIdMember) {
            *pDispParams->rgvarg[0].pboolVal = VARIANT_TRUE;
            sink->cancel_dispid = DISPID_UNKNOWN;
        }
        break;
    case DISPID_VFG_EVT_AFTERSCROLL:
        sink->after_scroll++;
        if (!pDispParams || pDispParams->cArgs != 4 || !pDispParams->rgvarg) {
            sink->arg_mismatch++;
        }
        break;
    case DISPID_VFG_EVT_BEFORESORT:
        sink->before_sort++;
        if (!pDispParams || pDispParams->cArgs != 2 || !pDispParams->rgvarg ||
            pDispParams->rgvarg[0].vt != (VT_BYREF | VT_I2)) {
            sink->arg_mismatch++;
        }
        break;
    case DISPID_VFG_EVT_AFTERSORT:
        sink->after_sort++;
        if (!pDispParams || pDispParams->cArgs != 2 || !pDispParams->rgvarg) {
            sink->arg_mismatch++;
        }
        break;
    case DISPID_VFG_EVT_BEFOREMOVECOLUMN:
        sink->before_move_col++;
        if (!pDispParams || pDispParams->cArgs != 2 || !pDispParams->rgvarg ||
            pDispParams->rgvarg[0].vt != (VT_BYREF | VT_I4)) {
            sink->arg_mismatch++;
        }
        break;
    case DISPID_VFG_EVT_AFTERMOVECOLUMN:
        sink->after_move_col++;
        if (!pDispParams || pDispParams->cArgs != 2 || !pDispParams->rgvarg) {
            sink->arg_mismatch++;
        }
        break;
    case DISPID_VFG_EVT_BEFOREMOVEROW:
        sink->before_move_row++;
        if (!pDispParams || pDispParams->cArgs != 2 || !pDispParams->rgvarg ||
            pDispParams->rgvarg[0].vt != (VT_BYREF | VT_I4)) {
            sink->arg_mismatch++;
        }
        break;
    case DISPID_VFG_EVT_AFTERMOVEROW:
        sink->after_move_row++;
        if (!pDispParams || pDispParams->cArgs != 2 || !pDispParams->rgvarg) {
            sink->arg_mismatch++;
        }
        break;
    case DISPID_VFG_EVT_BEFOREUSERRESIZE:
        sink->before_resize++;
        if (!pDispParams || pDispParams->cArgs != 3 || !pDispParams->rgvarg ||
            pDispParams->rgvarg[0].vt != (VT_BYREF | VT_BOOL) ||
            !pDispParams->rgvarg[0].pboolVal) {
            sink->arg_mismatch++;
            break;
        }
        if (sink->cancel_dispid == dispIdMember) {
            *pDispParams->rgvarg[0].pboolVal = VARIANT_TRUE;
            sink->cancel_dispid = DISPID_UNKNOWN;
        }
        break;
    case DISPID_VFG_EVT_AFTERUSERRESIZE:
        sink->after_resize++;
        if (!pDispParams || pDispParams->cArgs != 2 || !pDispParams->rgvarg) {
            sink->arg_mismatch++;
        }
        break;
    case DISPID_VFG_EVT_BEFORECOLLAPSE:
        sink->before_collapse++;
        if (!pDispParams || pDispParams->cArgs != 3 || !pDispParams->rgvarg ||
            pDispParams->rgvarg[0].vt != (VT_BYREF | VT_BOOL) ||
            !pDispParams->rgvarg[0].pboolVal) {
            sink->arg_mismatch++;
            break;
        }
        if (sink->cancel_dispid == dispIdMember) {
            *pDispParams->rgvarg[0].pboolVal = VARIANT_TRUE;
            sink->cancel_dispid = DISPID_UNKNOWN;
        }
        break;
    case DISPID_VFG_EVT_AFTERCOLLAPSE:
        sink->after_collapse++;
        if (!pDispParams || pDispParams->cArgs != 2 || !pDispParams->rgvarg) {
            sink->arg_mismatch++;
        }
        break;
    case DISPID_VFG_EVT_BEFOREEDIT:
        sink->before_edit++;
        if (!pDispParams || pDispParams->cArgs != 3 || !pDispParams->rgvarg ||
            pDispParams->rgvarg[0].vt != (VT_BYREF | VT_BOOL) ||
            !pDispParams->rgvarg[0].pboolVal) {
            sink->arg_mismatch++;
        }
        break;
    case DISPID_VFG_EVT_STARTEDIT:
        sink->start_edit++;
        if (!pDispParams || pDispParams->cArgs != 3 || !pDispParams->rgvarg ||
            pDispParams->rgvarg[0].vt != (VT_BYREF | VT_BOOL)) {
            sink->arg_mismatch++;
        }
        break;
    case DISPID_VFG_EVT_AFTEREDIT:
        sink->after_edit++;
        if (!pDispParams || pDispParams->cArgs != 2 || !pDispParams->rgvarg) {
            sink->arg_mismatch++;
        }
        break;
    case DISPID_VFG_EVT_AFTERUSERFREEZE:
        sink->after_user_freeze++;
        if (pDispParams && pDispParams->cArgs != 0) sink->arg_mismatch++;
        break;
    case DISPID_VFG_EVT_CELLCHANGED:
        sink->cell_changed++;
        if (!pDispParams || pDispParams->cArgs != 2 || !pDispParams->rgvarg) {
            sink->arg_mismatch++;
        }
        break;
    case DISPID_VFG_EVT_BEFOREDATAREFRESH:
        sink->before_data_refresh++;
        if (!pDispParams || pDispParams->cArgs != 1 || !pDispParams->rgvarg ||
            pDispParams->rgvarg[0].vt != (VT_BYREF | VT_BOOL) ||
            !pDispParams->rgvarg[0].pboolVal) {
            sink->arg_mismatch++;
            break;
        }
        if (sink->cancel_dispid == dispIdMember) {
            *pDispParams->rgvarg[0].pboolVal = VARIANT_TRUE;
            sink->cancel_dispid = DISPID_UNKNOWN;
        }
        break;
    case DISPID_VFG_EVT_AFTERDATAREFRESH:
        sink->after_data_refresh++;
        if (pDispParams && pDispParams->cArgs != 0) sink->arg_mismatch++;
        break;
    case DISPID_VFG_EVT_OLESTARTDRAG:
        sink->ole_start_drag++;
        if (!pDispParams || pDispParams->cArgs != 2 || !pDispParams->rgvarg ||
            pDispParams->rgvarg[1].vt != VT_UNKNOWN ||
            pDispParams->rgvarg[0].vt != (VT_BYREF | VT_I4) ||
            !pDispParams->rgvarg[0].plVal) {
            sink->arg_mismatch++;
            break;
        }
        if (sink->cancel_dispid == dispIdMember) {
            *pDispParams->rgvarg[0].plVal = 0;
            sink->cancel_dispid = DISPID_UNKNOWN;
        }
        break;
    case DISPID_VFG_EVT_OLEGIVEFEEDBACK:
        sink->ole_give_feedback++;
        if (!pDispParams || pDispParams->cArgs != 2 || !pDispParams->rgvarg ||
            pDispParams->rgvarg[1].vt != VT_I4 ||
            pDispParams->rgvarg[0].vt != (VT_BYREF | VT_BOOL) ||
            !pDispParams->rgvarg[0].pboolVal) {
            sink->arg_mismatch++;
        }
        break;
    case DISPID_VFG_EVT_OLECOMPLETEDRAG:
        sink->ole_complete_drag++;
        if (!pDispParams || pDispParams->cArgs != 1 || !pDispParams->rgvarg ||
            pDispParams->rgvarg[0].vt != VT_I4) {
            sink->arg_mismatch++;
        }
        break;
    case DISPID_VFG_EVT_OLEDRAGOVER:
        sink->ole_drag_over++;
        if (!pDispParams || pDispParams->cArgs != 7 || !pDispParams->rgvarg ||
            pDispParams->rgvarg[6].vt != VT_UNKNOWN ||
            pDispParams->rgvarg[5].vt != (VT_BYREF | VT_I4) ||
            !pDispParams->rgvarg[5].plVal ||
            pDispParams->rgvarg[4].vt != VT_I4 ||
            pDispParams->rgvarg[3].vt != VT_I4 ||
            pDispParams->rgvarg[2].vt != VT_R4 ||
            pDispParams->rgvarg[1].vt != VT_R4 ||
            pDispParams->rgvarg[0].vt != VT_I4) {
            sink->arg_mismatch++;
            break;
        }
        if (pDispParams->rgvarg[0].lVal == 0) sink->ole_drag_enter_state++;
        else if (pDispParams->rgvarg[0].lVal == 1) sink->ole_drag_over_state++;
        else if (pDispParams->rgvarg[0].lVal == 2) sink->ole_drag_leave_state++;
        else sink->arg_mismatch++;
        break;
    case DISPID_VFG_EVT_OLEDRAGDROP:
        sink->ole_drag_drop++;
        if (!pDispParams || pDispParams->cArgs != 6 || !pDispParams->rgvarg ||
            pDispParams->rgvarg[5].vt != VT_UNKNOWN ||
            pDispParams->rgvarg[4].vt != (VT_BYREF | VT_I4) ||
            !pDispParams->rgvarg[4].plVal ||
            pDispParams->rgvarg[3].vt != VT_I4 ||
            pDispParams->rgvarg[2].vt != VT_I4 ||
            pDispParams->rgvarg[1].vt != VT_R4 ||
            pDispParams->rgvarg[0].vt != VT_R4) {
            sink->arg_mismatch++;
        }
        break;
    case DISPID_VFG_EVT_DRAWCELL: {
        HDC hdc;
        RECT rect;
        HBRUSH brush;

        sink->draw_cell++;
        if (!pDispParams || pDispParams->cArgs != 8 || !pDispParams->rgvarg ||
            pDispParams->rgvarg[7].vt != VT_I4 ||
            pDispParams->rgvarg[6].vt != VT_I4 ||
            pDispParams->rgvarg[5].vt != VT_I4 ||
            pDispParams->rgvarg[4].vt != VT_I4 ||
            pDispParams->rgvarg[3].vt != VT_I4 ||
            pDispParams->rgvarg[2].vt != VT_I4 ||
            pDispParams->rgvarg[1].vt != VT_I4 ||
            pDispParams->rgvarg[0].vt != (VT_BYREF | VT_BOOL) ||
            !pDispParams->rgvarg[0].pboolVal) {
            sink->arg_mismatch++;
            break;
        }

        hdc = (HDC)(LONG_PTR)pDispParams->rgvarg[7].lVal;
        rect.left = pDispParams->rgvarg[4].lVal;
        rect.top = pDispParams->rgvarg[3].lVal;
        rect.right = pDispParams->rgvarg[2].lVal;
        rect.bottom = pDispParams->rgvarg[1].lVal;
        if (!hdc || rect.right <= rect.left || rect.bottom <= rect.top ||
            GetObjectType((HGDIOBJ)hdc) == 0) {
            sink->arg_mismatch++;
            break;
        }

        if (sink->draw_cell == 1) {
            sink->draw_first_row = pDispParams->rgvarg[6].lVal;
            sink->draw_first_col = pDispParams->rgvarg[5].lVal;
            sink->draw_first_left = rect.left;
            sink->draw_first_top = rect.top;
            sink->draw_first_right = rect.right;
            sink->draw_first_bottom = rect.bottom;
        }

        brush = CreateSolidBrush(PROBE_OWNER_DRAW_COLOR);
        if (!brush) {
            sink->arg_mismatch++;
            break;
        }
        FillRect(hdc, &rect, brush);
        DeleteObject(brush);
        *pDispParams->rgvarg[0].pboolVal = VARIANT_TRUE;
        sink->draw_done_count++;
        break;
    }
    case DISPID_VFG_EVT_ERROR:
        sink->error_event++;
        if (!pDispParams || pDispParams->cArgs != 2 || !pDispParams->rgvarg ||
            pDispParams->rgvarg[0].vt != (VT_BYREF | VT_BOOL) ||
            !pDispParams->rgvarg[0].pboolVal ||
            pDispParams->rgvarg[1].vt != VT_I4) {
            sink->arg_mismatch++;
        }
        break;
    default:
        break;
    }
    return S_OK;
}

static IDispatchVtbl g_event_sink_vtbl = {
    event_sink_qi,
    event_sink_addref,
    event_sink_release,
    event_sink_get_type_info_count,
    event_sink_get_type_info,
    event_sink_get_ids_of_names,
    event_sink_invoke
};

static void event_sink_reset(ProbeEventSink *sink) {
    if (!sink) return;
    sink->before_row_col = 0;
    sink->after_row_col = 0;
    sink->row_col_change = 0;
    sink->before_sel = 0;
    sink->after_sel = 0;
    sink->sel_change = 0;
    sink->before_scroll = 0;
    sink->after_scroll = 0;
    sink->before_sort = 0;
    sink->after_sort = 0;
    sink->before_move_col = 0;
    sink->after_move_col = 0;
    sink->before_move_row = 0;
    sink->after_move_row = 0;
    sink->before_resize = 0;
    sink->after_resize = 0;
    sink->before_collapse = 0;
    sink->after_collapse = 0;
    sink->before_edit = 0;
    sink->start_edit = 0;
    sink->after_edit = 0;
    sink->after_user_freeze = 0;
    sink->cell_changed = 0;
    sink->before_data_refresh = 0;
    sink->after_data_refresh = 0;
    sink->error_event = 0;
    sink->ole_start_drag = 0;
    sink->ole_give_feedback = 0;
    sink->ole_complete_drag = 0;
    sink->ole_drag_over = 0;
    sink->ole_drag_drop = 0;
    sink->ole_drag_enter_state = 0;
    sink->ole_drag_over_state = 0;
    sink->ole_drag_leave_state = 0;
    sink->draw_cell = 0;
    sink->draw_done_count = 0;
    sink->draw_first_row = -1;
    sink->draw_first_col = -1;
    sink->draw_first_left = -1;
    sink->draw_first_top = -1;
    sink->draw_first_right = -1;
    sink->draw_first_bottom = -1;
    sink->cancel_dispid = DISPID_UNKNOWN;
    sink->arg_mismatch = 0;
}

static HRESULT probe_event_contract(IDispatch *disp) {
    IConnectionPointContainer *cpc = NULL;
    IConnectionPoint *cp = NULL;
    IEnumConnectionPoints *cp_enum = NULL;
    IConnectionPoint *enum_cp = NULL;
    IEnumConnections *conn_enum = NULL;
    CONNECTDATA conn;
    ULONG fetched = 0;
    IID iid;
    ProbeEventSink sink;
    DWORD cookie = 0;
    IDispatch *probe_rs = NULL;
    IDispatch *virtual_rs = NULL;
    IDispatch *failing_source = NULL;
    ProbeAdoRecordset *virtual_rs_state = NULL;
    BSTR virtual_cell = NULL;
    LONG rows_after_virtual = -1;
    LONG row = -1;
    HRESULT hr;

    if (FAILED(hr = put_i4(disp, L"Rows", 4))) return hr;
    if (FAILED(hr = put_i4(disp, L"Cols", 4))) return hr;
    if (FAILED(hr = put_i4(disp, L"FixedRows", 0))) return hr;
    if (FAILED(hr = put_i4(disp, L"FixedCols", 0))) return hr;
    if (FAILED(hr = put_i4(disp, L"Row", 0))) return hr;
    if (FAILED(hr = put_i4(disp, L"Col", 0))) return hr;
    if (FAILED(hr = get_i4(disp, L"Row", &row))) return hr;
    if (row != 0) return E_FAIL;

    memset(&sink, 0, sizeof(sink));
    sink.lpVtbl = &g_event_sink_vtbl;
    sink.refs = 1;

    hr = IDispatch_QueryInterface(disp, &IID_IConnectionPointContainer, (void **)&cpc);
    if (FAILED(hr)) goto done;
    hr = IConnectionPointContainer_FindConnectionPoint(cpc, &DIID__DVolvoxGridEvents, &cp);
    if (FAILED(hr)) goto done;

    hr = IConnectionPointContainer_EnumConnectionPoints(cpc, &cp_enum);
    if (FAILED(hr)) goto done;
    hr = IEnumConnectionPoints_Next(cp_enum, 1, &enum_cp, &fetched);
    if (hr != S_OK || fetched != 1 || !enum_cp) {
        hr = E_FAIL;
        goto done;
    }
    memset(&iid, 0, sizeof(iid));
    hr = IConnectionPoint_GetConnectionInterface(enum_cp, &iid);
    if (FAILED(hr) || !IsEqualIID(&iid, &DIID__DVolvoxGridEvents)) {
        if (SUCCEEDED(hr)) hr = E_FAIL;
        goto done;
    }
    IConnectionPoint_Release(enum_cp);
    enum_cp = NULL;
    fetched = 1;
    hr = IEnumConnectionPoints_Next(cp_enum, 1, &enum_cp, &fetched);
    if (hr != S_FALSE || fetched != 0 || enum_cp) {
        hr = E_FAIL;
        goto done;
    }
    hr = IEnumConnectionPoints_Reset(cp_enum);
    if (FAILED(hr)) goto done;
    hr = IEnumConnectionPoints_Skip(cp_enum, 1);
    if (hr != S_OK) {
        if (SUCCEEDED(hr)) hr = E_FAIL;
        goto done;
    }
    IEnumConnectionPoints_Release(cp_enum);
    cp_enum = NULL;

    hr = IConnectionPoint_Advise(cp, (IUnknown *)&sink, &cookie);
    if (FAILED(hr)) goto done;

    memset(&conn, 0, sizeof(conn));
    hr = IConnectionPoint_EnumConnections(cp, &conn_enum);
    if (FAILED(hr)) goto done;
    fetched = 0;
    hr = IEnumConnections_Next(conn_enum, 1, &conn, &fetched);
    if (hr != S_OK || fetched != 1 || conn.dwCookie != cookie || !conn.pUnk) {
        if (conn.pUnk) IUnknown_Release(conn.pUnk);
        hr = E_FAIL;
        goto done;
    }
    IUnknown_Release(conn.pUnk);
    memset(&conn, 0, sizeof(conn));
    fetched = 1;
    hr = IEnumConnections_Next(conn_enum, 1, &conn, &fetched);
    if (hr != S_FALSE || fetched != 0 || conn.pUnk) {
        if (conn.pUnk) IUnknown_Release(conn.pUnk);
        hr = E_FAIL;
        goto done;
    }
    IEnumConnections_Release(conn_enum);
    conn_enum = NULL;

    sink.cancel_dispid = DISPID_VFG_EVT_BEFOREROWCOLCHANGE;
    hr = put_i4(disp, L"Row", 1);
    if (FAILED(hr)) goto done;
    hr = get_i4(disp, L"Row", &row);
    if (FAILED(hr)) goto done;
    if (sink.before_row_col != 1 || sink.after_row_col != 0 ||
        sink.row_col_change != 0 || sink.arg_mismatch || row != 0) {
        hr = E_FAIL;
        goto done;
    }

    event_sink_reset(&sink);
    hr = put_i4(disp, L"Row", 1);
    if (FAILED(hr)) goto done;
    hr = put_i4(disp, L"Col", 1);
    if (FAILED(hr)) goto done;
    if (sink.before_row_col < 2 || sink.after_row_col < 2 ||
        sink.row_col_change < 2 || sink.arg_mismatch) {
        hr = E_FAIL;
        goto done;
    }

    event_sink_reset(&sink);
    sink.cancel_dispid = DISPID_VFG_EVT_BEFORESELCHANGE;
    hr = put_i4(disp, L"RowSel", 2);
    if (FAILED(hr)) goto done;
    if (sink.before_sel != 1 || sink.after_sel != 0 || sink.sel_change != 0 ||
        sink.arg_mismatch) {
        hr = E_FAIL;
        goto done;
    }

    event_sink_reset(&sink);
    hr = put_i4(disp, L"RowSel", 2);
    if (FAILED(hr)) goto done;
    hr = put_i4(disp, L"ColSel", 2);
    if (FAILED(hr)) goto done;
    if (sink.before_sel < 2 || sink.after_sel < 2 || sink.sel_change < 2 ||
        sink.arg_mismatch) {
        hr = E_FAIL;
        goto done;
    }

    event_sink_reset(&sink);
    sink.cancel_dispid = DISPID_VFG_EVT_BEFORESCROLL;
    hr = put_i4(disp, L"TopRow", 2);
    if (FAILED(hr)) goto done;
    if (sink.before_scroll != 1 || sink.after_scroll != 0 || sink.arg_mismatch) {
        hr = E_FAIL;
        goto done;
    }

    event_sink_reset(&sink);
    hr = put_i4(disp, L"TopRow", 2);
    if (FAILED(hr)) goto done;
    if (sink.before_scroll < 1 || sink.after_scroll < 1 || sink.arg_mismatch) {
        hr = E_FAIL;
        goto done;
    }

    event_sink_reset(&sink);
    sink.cancel_dispid = DISPID_VFG_EVT_BEFOREUSERRESIZE;
    hr = put_indexed_i4(disp, L"RowHeight", 1, 600);
    if (FAILED(hr)) goto done;
    if (sink.before_resize != 1 || sink.after_resize != 0 || sink.arg_mismatch) {
        hr = E_FAIL;
        goto done;
    }

    event_sink_reset(&sink);
    hr = put_indexed_i4(disp, L"RowHeight", 1, 600);
    if (FAILED(hr)) goto done;
    hr = put_indexed_i4(disp, L"ColWidth", 1, 1200);
    if (FAILED(hr)) goto done;
    if (sink.before_resize < 2 || sink.after_resize < 2 || sink.arg_mismatch) {
        hr = E_FAIL;
        goto done;
    }

    event_sink_reset(&sink);
    hr = put_indexed_i4(disp, L"ColPosition", 2, 0);
    if (FAILED(hr)) goto done;
    hr = put_indexed_i4(disp, L"RowPosition", 3, 1);
    if (FAILED(hr)) goto done;
    if (sink.before_move_col < 1 || sink.after_move_col < 1 ||
        sink.before_move_row < 1 || sink.after_move_row < 1 || sink.arg_mismatch) {
        hr = E_FAIL;
        goto done;
    }

    event_sink_reset(&sink);
    hr = put_i4(disp, L"FrozenCols", 1);
    if (FAILED(hr)) goto done;
    if (sink.after_user_freeze < 1 || sink.arg_mismatch) {
        hr = E_FAIL;
        goto done;
    }

    event_sink_reset(&sink);
    hr = put_indexed_i4(disp, L"IsCollapsed", 2, 2);
    if (FAILED(hr)) goto done;
    if (sink.before_collapse < 1 || sink.after_collapse < 1 || sink.arg_mismatch) {
        hr = E_FAIL;
        goto done;
    }

    event_sink_reset(&sink);
    if (FAILED(hr = put_text_matrix(disp, 1, 1, L"B"))) goto done;
    if (FAILED(hr = put_text_matrix(disp, 2, 1, L"A"))) goto done;
    hr = call_method_i4_i4(disp, L"Sort", 1, 1);
    if (FAILED(hr)) goto done;
    if (sink.before_sort < 1 || sink.after_sort < 1 || sink.arg_mismatch) {
        hr = E_FAIL;
        goto done;
    }

    event_sink_reset(&sink);
    hr = call_method_i4_i4(disp, L"EditCell", 1, 1);
    if (FAILED(hr)) goto done;
    hr = put_bstr(disp, L"EditText", L"Edited");
    if (FAILED(hr)) goto done;
    hr = call_method0(disp, L"FinishEditing");
    if (FAILED(hr)) goto done;
    if (sink.before_edit < 1 || sink.start_edit < 1 || sink.after_edit < 1 ||
        sink.cell_changed < 1 || sink.arg_mismatch) {
        hr = E_FAIL;
        goto done;
    }

    event_sink_reset(&sink);
    probe_rs = probe_ado_recordset_create();
    if (!probe_rs) {
        hr = E_OUTOFMEMORY;
        goto done;
    }
    hr = put_i4(disp, L"DataMode", 1);
    if (FAILED(hr)) goto done;
    hr = put_i4(disp, L"FixedCols", 0);
    if (FAILED(hr)) goto done;
    hr = putref_dispatch(disp, L"DataSource", probe_rs);
    if (FAILED(hr)) goto done;
    if (sink.before_data_refresh < 1 || sink.after_data_refresh < 1 ||
        sink.arg_mismatch) {
        hr = E_FAIL;
        goto done;
    }

    event_sink_reset(&sink);
    sink.cancel_dispid = DISPID_VFG_EVT_BEFOREDATAREFRESH;
    hr = call_method0(disp, L"DataRefresh");
    if (FAILED(hr)) goto done;
    if (sink.before_data_refresh != 1 || sink.after_data_refresh != 0 ||
        sink.arg_mismatch) {
        hr = E_FAIL;
        goto done;
    }

    event_sink_reset(&sink);
    virtual_rs = probe_ado_virtual_recordset_create(&virtual_rs_state);
    if (!virtual_rs || !virtual_rs_state) {
        hr = E_OUTOFMEMORY;
        goto done;
    }
    hr = put_i4(disp, L"VirtualData", 1);
    if (FAILED(hr)) goto done;
    hr = put_i4(disp, L"DataMode", 2);
    if (FAILED(hr)) goto done;
    hr = putref_dispatch(disp, L"DataSource", virtual_rs);
    if (FAILED(hr)) goto done;
    hr = get_i4(disp, L"Rows", &rows_after_virtual);
    if (FAILED(hr)) goto done;
    if (rows_after_virtual < 20001 ||
        virtual_rs_state->move_first_calls != 0 ||
        virtual_rs_state->move_next_calls != 0 ||
        sink.before_data_refresh < 1 || sink.after_data_refresh < 1 ||
        sink.error_event != 0 || sink.arg_mismatch) {
        hr = E_FAIL;
        goto done;
    }
    hr = get_text_matrix(disp, 1, 0, &virtual_cell);
    if (FAILED(hr)) goto done;
    if (!virtual_cell || wcscmp(virtual_cell, L"R1C0") != 0) {
        hr = E_FAIL;
        goto done;
    }
    SysFreeString(virtual_cell);
    virtual_cell = NULL;

    event_sink_reset(&sink);
    hr = put_i4(disp, L"Row", 100);
    if (FAILED(hr)) goto done;
    if (virtual_rs_state->absolute_position != 100 ||
        virtual_rs_state->move_first_calls != 0 ||
        virtual_rs_state->move_next_calls != 0 ||
        sink.before_row_col < 1 || sink.after_row_col < 1 ||
        sink.error_event != 0 || sink.arg_mismatch) {
        hr = E_FAIL;
        goto done;
    }
    hr = get_text_matrix(disp, 100, 0, &virtual_cell);
    if (FAILED(hr)) goto done;
    if (!virtual_cell || wcscmp(virtual_cell, L"R100C0") != 0) {
        hr = E_FAIL;
        goto done;
    }
    SysFreeString(virtual_cell);
    virtual_cell = NULL;

    event_sink_reset(&sink);
    failing_source = probe_ado_failing_source_create();
    if (!failing_source) {
        hr = E_OUTOFMEMORY;
        goto done;
    }
    hr = putref_dispatch(disp, L"DataSource", failing_source);
    if (SUCCEEDED(hr) || sink.before_data_refresh != 1 ||
        sink.after_data_refresh != 0 || sink.error_event != 1 ||
        sink.arg_mismatch) {
        hr = E_FAIL;
        goto done;
    }
    hr = S_OK;

done:
    if (virtual_cell) SysFreeString(virtual_cell);
    if (failing_source) IDispatch_Release(failing_source);
    if (virtual_rs) IDispatch_Release(virtual_rs);
    if (probe_rs) IDispatch_Release(probe_rs);
    if (conn_enum) IEnumConnections_Release(conn_enum);
    if (enum_cp) IConnectionPoint_Release(enum_cp);
    if (cp_enum) IEnumConnectionPoints_Release(cp_enum);
    if (cp && cookie) IConnectionPoint_Unadvise(cp, cookie);
    if (cp) IConnectionPoint_Release(cp);
    if (cpc) IConnectionPointContainer_Release(cpc);
    return hr;
}

static HRESULT probe_view_object2(IDispatch *disp) {
    IViewObject2 *view2 = NULL;
    SIZEL extent;
    HRESULT hr = IDispatch_QueryInterface(disp, &IID_IViewObject2, (void **)&view2);
    if (FAILED(hr)) return hr;
    memset(&extent, 0, sizeof(extent));
    hr = IViewObject2_GetExtent(view2, DVASPECT_CONTENT, -1, NULL, &extent);
    IViewObject2_Release(view2);
    if (FAILED(hr)) return hr;
    return (extent.cx > 0 && extent.cy > 0) ? S_OK : E_FAIL;
}

static HRESULT probe_owner_draw_hdc_contract(IDispatch *disp) {
    IConnectionPointContainer *cpc = NULL;
    IConnectionPoint *cp = NULL;
    IViewObject2 *view2 = NULL;
    ProbeEventSink sink;
    DWORD cookie = 0;
    HDC memdc = NULL;
    HBITMAP bitmap = NULL;
    HGDIOBJ old_bitmap = NULL;
    BITMAPINFO bmi;
    void *bits = NULL;
    RECTL bounds;
    COLORREF pixel;
    int sample_x;
    int sample_y;
    HRESULT hr;

    memset(&sink, 0, sizeof(sink));
    sink.lpVtbl = &g_event_sink_vtbl;
    sink.refs = 1;
    event_sink_reset(&sink);

    if (FAILED(hr = put_i4(disp, L"Rows", 2))) return hr;
    if (FAILED(hr = put_i4(disp, L"Cols", 2))) return hr;
    if (FAILED(hr = put_i4(disp, L"FixedRows", 0))) return hr;
    if (FAILED(hr = put_i4(disp, L"FixedCols", 0))) return hr;
    if (FAILED(hr = put_i4(disp, L"TopRow", 0))) return hr;
    if (FAILED(hr = put_i4(disp, L"LeftCol", 0))) return hr;
    if (FAILED(hr = put_i4(disp, L"OwnerDraw", 2))) return hr;

    hr = IDispatch_QueryInterface(disp, &IID_IConnectionPointContainer, (void **)&cpc);
    if (FAILED(hr)) goto done;
    hr = IConnectionPointContainer_FindConnectionPoint(cpc, &DIID__DVolvoxGridEvents, &cp);
    if (FAILED(hr)) goto done;
    hr = IConnectionPoint_Advise(cp, (IUnknown *)&sink, &cookie);
    if (FAILED(hr)) goto done;
    hr = IDispatch_QueryInterface(disp, &IID_IViewObject2, (void **)&view2);
    if (FAILED(hr)) goto done;

    memdc = CreateCompatibleDC(NULL);
    if (!memdc) {
        hr = HRESULT_FROM_WIN32(GetLastError());
        if (SUCCEEDED(hr)) hr = E_FAIL;
        goto done;
    }
    memset(&bmi, 0, sizeof(bmi));
    bmi.bmiHeader.biSize = sizeof(BITMAPINFOHEADER);
    bmi.bmiHeader.biWidth = 128;
    bmi.bmiHeader.biHeight = -96;
    bmi.bmiHeader.biPlanes = 1;
    bmi.bmiHeader.biBitCount = 32;
    bmi.bmiHeader.biCompression = BI_RGB;
    bitmap = CreateDIBSection(memdc, &bmi, DIB_RGB_COLORS, &bits, NULL, 0);
    if (!bitmap || !bits) {
        hr = HRESULT_FROM_WIN32(GetLastError());
        if (SUCCEEDED(hr)) hr = E_FAIL;
        goto done;
    }
    old_bitmap = SelectObject(memdc, bitmap);
    if (!old_bitmap) {
        hr = E_FAIL;
        goto done;
    }
    PatBlt(memdc, 0, 0, 128, 96, WHITENESS);

    bounds.left = 0;
    bounds.top = 0;
    bounds.right = 128;
    bounds.bottom = 96;
    hr = IViewObject2_Draw(
        view2, DVASPECT_CONTENT, -1, NULL, NULL, NULL, memdc,
        &bounds, NULL, NULL, 0);
    if (FAILED(hr)) goto done;

    if (sink.draw_cell < 1 || sink.draw_done_count < 1 || sink.arg_mismatch ||
        sink.draw_first_row != 0 || sink.draw_first_col != 0 ||
        sink.draw_first_left < 0 || sink.draw_first_top < 0 ||
        sink.draw_first_right <= sink.draw_first_left ||
        sink.draw_first_bottom <= sink.draw_first_top ||
        sink.draw_first_right > bounds.right ||
        sink.draw_first_bottom > bounds.bottom) {
        hr = E_FAIL;
        goto done;
    }

    sample_x = (int)((sink.draw_first_left + sink.draw_first_right) / 2);
    sample_y = (int)((sink.draw_first_top + sink.draw_first_bottom) / 2);
    pixel = GetPixel(memdc, sample_x, sample_y);
    hr = (pixel == PROBE_OWNER_DRAW_COLOR) ? S_OK : E_FAIL;

done:
    if (old_bitmap && memdc) SelectObject(memdc, old_bitmap);
    if (bitmap) DeleteObject(bitmap);
    if (memdc) DeleteDC(memdc);
    if (view2) IViewObject2_Release(view2);
    if (cp && cookie) IConnectionPoint_Unadvise(cp, cookie);
    if (cp) IConnectionPoint_Release(cp);
    if (cpc) IConnectionPointContainer_Release(cpc);
    return hr;
}

static HRESULT probe_data_object(IDispatch *disp) {
    IDataObject *data = NULL;
    IEnumFORMATETC *formats = NULL;
    FORMATETC fmt;
    FORMATETC enum_fmt;
    STGMEDIUM medium;
    WCHAR *text;
    CLIPFORMAT cf_html;
    CLIPFORMAT cf_cells;
    char *html;
    char *cells;
    ULONG fetched;
    int saw_text = 0;
    int saw_html = 0;
    int saw_cells = 0;
    HRESULT hr;

    hr = put_bstr(disp, L"Clip", L"A\tB");
    if (FAILED(hr)) return hr;
    cf_html = (CLIPFORMAT)RegisterClipboardFormatA("HTML Format");
    if (!cf_html) return E_FAIL;
    cf_cells = (CLIPFORMAT)RegisterClipboardFormatA("CF_VFG_CELLS");
    if (!cf_cells) return E_FAIL;
    hr = IDispatch_QueryInterface(disp, &IID_IDataObject, (void **)&data);
    if (FAILED(hr)) return hr;
    hr = IDataObject_EnumFormatEtc(data, DATADIR_GET, &formats);
    if (FAILED(hr)) goto done;
    for (;;) {
        memset(&enum_fmt, 0, sizeof(enum_fmt));
        fetched = 0;
        hr = IEnumFORMATETC_Next(formats, 1, &enum_fmt, &fetched);
        if (hr == S_FALSE) break;
        if (FAILED(hr)) goto done;
        if (fetched != 1) {
            hr = E_FAIL;
            goto done;
        }
        if (enum_fmt.cfFormat == CF_UNICODETEXT &&
            enum_fmt.dwAspect == DVASPECT_CONTENT &&
            enum_fmt.lindex == -1 &&
            (enum_fmt.tymed & TYMED_HGLOBAL)) {
            saw_text = 1;
        }
        if (enum_fmt.cfFormat == cf_html &&
            enum_fmt.dwAspect == DVASPECT_CONTENT &&
            enum_fmt.lindex == -1 &&
            (enum_fmt.tymed & TYMED_HGLOBAL)) {
            saw_html = 1;
        }
        if (enum_fmt.cfFormat == cf_cells &&
            enum_fmt.dwAspect == DVASPECT_CONTENT &&
            enum_fmt.lindex == -1 &&
            (enum_fmt.tymed & TYMED_HGLOBAL)) {
            saw_cells = 1;
        }
        if (enum_fmt.ptd) CoTaskMemFree(enum_fmt.ptd);
    }
    if (!saw_text || !saw_html || !saw_cells) {
        hr = E_FAIL;
        goto done;
    }
    IEnumFORMATETC_Release(formats);
    formats = NULL;

    memset(&fmt, 0, sizeof(fmt));
    fmt.cfFormat = CF_UNICODETEXT;
    fmt.dwAspect = DVASPECT_CONTENT;
    fmt.lindex = -1;
    fmt.tymed = TYMED_HGLOBAL;
    memset(&medium, 0, sizeof(medium));
    hr = IDataObject_GetData(data, &fmt, &medium);
    if (FAILED(hr)) goto done;
    text = (WCHAR *)GlobalLock(medium.hGlobal);
    if (!text || wcsstr(text, L"A") == NULL) hr = E_FAIL;
    if (text) GlobalUnlock(medium.hGlobal);
    ReleaseStgMedium(&medium);
    if (FAILED(hr)) goto done;

    memset(&fmt, 0, sizeof(fmt));
    fmt.cfFormat = cf_html;
    fmt.dwAspect = DVASPECT_CONTENT;
    fmt.lindex = -1;
    fmt.tymed = TYMED_HGLOBAL;
    memset(&medium, 0, sizeof(medium));
    hr = IDataObject_GetData(data, &fmt, &medium);
    if (FAILED(hr)) goto done;
    html = (char *)GlobalLock(medium.hGlobal);
    if (!html || strstr(html, "<table>") == NULL || strstr(html, "<td>A</td>") == NULL) {
        hr = E_FAIL;
    }
    if (html) GlobalUnlock(medium.hGlobal);
    ReleaseStgMedium(&medium);
    if (FAILED(hr)) goto done;

    memset(&fmt, 0, sizeof(fmt));
    fmt.cfFormat = cf_cells;
    fmt.dwAspect = DVASPECT_CONTENT;
    fmt.lindex = -1;
    fmt.tymed = TYMED_HGLOBAL;
    memset(&medium, 0, sizeof(medium));
    hr = IDataObject_GetData(data, &fmt, &medium);
    if (FAILED(hr)) goto done;
    cells = (char *)GlobalLock(medium.hGlobal);
    if (!cells || strstr(cells, "A") == NULL) {
        hr = E_FAIL;
    }
    if (cells) GlobalUnlock(medium.hGlobal);
    ReleaseStgMedium(&medium);
    if (FAILED(hr)) goto done;

    memset(&fmt, 0, sizeof(fmt));
    fmt.cfFormat = cf_cells;
    fmt.dwAspect = DVASPECT_CONTENT;
    fmt.lindex = -1;
    fmt.tymed = TYMED_HGLOBAL;
    memset(&medium, 0, sizeof(medium));
    medium.tymed = TYMED_HGLOBAL;
    medium.hGlobal = GlobalAlloc(GMEM_MOVEABLE | GMEM_ZEROINIT, 9);
    if (!medium.hGlobal) {
        hr = E_OUTOFMEMORY;
        goto done;
    }
    cells = (char *)GlobalLock(medium.hGlobal);
    if (!cells) {
        ReleaseStgMedium(&medium);
        hr = E_OUTOFMEMORY;
        goto done;
    }
    memcpy(cells, "override", 8);
    GlobalUnlock(medium.hGlobal);
    hr = IDataObject_SetData(data, &fmt, &medium, FALSE);
    ReleaseStgMedium(&medium);
    if (FAILED(hr)) goto done;
    memset(&medium, 0, sizeof(medium));
    hr = IDataObject_GetData(data, &fmt, &medium);
    if (FAILED(hr)) goto done;
    cells = (char *)GlobalLock(medium.hGlobal);
    if (!cells || memcmp(cells, "override", 8) != 0) {
        hr = E_FAIL;
    }
    if (cells) GlobalUnlock(medium.hGlobal);
    ReleaseStgMedium(&medium);

done:
    if (formats) IEnumFORMATETC_Release(formats);
    if (data) IDataObject_Release(data);
    return hr;
}

static HRESULT probe_ole_dragdrop_contract(IDispatch *disp) {
    IConnectionPointContainer *cpc = NULL;
    IConnectionPoint *cp = NULL;
    IDataObject *data = NULL;
    IDropSource *source = NULL;
    IDropTarget *target = NULL;
    ProbeEventSink sink;
    DWORD cookie = 0;
    POINTL pt;
    DWORD effect;
    LONG value = -1;
    HRESULT hr;

    memset(&sink, 0, sizeof(sink));
    sink.lpVtbl = &g_event_sink_vtbl;
    sink.refs = 1;
    event_sink_reset(&sink);

    hr = put_i4(disp, L"OLEDragMode", 1);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"OLEDragMode", &value);
    if (FAILED(hr)) return hr;
    if (value != 1) return E_FAIL;
    hr = put_i4(disp, L"OLEDropMode", 2);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"OLEDropMode", &value);
    if (FAILED(hr)) return hr;
    if (value != 2) return E_FAIL;

    hr = IDispatch_QueryInterface(disp, &IID_IDataObject, (void **)&data);
    if (FAILED(hr)) goto done;
    hr = IDispatch_QueryInterface(disp, &IID_IDropSource, (void **)&source);
    if (FAILED(hr)) goto done;
    hr = IDispatch_QueryInterface(disp, &IID_IDropTarget, (void **)&target);
    if (FAILED(hr)) goto done;
    hr = IDispatch_QueryInterface(disp, &IID_IConnectionPointContainer, (void **)&cpc);
    if (FAILED(hr)) goto done;
    hr = IConnectionPointContainer_FindConnectionPoint(cpc, &DIID__DVolvoxGridEvents, &cp);
    if (FAILED(hr)) goto done;
    hr = IConnectionPoint_Advise(cp, (IUnknown *)&sink, &cookie);
    if (FAILED(hr)) goto done;

    hr = IDropSource_QueryContinueDrag(source, FALSE, MK_LBUTTON);
    if (hr != S_OK) {
        hr = E_FAIL;
        goto done;
    }
    hr = IDropSource_QueryContinueDrag(source, FALSE, 0);
    if (hr != DRAGDROP_S_DROP) {
        hr = E_FAIL;
        goto done;
    }
    hr = IDropSource_QueryContinueDrag(source, TRUE, MK_LBUTTON);
    if (hr != DRAGDROP_S_CANCEL) {
        hr = E_FAIL;
        goto done;
    }
    hr = IDropSource_GiveFeedback(source, DROPEFFECT_COPY);
    if (hr != DRAGDROP_S_USEDEFAULTCURSORS) {
        hr = E_FAIL;
        goto done;
    }
    if (sink.ole_give_feedback != 1 || sink.arg_mismatch) {
        hr = E_FAIL;
        goto done;
    }

    event_sink_reset(&sink);
    pt.x = 12;
    pt.y = 34;
    effect = DROPEFFECT_COPY | DROPEFFECT_MOVE;
    hr = IDropTarget_DragEnter(target, data, MK_CONTROL, pt, &effect);
    if (FAILED(hr)) goto done;
    if (effect != DROPEFFECT_COPY) {
        hr = E_FAIL;
        goto done;
    }
    effect = DROPEFFECT_COPY | DROPEFFECT_MOVE;
    hr = IDropTarget_DragOver(target, MK_CONTROL, pt, &effect);
    if (FAILED(hr)) goto done;
    if (effect != DROPEFFECT_COPY) {
        hr = E_FAIL;
        goto done;
    }
    hr = IDropTarget_DragLeave(target);
    if (FAILED(hr)) goto done;
    effect = DROPEFFECT_COPY | DROPEFFECT_MOVE;
    hr = IDropTarget_Drop(target, data, MK_CONTROL, pt, &effect);
    if (FAILED(hr)) goto done;
    if (effect != DROPEFFECT_COPY) hr = E_FAIL;
    if (SUCCEEDED(hr) &&
        (sink.ole_drag_over < 3 || sink.ole_drag_enter_state != 1 ||
         sink.ole_drag_over_state != 1 || sink.ole_drag_leave_state != 1 ||
         sink.ole_drag_drop != 1 || sink.arg_mismatch)) {
        hr = E_FAIL;
        goto done;
    }

    event_sink_reset(&sink);
    sink.cancel_dispid = DISPID_VFG_EVT_OLESTARTDRAG;
    hr = call_method_i4(disp, L"OLEDrag", DROPEFFECT_COPY | DROPEFFECT_MOVE);
    if (FAILED(hr)) goto done;
    if (sink.ole_start_drag != 1 || sink.ole_complete_drag != 1 ||
        sink.ole_give_feedback != 0 || sink.arg_mismatch) {
        hr = E_FAIL;
    }

done:
    if (cp && cookie) IConnectionPoint_Unadvise(cp, cookie);
    if (cp) IConnectionPoint_Release(cp);
    if (cpc) IConnectionPointContainer_Release(cpc);
    if (target) IDropTarget_Release(target);
    if (source) IDropSource_Release(source);
    if (data) IDataObject_Release(data);
    return hr;
}

static HRESULT probe_picture_type_contract(IDispatch *disp) {
    static const BYTE png_sig[] = { 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A };
    LONG value = -1;
    LONG byte_len = 0;
    HRESULT hr;

    hr = put_i4(disp, L"PictureType", 1);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"PictureType", &value);
    if (FAILED(hr)) return hr;
    if (value != 1) return E_FAIL;
    hr = put_i4(disp, L"PictureType", 99);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"PictureType", &value);
    if (FAILED(hr)) return hr;
    if (value != 2) return E_FAIL;

    hr = put_indexed_i4(disp, L"ColImageList", 1, 1234);
    if (FAILED(hr)) return hr;
    hr = get_indexed_i4(disp, L"ColImageList", 1, &value);
    if (FAILED(hr)) return hr;
    if (value != 1234) return E_FAIL;

    hr = put_i4(disp, L"CellPictureAlignment", 4);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"CellPictureAlignment", &value);
    if (FAILED(hr)) return hr;
    if (value != 4) return E_FAIL;

    hr = put_ui1_array(disp, L"CellButtonPicture", png_sig, (LONG)sizeof(png_sig));
    if (FAILED(hr)) return hr;
    hr = get_ui1_array_len(disp, L"CellButtonPicture", &byte_len);
    if (FAILED(hr)) return hr;
    if (byte_len != (LONG)sizeof(png_sig)) return E_FAIL;

    hr = put_ui1_array(disp, L"NodeOpenPicture", png_sig, (LONG)sizeof(png_sig));
    if (FAILED(hr)) return hr;
    hr = get_ui1_array_len(disp, L"NodeOpenPicture", &byte_len);
    if (FAILED(hr)) return hr;
    if (byte_len != (LONG)sizeof(png_sig)) return E_FAIL;

    hr = put_ui1_array(disp, L"NodeClosedPicture", png_sig, (LONG)sizeof(png_sig));
    if (FAILED(hr)) return hr;
    hr = get_ui1_array_len(disp, L"NodeClosedPicture", &byte_len);
    if (FAILED(hr)) return hr;
    if (byte_len != (LONG)sizeof(png_sig)) return E_FAIL;

    hr = put_ui1_array(disp, L"SortAscendingPicture", png_sig, (LONG)sizeof(png_sig));
    if (FAILED(hr)) return hr;
    hr = get_ui1_array_len(disp, L"SortAscendingPicture", &byte_len);
    if (FAILED(hr)) return hr;
    if (byte_len != (LONG)sizeof(png_sig)) return E_FAIL;

    hr = put_ui1_array(disp, L"SortDescendingPicture", png_sig, (LONG)sizeof(png_sig));
    if (FAILED(hr)) return hr;
    hr = get_ui1_array_len(disp, L"SortDescendingPicture", &byte_len);
    if (FAILED(hr)) return hr;
    if (byte_len != (LONG)sizeof(png_sig)) return E_FAIL;

    hr = put_i4(disp, L"PicturesOver", -1);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"PicturesOver", &value);
    if (FAILED(hr)) return hr;
    if (value != -1) return E_FAIL;

    hr = put_ui1_array(disp, L"WallPaper", png_sig, (LONG)sizeof(png_sig));
    if (FAILED(hr)) return hr;
    hr = get_ui1_array_len(disp, L"WallPaper", &byte_len);
    if (FAILED(hr)) return hr;
    if (byte_len != (LONG)sizeof(png_sig)) return E_FAIL;

    hr = put_i4(disp, L"WallPaperAlignment", 2);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"WallPaperAlignment", &value);
    if (FAILED(hr)) return hr;
    return value == 2 ? S_OK : E_FAIL;
}

static HRESULT probe_string_option_contract(IDispatch *disp) {
    BSTR value = NULL;
    HRESULT hr;

    hr = put_bstr(disp, L"FormatString", L"<Name|>Amount");
    if (FAILED(hr)) return hr;
    hr = get_bstr(disp, L"FormatString", &value);
    if (FAILED(hr)) return hr;
    if (!value || wcscmp(value, L"<Name|>Amount") != 0) {
        if (value) SysFreeString(value);
        return E_FAIL;
    }
    SysFreeString(value);
    value = NULL;

    hr = put_i4(disp, L"Row", 1);
    if (FAILED(hr)) return hr;
    hr = put_i4(disp, L"Col", 1);
    if (FAILED(hr)) return hr;
    hr = put_bstr(disp, L"ComboList", L"One|Two|Three");
    if (FAILED(hr)) return hr;
    hr = get_bstr(disp, L"ComboList", &value);
    if (FAILED(hr)) return hr;
    if (!value || wcscmp(value, L"One|Two|Three") != 0) {
        if (value) SysFreeString(value);
        return E_FAIL;
    }
    SysFreeString(value);
    value = NULL;

    hr = put_bstr(disp, L"ClipSeparators", L",\r");
    if (FAILED(hr)) return hr;
    hr = get_bstr(disp, L"ClipSeparators", &value);
    if (FAILED(hr)) return hr;
    if (!value || wcscmp(value, L",\r") != 0) {
        if (value) SysFreeString(value);
        return E_FAIL;
    }
    SysFreeString(value);
    return S_OK;
}

static HRESULT probe_merge_option_contract(IDispatch *disp) {
    LONG value = -1;
    HRESULT hr;

    hr = put_i4(disp, L"MergeCellsFixed", 5);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"MergeCellsFixed", &value);
    if (FAILED(hr)) return hr;
    if (value != 5) return E_FAIL;
    hr = put_i4(disp, L"GroupCompare", 2);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"GroupCompare", &value);
    if (FAILED(hr)) return hr;
    return value == 2 ? S_OK : E_FAIL;
}

static HRESULT probe_interaction_option_contract(IDispatch *disp) {
    LONG value = -1;
    HRESULT hr;

    hr = put_i4(disp, L"ScrollTips", 1);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"ScrollTips", &value);
    if (FAILED(hr)) return hr;
    if (value == 0) return E_FAIL;
    hr = put_i4(disp, L"ScrollTips", 0);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"ScrollTips", &value);
    if (FAILED(hr)) return hr;
    if (value != 0) return E_FAIL;
    hr = put_i4(disp, L"ComboSearch", 1);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"ComboSearch", &value);
    if (FAILED(hr)) return hr;
    if (value != 1) return E_FAIL;
    hr = put_i4(disp, L"OwnerDraw", 2);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"OwnerDraw", &value);
    if (FAILED(hr)) return hr;
    return value == 2 ? S_OK : E_FAIL;
}

static HRESULT probe_font_option_contract(IDispatch *disp) {
    LONG value = -1;
    HRESULT hr;

    hr = put_i4(disp, L"FontBold", 1);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"FontBold", &value);
    if (FAILED(hr)) return hr;
    if (value == 0) return E_FAIL;
    hr = put_i4(disp, L"FontItalic", 1);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"FontItalic", &value);
    if (FAILED(hr)) return hr;
    if (value == 0) return E_FAIL;
    hr = put_i4(disp, L"FontStrikethru", 1);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"FontStrikethru", &value);
    if (FAILED(hr)) return hr;
    if (value == 0) return E_FAIL;
    hr = put_i4(disp, L"FontUnderline", 1);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"FontUnderline", &value);
    if (FAILED(hr)) return hr;
    if (value == 0) return E_FAIL;
    hr = put_i4(disp, L"FontWidth", 70);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"FontWidth", &value);
    if (FAILED(hr)) return hr;
    return value == 70 ? S_OK : E_FAIL;
}

static HRESULT probe_visual_option_contract(IDispatch *disp) {
    LONG value = -1;
    HRESULT hr;

    hr = put_i4(disp, L"Appearance", 1);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"Appearance", &value);
    if (FAILED(hr)) return hr;
    if (value != 1) return E_FAIL;
    hr = put_i4(disp, L"Appearance", 0);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"Appearance", &value);
    if (FAILED(hr)) return hr;
    if (value != 0) return E_FAIL;
    hr = put_i4(disp, L"SheetBorder", 0x00112244);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"SheetBorder", &value);
    if (FAILED(hr)) return hr;
    return value == 0x00112244 ? S_OK : E_FAIL;
}

static HRESULT probe_layout_option_contract(IDispatch *disp) {
    LONG value = -1;
    HRESULT hr;

    hr = put_i4(disp, L"AllowUserFreezing", 3);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"AllowUserFreezing", &value);
    if (FAILED(hr)) return hr;
    if (value != 3) return E_FAIL;
    hr = put_i4(disp, L"ExplorerBar", 1);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"ExplorerBar", &value);
    if (FAILED(hr)) return hr;
    if (value != 1) return E_FAIL;
    hr = put_i4(disp, L"TabBehavior", 0);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"TabBehavior", &value);
    if (FAILED(hr)) return hr;
    if (value != 0) return E_FAIL;
    hr = put_i4(disp, L"RowHeightMin", 255);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"RowHeightMin", &value);
    if (FAILED(hr)) return hr;
    if (value != 255) return E_FAIL;
    hr = put_indexed_i4(disp, L"RowHeight", 1, 120);
    if (FAILED(hr)) return hr;
    hr = get_indexed_i4(disp, L"RowHeight", 1, &value);
    if (FAILED(hr)) return hr;
    if (value != 255) return E_FAIL;
    hr = put_i4(disp, L"ColWidthMin", 240);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"ColWidthMin", &value);
    if (FAILED(hr)) return hr;
    if (value != 240) return E_FAIL;
    hr = put_indexed_i4(disp, L"ColWidth", 1, 120);
    if (FAILED(hr)) return hr;
    hr = get_indexed_i4(disp, L"ColWidth", 1, &value);
    if (FAILED(hr)) return hr;
    if (value != 240) return E_FAIL;
    hr = put_i4(disp, L"GridLineWidth", 3);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"GridLineWidth", &value);
    if (FAILED(hr)) return hr;
    if (value != 3) return E_FAIL;
    hr = put_indexed_i4(disp, L"ColIndent", 2, 5);
    if (FAILED(hr)) return hr;
    hr = get_indexed_i4(disp, L"ColIndent", 2, &value);
    if (FAILED(hr)) return hr;
    return value == 5 ? S_OK : E_FAIL;
}

static HRESULT probe_color_option_contract(IDispatch *disp) {
    LONG value = -1;
    HRESULT hr;

    hr = put_i4(disp, L"BackColorBkg", 0x00112233);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"BackColorBkg", &value);
    if (FAILED(hr)) return hr;
    if ((value & 0x00FFFFFF) != 0x00112233) return E_FAIL;
    hr = put_i4(disp, L"BackColorFrozen", 0x00224466);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"BackColorFrozen", &value);
    if (FAILED(hr)) return hr;
    if ((value & 0x00FFFFFF) != 0x00224466) return E_FAIL;
    hr = put_i4(disp, L"ForeColorFrozen", 0x00335577);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"ForeColorFrozen", &value);
    if (FAILED(hr)) return hr;
    if ((value & 0x00FFFFFF) != 0x00335577) return E_FAIL;
    hr = put_i4(disp, L"FloodColor", 0x00446688);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"FloodColor", &value);
    if (FAILED(hr)) return hr;
    if ((value & 0x00FFFFFF) != 0x00446688) return E_FAIL;
    hr = put_i4(disp, L"GridColorFixed", 0x00557799);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"GridColorFixed", &value);
    if (FAILED(hr)) return hr;
    return ((value & 0x00FFFFFF) == 0x00557799) ? S_OK : E_FAIL;
}

static HRESULT probe_accessibility_contract(IDispatch *disp) {
    BSTR value = NULL;
    LONG role = 0;
    HRESULT hr;

    /* The legacy grid defaults AccessibleRole to ROLE_SYSTEM_TABLE (24). */
    hr = get_i4(disp, L"AccessibleRole", &role);
    if (FAILED(hr)) return hr;
    if (role != 24) return E_FAIL;

    hr = put_bstr(disp, L"AccessibleName", L"Orders grid");
    if (FAILED(hr)) return hr;
    hr = get_bstr(disp, L"AccessibleName", &value);
    if (FAILED(hr)) return hr;
    if (!value || wcscmp(value, L"Orders grid") != 0) {
        if (value) SysFreeString(value);
        return E_FAIL;
    }
    SysFreeString(value);
    value = NULL;

    hr = put_bstr(disp, L"AccessibleDescription", L"Order rows and columns");
    if (FAILED(hr)) return hr;
    hr = get_bstr(disp, L"AccessibleDescription", &value);
    if (FAILED(hr)) return hr;
    if (!value || wcscmp(value, L"Order rows and columns") != 0) {
        if (value) SysFreeString(value);
        return E_FAIL;
    }
    SysFreeString(value);
    value = NULL;

    hr = put_bstr(disp, L"AccessibleValue", L"Ready");
    if (FAILED(hr)) return hr;
    hr = get_bstr(disp, L"AccessibleValue", &value);
    if (FAILED(hr)) return hr;
    if (!value || wcscmp(value, L"Ready") != 0) {
        if (value) SysFreeString(value);
        return E_FAIL;
    }
    SysFreeString(value);

    hr = put_i4(disp, L"AccessibleRole", 42);
    if (FAILED(hr)) return hr;
    hr = get_i4(disp, L"AccessibleRole", &role);
    if (FAILED(hr)) return hr;
    return role == 42 ? S_OK : E_FAIL;
}

static HRESULT probe_persist(IClassFactory *factory) {
    IDispatch *src = NULL;
    IDispatch *dst = NULL;
    IPersistStreamInit *psi_src = NULL;
    IPersistStreamInit *psi_dst = NULL;
    IStream *stream = NULL;
    LARGE_INTEGER zero;
    BSTR text = NULL;
    HRESULT hr;

    memset(&zero, 0, sizeof(zero));
    hr = create_grid(factory, &src);
    if (FAILED(hr)) return hr;
    hr = create_grid(factory, &dst);
    if (FAILED(hr)) goto done;
    if (FAILED(hr = put_i4(src, L"Rows", 3))) goto done;
    if (FAILED(hr = put_i4(src, L"Cols", 2))) goto done;
    if (FAILED(hr = put_text_matrix(src, 1, 1, L"Persisted"))) goto done;
    if (FAILED(hr = IDispatch_QueryInterface(src, &IID_IPersistStreamInit, (void **)&psi_src))) goto done;
    if (FAILED(hr = IDispatch_QueryInterface(dst, &IID_IPersistStreamInit, (void **)&psi_dst))) goto done;
    if (FAILED(hr = CreateStreamOnHGlobal(NULL, TRUE, &stream))) goto done;
    if (FAILED(hr = IPersistStreamInit_Save(psi_src, stream, TRUE))) goto done;
    if (FAILED(hr = IStream_Seek(stream, zero, STREAM_SEEK_SET, NULL))) goto done;
    if (FAILED(hr = IPersistStreamInit_Load(psi_dst, stream))) goto done;
    if (FAILED(hr = get_text_matrix(dst, 1, 1, &text))) goto done;
    hr = (text && wcscmp(text, L"Persisted") == 0) ? S_OK : E_FAIL;

done:
    if (text) SysFreeString(text);
    if (stream) IStream_Release(stream);
    if (psi_src) IPersistStreamInit_Release(psi_src);
    if (psi_dst) IPersistStreamInit_Release(psi_dst);
    if (src) IDispatch_Release(src);
    if (dst) IDispatch_Release(dst);
    return hr;
}

int main(int argc, char **argv) {
    IClassFactory *factory = NULL;
    IDispatch *disp = NULL;
    const char *mode = "all";
    int run_all;
    int run_properties;
    int run_view_data;
    int run_events;
    int run_persist;
    int run_oledrag;
    int run_ownerdraw;
    HRESULT hr;
    int failed = 0;

    if (argc < 2 || argc > 3) {
        fprintf(stderr, "usage: probe_container_contract.exe <volvox-ocx> [all|properties|view-data|events|persist|oledrag|ownerdraw]\n");
        return 2;
    }
    if (argc == 3) mode = argv[2];
    run_all = strcmp(mode, "all") == 0;
    run_properties = run_all || strcmp(mode, "properties") == 0;
    run_view_data = run_all || strcmp(mode, "view-data") == 0;
    run_events = run_all || strcmp(mode, "events") == 0;
    run_persist = run_all || strcmp(mode, "persist") == 0;
    run_oledrag = run_all || strcmp(mode, "oledrag") == 0;
    run_ownerdraw = run_all || strcmp(mode, "ownerdraw") == 0;
    if (!run_properties && !run_view_data && !run_events &&
        !run_persist && !run_oledrag && !run_ownerdraw) {
        fprintf(stderr, "unknown mode: %s\n", mode);
        return 2;
    }

    OleInitialize(NULL);
    hr = load_factory(argv[1], &factory);
    if (FAILED(hr) || !factory) {
        print_hr("FAIL IClassFactory", hr);
        OleUninitialize();
        return 1;
    }

    if (run_properties || run_view_data || run_events || run_oledrag) {
        hr = create_grid(factory, &disp);
        if (FAILED(hr) || !disp) {
            print_hr("FAIL CreateInstance", hr);
            failed++;
        } else {
            if (run_view_data) {
                hr = probe_view_object2(disp);
                if (FAILED(hr)) {
                    print_hr("FAIL IViewObject2", hr);
                    failed++;
                }
                hr = probe_data_object(disp);
                if (FAILED(hr)) {
                    print_hr("FAIL IDataObject", hr);
                    failed++;
                }
            }
            if (run_properties) {
                hr = probe_picture_type_contract(disp);
                if (FAILED(hr)) {
                    print_hr("FAIL PictureType", hr);
                    failed++;
                }
                hr = probe_merge_option_contract(disp);
                if (FAILED(hr)) {
                    print_hr("FAIL Merge options", hr);
                    failed++;
                }
                hr = probe_interaction_option_contract(disp);
                if (FAILED(hr)) {
                    print_hr("FAIL Interaction options", hr);
                    failed++;
                }
                hr = probe_font_option_contract(disp);
                if (FAILED(hr)) {
                    print_hr("FAIL Font options", hr);
                    failed++;
                }
                hr = probe_visual_option_contract(disp);
                if (FAILED(hr)) {
                    print_hr("FAIL Visual options", hr);
                    failed++;
                }
                hr = probe_layout_option_contract(disp);
                if (FAILED(hr)) {
                    print_hr("FAIL Layout options", hr);
                    failed++;
                }
                hr = probe_color_option_contract(disp);
                if (FAILED(hr)) {
                    print_hr("FAIL Color options", hr);
                    failed++;
                }
                hr = probe_accessibility_contract(disp);
                if (FAILED(hr)) {
                    print_hr("FAIL Accessibility options", hr);
                    failed++;
                }
                hr = probe_string_option_contract(disp);
                if (FAILED(hr)) {
                    print_hr("FAIL String options", hr);
                    failed++;
                }
            }
            if (run_events) {
                hr = probe_event_contract(disp);
                if (FAILED(hr)) {
                    print_hr("FAIL IConnectionPoint events", hr);
                    failed++;
                }
            }
            if (run_oledrag) {
                hr = probe_ole_dragdrop_contract(disp);
                if (FAILED(hr)) {
                    print_hr("FAIL OLE drag/drop", hr);
                    failed++;
                }
            }
            IDispatch_Release(disp);
        }
    }

    if (run_ownerdraw) {
        disp = NULL;
        hr = create_grid(factory, &disp);
        if (FAILED(hr) || !disp) {
            print_hr("FAIL CreateInstance ownerdraw", hr);
            failed++;
        } else {
            hr = probe_owner_draw_hdc_contract(disp);
            if (FAILED(hr)) {
                print_hr("FAIL OwnerDraw HDC", hr);
                failed++;
            }
            IDispatch_Release(disp);
        }
    }

    if (run_persist) {
        hr = probe_persist(factory);
        if (FAILED(hr)) {
            print_hr("FAIL IPersistStreamInit", hr);
            failed++;
        }
    }

    IClassFactory_Release(factory);
    OleUninitialize();
    printf("SUMMARY container_contract mode=%s failed=%d\n", mode, failed);
    return failed == 0 ? 0 : 1;
}
