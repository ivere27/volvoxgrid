// ADOAdapter.cpp -- ADO/DAO Recordset adapter for VolvoxGrid ActiveX
//
// Provides data binding support: when a VBA/VB6 user sets
//     VolvoxGrid1.DataSource = rs   ' ADO Recordset
// this adapter iterates the recordset and populates the grid.
//
// We use late-bound IDispatch calls so there is no compile-time
// dependency on the ADO type library. This keeps the build simple
// and works with any ADO version.

#include "VolvoxGridCtrl.h"
#include <comutil.h>
#include <oleauto.h>

// ═══════════════════════════════════════════════════════════════════
// IDispatch helper -- invoke a method/property by name
// ═══════════════════════════════════════════════════════════════════

static HRESULT DispatchGet(IDispatch* pDisp, LPCOLESTR name, VARIANT* pResult)
{
    if (!pDisp || !pResult) return E_POINTER;

    DISPID dispid = 0;
    LPOLESTR nameArr[] = { const_cast<LPOLESTR>(name) };
    HRESULT hr = pDisp->GetIDsOfNames(IID_NULL, nameArr, 1,
                                       LOCALE_USER_DEFAULT, &dispid);
    if (FAILED(hr)) return hr;

    DISPPARAMS dp = { nullptr, nullptr, 0, 0 };
    return pDisp->Invoke(dispid, IID_NULL, LOCALE_USER_DEFAULT,
                         DISPATCH_PROPERTYGET, &dp, pResult, nullptr, nullptr);
}

static HRESULT DispatchCall(IDispatch* pDisp, LPCOLESTR name,
                            VARIANT* args = nullptr, int nArgs = 0)
{
    if (!pDisp) return E_POINTER;

    DISPID dispid = 0;
    LPOLESTR nameArr[] = { const_cast<LPOLESTR>(name) };
    HRESULT hr = pDisp->GetIDsOfNames(IID_NULL, nameArr, 1,
                                       LOCALE_USER_DEFAULT, &dispid);
    if (FAILED(hr)) return hr;

    DISPPARAMS dp = { args, nullptr, (UINT)nArgs, 0 };
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
    return pDisp->Invoke(dispid, IID_NULL, LOCALE_USER_DEFAULT,
                         DISPATCH_PROPERTYGET, &dp, pResult, nullptr, nullptr);
}

// ═══════════════════════════════════════════════════════════════════
// ADOAdapter_BindRecordset
//
// Called from CVolvoxGridCtrl::putref_DataSource when the user
// assigns an ADO Recordset to the control.
// ═══════════════════════════════════════════════════════════════════

HRESULT ADOAdapter_BindRecordset(CVolvoxGridCtrl* ctrl, IDispatch* pRS)
{
    if (!ctrl) return E_POINTER;
    if (!pRS) {
        // Unbind -- clear the grid
        ctrl->Clear(flexClearEverything);
        return S_OK;
    }

    HRESULT hr;
    VARIANT v;
    VariantInit(&v);

    // ---------------------------------------------------------------
    // 1. Get the Fields collection and field count
    // ---------------------------------------------------------------
    VARIANT vFields;
    VariantInit(&vFields);
    hr = DispatchGet(pRS, L"Fields", &vFields);
    if (FAILED(hr) || vFields.vt != VT_DISPATCH || !vFields.pdispVal) {
        VariantClear(&vFields);
        return E_FAIL;
    }

    IDispatch* pFields = vFields.pdispVal;

    VARIANT vCount;
    VariantInit(&vCount);
    hr = DispatchGet(pFields, L"Count", &vCount);
    if (FAILED(hr)) {
        VariantClear(&vFields);
        return E_FAIL;
    }

    long fieldCount = 0;
    if (vCount.vt == VT_I4) fieldCount = vCount.lVal;
    else if (vCount.vt == VT_I2) fieldCount = vCount.iVal;
    VariantClear(&vCount);

    if (fieldCount <= 0) {
        VariantClear(&vFields);
        return S_OK;
    }

    // ---------------------------------------------------------------
    // 2. Move to first record and count rows
    // ---------------------------------------------------------------
    DispatchCall(pRS, L"MoveFirst");

    // Count records: try RecordCount property first
    long recordCount = 0;
    VARIANT vRecCount;
    VariantInit(&vRecCount);
    hr = DispatchGet(pRS, L"RecordCount", &vRecCount);
    if (SUCCEEDED(hr) && (vRecCount.vt == VT_I4 || vRecCount.vt == VT_I2)) {
        recordCount = (vRecCount.vt == VT_I4) ? vRecCount.lVal : vRecCount.iVal;
    }
    VariantClear(&vRecCount);

    // If RecordCount is -1 (forward-only), scan the recordset
    if (recordCount <= 0) {
        recordCount = 0;
        while (true) {
            VARIANT vEOF;
            VariantInit(&vEOF);
            DispatchGet(pRS, L"EOF", &vEOF);
            bool isEOF = (vEOF.vt == VT_BOOL && vEOF.boolVal != VARIANT_FALSE);
            VariantClear(&vEOF);
            if (isEOF) break;
            recordCount++;
            DispatchCall(pRS, L"MoveNext");
        }
        DispatchCall(pRS, L"MoveFirst");
    }

    // ---------------------------------------------------------------
    // 3. Configure the grid dimensions
    // ---------------------------------------------------------------
    // Suppress redraw while populating
    ctrl->put_Redraw(VARIANT_FALSE);

    ctrl->put_Rows(recordCount + 1);  // +1 for header row
    ctrl->put_Cols(fieldCount);
    ctrl->put_FixedRows(1);
    ctrl->put_FixedCols(0);

    // ---------------------------------------------------------------
    // 4. Set column headers from field names
    // ---------------------------------------------------------------
    for (long col = 0; col < fieldCount; col++) {
        VARIANT vField;
        VariantInit(&vField);
        hr = DispatchGetIndexed(pFields, L"Item", col, &vField);
        if (SUCCEEDED(hr) && vField.vt == VT_DISPATCH && vField.pdispVal) {
            VARIANT vName;
            VariantInit(&vName);
            DispatchGet(vField.pdispVal, L"Name", &vName);
            if (vName.vt == VT_BSTR && vName.bstrVal) {
                ctrl->SetTextMatrix(0, col, vName.bstrVal);
            }
            VariantClear(&vName);
        }
        VariantClear(&vField);
    }

    // ---------------------------------------------------------------
    // 5. Iterate rows and populate cell data
    // ---------------------------------------------------------------
    long row = 1;
    while (true) {
        VARIANT vEOF;
        VariantInit(&vEOF);
        DispatchGet(pRS, L"EOF", &vEOF);
        bool isEOF = (vEOF.vt == VT_BOOL && vEOF.boolVal != VARIANT_FALSE);
        VariantClear(&vEOF);
        if (isEOF) break;

        for (long col = 0; col < fieldCount; col++) {
            VARIANT vField;
            VariantInit(&vField);
            hr = DispatchGetIndexed(pFields, L"Item", col, &vField);
            if (SUCCEEDED(hr) && vField.vt == VT_DISPATCH && vField.pdispVal) {
                VARIANT vValue;
                VariantInit(&vValue);
                DispatchGet(vField.pdispVal, L"Value", &vValue);

                // Convert to BSTR for SetTextMatrix
                VARIANT vStr;
                VariantInit(&vStr);
                if (SUCCEEDED(VariantChangeType(&vStr, &vValue, 0, VT_BSTR))) {
                    ctrl->SetTextMatrix(row, col, vStr.bstrVal);
                }
                VariantClear(&vStr);
                VariantClear(&vValue);
            }
            VariantClear(&vField);
        }

        DispatchCall(pRS, L"MoveNext");
        row++;
    }

    // ---------------------------------------------------------------
    // 6. Re-enable redraw and refresh
    // ---------------------------------------------------------------
    ctrl->put_Redraw(VARIANT_TRUE);
    ctrl->Refresh();

    VariantClear(&vFields);
    return S_OK;
}
