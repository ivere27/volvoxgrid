// ADOAdapter.cpp -- ADO/DAO Recordset adapter for VolvoxGrid ActiveX
//
// Provides data binding support for the ADO-facing ActiveX surface. The
// adapter remains late-bound so the control does not require a compile-time
// dependency on specific ADO type libraries.

#include "VolvoxGridCtrl.h"
#include <comutil.h>
#include <oleauto.h>

static HRESULT DispatchGet(IDispatch* pDisp, LPCOLESTR name, VARIANT* pResult)
{
    if (!pDisp || !pResult) return E_POINTER;

    DISPID dispid = 0;
    LPOLESTR nameArr[] = { const_cast<LPOLESTR>(name) };
    HRESULT hr = pDisp->GetIDsOfNames(IID_NULL, nameArr, 1,
                                      LOCALE_USER_DEFAULT, &dispid);
    if (FAILED(hr)) return hr;

    DISPPARAMS dp = { nullptr, nullptr, 0, 0 };
    VariantInit(pResult);
    return pDisp->Invoke(dispid, IID_NULL, LOCALE_USER_DEFAULT,
                         DISPATCH_PROPERTYGET, &dp, pResult, nullptr, nullptr);
}

static HRESULT DispatchGetByDispid(IDispatch* pDisp, DISPID dispid, VARIANT* pResult)
{
    if (!pDisp || !pResult) return E_POINTER;
    DISPPARAMS dp = { nullptr, nullptr, 0, 0 };
    VariantInit(pResult);
    return pDisp->Invoke(dispid, IID_NULL, LOCALE_USER_DEFAULT,
                         DISPATCH_PROPERTYGET, &dp, pResult, nullptr, nullptr);
}

static HRESULT DispatchCall(IDispatch* pDisp, LPCOLESTR name)
{
    if (!pDisp) return E_POINTER;

    DISPID dispid = 0;
    LPOLESTR nameArr[] = { const_cast<LPOLESTR>(name) };
    HRESULT hr = pDisp->GetIDsOfNames(IID_NULL, nameArr, 1,
                                      LOCALE_USER_DEFAULT, &dispid);
    if (FAILED(hr)) return hr;

    DISPPARAMS dp = { nullptr, nullptr, 0, 0 };
    return pDisp->Invoke(dispid, IID_NULL, LOCALE_USER_DEFAULT,
                         DISPATCH_METHOD, &dp, nullptr, nullptr, nullptr);
}

static HRESULT DispatchGetIndexed(IDispatch* pDisp, LPCOLESTR name,
                                  long index, VARIANT* pResult)
{
    if (!pDisp || !pResult) return E_POINTER;

    DISPID dispid = 0;
    LPOLESTR nameArr[] = { const_cast<LPOLESTR>(name) };
    HRESULT hr = pDisp->GetIDsOfNames(IID_NULL, nameArr, 1,
                                      LOCALE_USER_DEFAULT, &dispid);
    if (FAILED(hr)) return hr;

    VARIANT arg;
    VariantInit(&arg);
    arg.vt = VT_I4;
    arg.lVal = index;

    DISPPARAMS dp = { &arg, nullptr, 1, 0 };
    VariantInit(pResult);
    return pDisp->Invoke(dispid, IID_NULL, LOCALE_USER_DEFAULT,
                         DISPATCH_PROPERTYGET, &dp, pResult, nullptr, nullptr);
}

static bool VariantIsTrue(const VARIANT& value)
{
    return value.vt == VT_BOOL && value.boolVal != VARIANT_FALSE;
}

static CComBSTR VariantToDisplayBstr(const VARIANT& value)
{
    if (value.vt == VT_EMPTY || value.vt == VT_NULL) {
        return CComBSTR(L"");
    }

    CComVariant converted;
    if (SUCCEEDED(VariantChangeType(&converted, const_cast<VARIANT*>(&value), 0, VT_BSTR))) {
        return CComBSTR(converted.bstrVal ? converted.bstrVal : L"");
    }
    return CComBSTR(L"");
}

static HRESULT ResolveRecordset(IDispatch* pDataSource, BSTR dataMember, IDispatch** ppRecordset)
{
    if (!ppRecordset) return E_POINTER;
    *ppRecordset = nullptr;
    if (!pDataSource) return S_OK;

    if (dataMember && SysStringLen(dataMember) > 0) {
        DISPID dispid = 0;
        LPOLESTR nameArr[] = { dataMember };
        HRESULT hr = pDataSource->GetIDsOfNames(IID_NULL, nameArr, 1,
                                                LOCALE_USER_DEFAULT, &dispid);
        if (SUCCEEDED(hr)) {
            CComVariant v;
            hr = DispatchGetByDispid(pDataSource, dispid, &v);
            if (SUCCEEDED(hr) && v.vt == VT_DISPATCH && v.pdispVal) {
                *ppRecordset = v.pdispVal;
                (*ppRecordset)->AddRef();
                return S_OK;
            }
        }
    }

    {
        CComVariant v;
        HRESULT hr = DispatchGet(pDataSource, L"Recordset", &v);
        if (SUCCEEDED(hr) && v.vt == VT_DISPATCH && v.pdispVal) {
            *ppRecordset = v.pdispVal;
            (*ppRecordset)->AddRef();
            return S_OK;
        }
    }

    {
        CComVariant v;
        HRESULT hr = DispatchGet(pDataSource, L"Fields", &v);
        if (SUCCEEDED(hr) && v.vt == VT_DISPATCH && v.pdispVal) {
            *ppRecordset = pDataSource;
            (*ppRecordset)->AddRef();
            return S_OK;
        }
    }

    return DISP_E_TYPEMISMATCH;
}

HRESULT ADOAdapter_BindRecordset(CVolvoxGridCtrl* ctrl, IDispatch* pRS)
{
    if (!ctrl) return E_POINTER;
    if (!pRS) {
        ctrl->Clear(flexClearEverything);
        ctrl->put_Rows(1);
        ctrl->put_Cols(0);
        return S_OK;
    }

    VARIANT_BOOL virtualData = VARIANT_FALSE;
    if (SUCCEEDED(ctrl->get_VirtualData(&virtualData)) && virtualData != VARIANT_FALSE) {
        long rows = 0;
        long cols = 0;
        if (SUCCEEDED(ctrl->get_Rows(&rows)) && rows < 50) {
            ctrl->put_Rows(50);
        }
        if (SUCCEEDED(ctrl->get_Cols(&cols)) && cols < 5) {
            ctrl->put_Cols(5);
        }
        return S_OK;
    }

    CComVariant vFields;
    HRESULT hr = DispatchGet(pRS, L"Fields", &vFields);
    if (FAILED(hr) || vFields.vt != VT_DISPATCH || !vFields.pdispVal) {
        return E_FAIL;
    }

    CComVariant vCount;
    hr = DispatchGet(vFields.pdispVal, L"Count", &vCount);
    if (FAILED(hr)) return E_FAIL;

    long fieldCount = 0;
    if (vCount.vt == VT_I4) fieldCount = vCount.lVal;
    else if (vCount.vt == VT_I2) fieldCount = vCount.iVal;
    else fieldCount = vCount.intVal;

    ctrl->put_Redraw(VARIANT_FALSE);
    ctrl->put_Cols(fieldCount > 0 ? fieldCount : 0);
    ctrl->put_Rows(1);
    ctrl->put_FixedRows(1);
    ctrl->put_FixedCols(0);

    for (long col = 0; col < fieldCount; ++col) {
        CComVariant vField;
        hr = DispatchGetIndexed(vFields.pdispVal, L"Item", col, &vField);
        if (SUCCEEDED(hr) && vField.vt == VT_DISPATCH && vField.pdispVal) {
            CComVariant vName;
            if (SUCCEEDED(DispatchGet(vField.pdispVal, L"Name", &vName)) &&
                vName.vt == VT_BSTR && vName.bstrVal) {
                ctrl->SetTextMatrix(0, col, vName.bstrVal);
            }
        }
    }

    DispatchCall(pRS, L"MoveFirst");

    long recordCount = -1;
    CComVariant vRecordCount;
    hr = DispatchGet(pRS, L"RecordCount", &vRecordCount);
    if (SUCCEEDED(hr)) {
        if (vRecordCount.vt == VT_I4) recordCount = vRecordCount.lVal;
        else if (vRecordCount.vt == VT_I2) recordCount = vRecordCount.iVal;
    }
    if (recordCount > 0) {
        ctrl->put_Rows(recordCount + 1);
    }

    long row = 1;
    while (true) {
        CComVariant vEOF;
        hr = DispatchGet(pRS, L"EOF", &vEOF);
        if (FAILED(hr) || VariantIsTrue(vEOF)) break;

        if (recordCount <= 0) {
            ctrl->put_Rows(row + 1);
        }

        for (long col = 0; col < fieldCount; ++col) {
            CComVariant vField;
            hr = DispatchGetIndexed(vFields.pdispVal, L"Item", col, &vField);
            if (SUCCEEDED(hr) && vField.vt == VT_DISPATCH && vField.pdispVal) {
                CComVariant vValue;
                if (SUCCEEDED(DispatchGet(vField.pdispVal, L"Value", &vValue))) {
                    CComBSTR text = VariantToDisplayBstr(vValue);
                    ctrl->SetTextMatrix(row, col, text);
                }
            }
        }

        ++row;
        if (FAILED(DispatchCall(pRS, L"MoveNext"))) break;
    }

    if (recordCount > 0 && row != recordCount + 1) {
        ctrl->put_Rows(row);
    }

    ctrl->put_Redraw(VARIANT_TRUE);
    return S_OK;
}

HRESULT ADOAdapter_BindDataSource(CVolvoxGridCtrl* ctrl, IDispatch* pDataSource, BSTR dataMember)
{
    if (!ctrl) return E_POINTER;
    if (!pDataSource) {
        return ADOAdapter_BindRecordset(ctrl, nullptr);
    }

    CComPtr<IDispatch> recordset;
    HRESULT hr = ResolveRecordset(pDataSource, dataMember, &recordset);
    if (FAILED(hr)) return hr;
    return ADOAdapter_BindRecordset(ctrl, recordset);
}
