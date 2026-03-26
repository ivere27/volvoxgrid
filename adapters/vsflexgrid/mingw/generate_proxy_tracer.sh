#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

echo "============================================="
echo " Generating TypeLib Extractor C++ source..."
echo "============================================="
cat << 'EOF' > tlb_dumper.cpp
#define _WIN32_WINNT 0x0501
#include <windows.h>
#include <oleauto.h>
#include <stdio.h>

int main(int argc, char** argv) {
    if (argc < 2) {
        printf("Usage: %s <path_to_ocx>\n", argv[0]);
        return 1;
    }
    CoInitialize(NULL);
    ITypeLib* pTypeLib = NULL;
    int len = MultiByteToWideChar(CP_ACP, 0, argv[1], -1, NULL, 0);
    wchar_t* wpath = new wchar_t[len];
    MultiByteToWideChar(CP_ACP, 0, argv[1], -1, wpath, len);
    
    HRESULT hr = LoadTypeLibEx(wpath, REGKIND_NONE, &pTypeLib);
    delete[] wpath;
    if (FAILED(hr)) return 1;
    
    UINT count = pTypeLib->GetTypeInfoCount();
    for (UINT i = 0; i < count; i++) {
        ITypeInfo* pTypeInfo = NULL;
        if (SUCCEEDED(pTypeLib->GetTypeInfo(i, &pTypeInfo))) {
            BSTR bstrName;
            pTypeInfo->GetDocumentation(MEMBERID_NIL, &bstrName, NULL, NULL, NULL);
            printf("\n--- Interface: %ws ---\n", bstrName);
            SysFreeString(bstrName);
            
            TYPEATTR* pTypeAttr;
            if (SUCCEEDED(pTypeInfo->GetTypeAttr(&pTypeAttr))) {
                for (int j = 0; j < pTypeAttr->cFuncs; j++) {
                    FUNCDESC* pFuncDesc;
                    if (SUCCEEDED(pTypeInfo->GetFuncDesc(j, &pFuncDesc))) {
                        BSTR name;
                        UINT names;
                        pTypeInfo->GetNames(pFuncDesc->memid, &name, 1, &names);
                        printf("DISPID: %5d | Func/Prop: %ws\n", pFuncDesc->memid, name);
                        SysFreeString(name);
                        pTypeInfo->ReleaseFuncDesc(pFuncDesc);
                    }
                }
                pTypeInfo->ReleaseTypeAttr(pTypeAttr);
            }
            pTypeInfo->Release();
        }
    }
    pTypeLib->Release();
    CoUninitialize();
    return 0;
}
EOF

echo "============================================="
echo " Generating Advanced PROXY DLL C++ source..."
echo "============================================="
cat << 'EOF' > proxy_dll.cpp
#define _WIN32_WINNT 0x0501
#include <windows.h>
#include <oaidl.h>
#include <stdio.h>

/*
  ADVANCED PROXY WRAPPER (IDispatch Tracer)
  1. Rename vsflex8.ocx -> vsflex8_real.ocx
  2. Compile this file as vsflex8.ocx
  3. Place in the app folder.
  All COM 'Invoke' calls (property sets/gets and methods) will be logged to Z:\tmp\vsflex_proxy.log
*/

void Log(const char* fmt, ...) {
    char buf[2048];
    va_list args;
    va_start(args, fmt);
    vsnprintf(buf, sizeof(buf), fmt, args);
    va_end(args);
    OutputDebugStringA(buf);
    
    // Also append to a file for easier retrieval in Linux/Wine.
    FILE* f = fopen("Z:\\tmp\\vsflex_proxy.log", "a");
    if (f) {
        fprintf(f, "%s\n", buf);
        fclose(f);
    }
}

// --------------------------------------------------------
// IDispatch Proxy (Intercepts Property reads/writes & methods)
// --------------------------------------------------------
class MyDispatchProxy : public IDispatch {
private:
    LONG m_cRef;
    IDispatch* m_pReal;

public:
    MyDispatchProxy(IDispatch* pReal) : m_cRef(1), m_pReal(pReal) {
        m_pReal->AddRef();
        Log("[PROXY] MyDispatchProxy created.");
    }

    ~MyDispatchProxy() {
        m_pReal->Release();
        Log("[PROXY] MyDispatchProxy destroyed.");
    }

    // --- IUnknown ---
    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void **ppvObject) override {
        // Log QI if helpful
        if (riid == IID_IUnknown || riid == IID_IDispatch) {
            *ppvObject = static_cast<IDispatch*>(this);
            AddRef();
            return S_OK;
        }
        // Fallback to real object
        return m_pReal->QueryInterface(riid, ppvObject);
    }

    ULONG STDMETHODCALLTYPE AddRef() override { return InterlockedIncrement(&m_cRef); }
    ULONG STDMETHODCALLTYPE Release() override {
        ULONG res = InterlockedDecrement(&m_cRef);
        if (res == 0) delete this;
        return res;
    }

    // --- IDispatch ---
    HRESULT STDMETHODCALLTYPE GetTypeInfoCount(UINT *pctinfo) override { return m_pReal->GetTypeInfoCount(pctinfo); }
    HRESULT STDMETHODCALLTYPE GetTypeInfo(UINT iTInfo, LCID lcid, ITypeInfo **ppTInfo) override { return m_pReal->GetTypeInfo(iTInfo, lcid, ppTInfo); }

    HRESULT STDMETHODCALLTYPE GetIDsOfNames(REFIID riid, LPOLESTR *rgszNames, UINT cNames, LCID lcid, DISPID *rgDispId) override {
        HRESULT hr = m_pReal->GetIDsOfNames(riid, rgszNames, cNames, lcid, rgDispId);
        if (SUCCEEDED(hr)) {
            Log("[PROXY] GetIDsOfNames: %ws -> DISPID %d", rgszNames[0], rgDispId[0]);
        }
        return hr;
    }

    HRESULT STDMETHODCALLTYPE Invoke(DISPID dispIdMember, REFIID riid, LCID lcid, WORD wFlags, DISPPARAMS *pDispParams, VARIANT *pVarResult, EXCEPINFO *pExcepInfo, UINT *puArgErr) override {
        const char* type = "METHOD";
        if (wFlags & DISPATCH_PROPERTYGET) type = "GET";
        if (wFlags & DISPATCH_PROPERTYPUT) type = "PUT";
        if (wFlags & DISPATCH_PROPERTYPUTREF) type = "PUTREF";

        Log("[PROXY] INVOKE (%s) | DISPID: %d | Args: %d", type, dispIdMember, pDispParams->cArgs);
        
        // Print arguments
        for (UINT i = 0; i < pDispParams->cArgs; i++) {
            VARIANT& arg = pDispParams->rgvarg[i];
            if (arg.vt == VT_I2) Log("  Arg[%d] (I2): %d", i, arg.iVal);
            else if (arg.vt == VT_I4) Log("  Arg[%d] (I4): %ld", i, arg.lVal);
            else if (arg.vt == VT_BSTR && arg.bstrVal) Log("  Arg[%d] (BSTR): %ws", i, arg.bstrVal);
            else if (arg.vt == VT_BOOL) Log("  Arg[%d] (BOOL): %s", i, arg.boolVal ? "TRUE" : "FALSE");
            else if (arg.vt == VT_DISPATCH) Log("  Arg[%d] (IDispatch): 0x%p", i, arg.pdispVal);
            else Log("  Arg[%d] (VT: %d)", i, arg.vt);
        }

        HRESULT hr = m_pReal->Invoke(dispIdMember, riid, lcid, wFlags, pDispParams, pVarResult, pExcepInfo, puArgErr);
        Log("[PROXY] INVOKE DISPID: %d returned 0x%08X", dispIdMember, hr);
        return hr;
    }
};

// --------------------------------------------------------
// IClassFactory Proxy (Intercepts object creation)
// --------------------------------------------------------
class MyClassFactoryProxy : public IClassFactory {
private:
    LONG m_cRef;
    IClassFactory* m_pReal;

public:
    MyClassFactoryProxy(IClassFactory* pReal) : m_cRef(1), m_pReal(pReal) {
        m_pReal->AddRef();
        Log("[PROXY] MyClassFactoryProxy created.");
    }
    ~MyClassFactoryProxy() { m_pReal->Release(); }

    HRESULT STDMETHODCALLTYPE QueryInterface(REFIID riid, void **ppvObject) override {
        if (riid == IID_IUnknown || riid == IID_IClassFactory) {
            *ppvObject = static_cast<IClassFactory*>(this);
            AddRef();
            return S_OK;
        }
        return m_pReal->QueryInterface(riid, ppvObject);
    }

    ULONG STDMETHODCALLTYPE AddRef() override { return InterlockedIncrement(&m_cRef); }
    ULONG STDMETHODCALLTYPE Release() override {
        ULONG res = InterlockedDecrement(&m_cRef);
        if (res == 0) delete this;
        return res;
    }

    HRESULT STDMETHODCALLTYPE CreateInstance(IUnknown *pUnkOuter, REFIID riid, void **ppvObject) override {
        Log("[PROXY] IClassFactory::CreateInstance called.");
        if (pUnkOuter != NULL) return CLASS_E_NOAGGREGATION;

        IDispatch* pRealObj = NULL;
        HRESULT hr = m_pReal->CreateInstance(pUnkOuter, IID_IDispatch, (void**)&pRealObj);
        
        if (SUCCEEDED(hr) && pRealObj) {
            Log("[PROXY] Real object created. Wrapping in MyDispatchProxy!");
            MyDispatchProxy* proxy = new MyDispatchProxy(pRealObj);
            
            hr = proxy->QueryInterface(riid, ppvObject);
            proxy->Release(); 
            pRealObj->Release();
        } else {
            Log("[PROXY] Failed to create real object: 0x%08X", hr);
        }
        return hr;
    }

    HRESULT STDMETHODCALLTYPE LockServer(BOOL fLock) override { return m_pReal->LockServer(fLock); }
};

// --------------------------------------------------------
// DLL Entry point overrides
// --------------------------------------------------------
typedef HRESULT (STDAPICALLTYPE *DllGetClassObject_t)(REFCLSID, REFIID, LPVOID*);
typedef HRESULT (STDAPICALLTYPE *DllCanUnloadNow_t)();

extern "C" __declspec(dllexport) 
HRESULT STDAPICALLTYPE DllGetClassObject(REFCLSID rclsid, REFIID riid, LPVOID* ppv) {
    Log("[PROXY] >>> Intercepted DllGetClassObject!");
    
    HMODULE hReal = LoadLibraryA("vsflex8_real.ocx");
    if (!hReal) {
        Log("[PROXY] FATAL: Could not load vsflex8_real.ocx");
        return CLASS_E_CLASSNOTAVAILABLE;
    }
    
    DllGetClassObject_t realGetClass = (DllGetClassObject_t)GetProcAddress(hReal, "DllGetClassObject");
    if (!realGetClass) {
        Log("[PROXY] FATAL: Could not find DllGetClassObject in real OCX.");
        return CLASS_E_CLASSNOTAVAILABLE;
    }
    
    IClassFactory* pRealCF = NULL;
    HRESULT hr = realGetClass(rclsid, IID_IClassFactory, (void**)&pRealCF);
    
    if (SUCCEEDED(hr) && pRealCF) {
        Log("[PROXY] Successfully intercepted ClassFactory.");
        MyClassFactoryProxy* proxyCF = new MyClassFactoryProxy(pRealCF);
        hr = proxyCF->QueryInterface(riid, ppv);
        proxyCF->Release();
        pRealCF->Release();
    } else {
        Log("[PROXY] Real DllGetClassObject failed: 0x%08X", hr);
    }
    
    return hr;
}

extern "C" __declspec(dllexport) 
HRESULT STDAPICALLTYPE DllCanUnloadNow() {
    HMODULE hReal = GetModuleHandleA("vsflex8_real.ocx");
    if (hReal) {
        DllCanUnloadNow_t realCanUnload = (DllCanUnloadNow_t)GetProcAddress(hReal, "DllCanUnloadNow");
        if (realCanUnload) return realCanUnload();
    }
    return S_FALSE;
}
EOF

echo "============================================="
echo " Compiling with MinGW (i686-w64-mingw32-g++)..."
echo "============================================="

if i686-w64-mingw32-g++ tlb_dumper.cpp -o tlb_dumper.exe -lole32 -loleaut32 -luuid; then
    echo " [+] tlb_dumper.exe compiled successfully."
else
    echo " [-] Failed to compile tlb_dumper.exe."
fi

if i686-w64-mingw32-g++ proxy_dll.cpp -shared -o proxy_vsflex8.ocx -lole32 -loleaut32 -luuid -Wl,--kill-at; then
    echo " [+] proxy_vsflex8.ocx compiled successfully."
else
    echo " [-] Failed to compile proxy DLL."
fi

echo "============================================="
echo " Update Complete! Advanced proxy code is ready."
echo "============================================="
