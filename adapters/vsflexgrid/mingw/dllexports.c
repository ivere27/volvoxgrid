/* VolvoxGrid.ocx — DLL entry points and COM registration.
 *
 * This file provides the four COM standard exports and DllMain.
 * The Rust staticlib is linked in and provides all grid functionality
 * through the native C API (volvox_grid_*).
 */

#define WIN32_LEAN_AND_MEAN
#define COBJMACROS
#define INITGUID
#include <windows.h>
#include <ole2.h>
#include <olectl.h>
#include <stdio.h>
#include "VolvoxGrid_guids.h"

/* Defined in the Rust staticlib */
extern void volvox_grid_init(void);
extern void volvox_grid_shutdown(void);

/* Forward declarations — implemented in volvoxgrid_ocx.c */
extern HRESULT VolvoxGrid_CreateInstance(IUnknown *pOuter, REFIID riid, void **ppv);
extern void vfg_init_object_registry(void);
extern void vfg_shutdown_object_registry(void);

static LONG g_cLocks = 0;
static HMODULE g_hModule = NULL;

/* VolvoxGrid COM identity. */
static const char CLSID_STR[] = "{A7E3B4D1-5C2F-4E8A-B9D6-1F3C7E2A4B5D}";
static const char LIBID_STR[] = "{C9A5D6F3-7E4B-4A0C-B1F8-3B5E9A4C6D7F}";

/* ════════════════════════════════════════════════════════════════ */
/* Class Factory                                                   */
/* ════════════════════════════════════════════════════════════════ */

typedef struct {
    IClassFactoryVtbl *lpVtbl;
    LONG cRef;
} VolvoxGridClassFactory;

static HRESULT STDMETHODCALLTYPE CF_QueryInterface(IClassFactory *This, REFIID riid, void **ppv) {
    if (IsEqualIID(riid, &IID_IUnknown) || IsEqualIID(riid, &IID_IClassFactory)) {
        *ppv = This;
        IClassFactory_AddRef(This);
        return S_OK;
    }
    *ppv = NULL;
    return E_NOINTERFACE;
}

static ULONG STDMETHODCALLTYPE CF_AddRef(IClassFactory *This) {
    VolvoxGridClassFactory *cf = (VolvoxGridClassFactory *)This;
    return InterlockedIncrement(&cf->cRef);
}

static ULONG STDMETHODCALLTYPE CF_Release(IClassFactory *This) {
    VolvoxGridClassFactory *cf = (VolvoxGridClassFactory *)This;
    LONG c = InterlockedDecrement(&cf->cRef);
    if (c == 0) HeapFree(GetProcessHeap(), 0, cf);
    return c;
}

static HRESULT STDMETHODCALLTYPE CF_CreateInstance(IClassFactory *This,
    IUnknown *pOuter, REFIID riid, void **ppv)
{
    (void)This;
    return VolvoxGrid_CreateInstance(pOuter, riid, ppv);
}

static HRESULT STDMETHODCALLTYPE CF_LockServer(IClassFactory *This, BOOL fLock) {
    (void)This;
    if (fLock)
        InterlockedIncrement(&g_cLocks);
    else
        InterlockedDecrement(&g_cLocks);
    return S_OK;
}

static IClassFactoryVtbl g_CFVtbl = {
    CF_QueryInterface,
    CF_AddRef,
    CF_Release,
    CF_CreateInstance,
    CF_LockServer,
};

/* ════════════════════════════════════════════════════════════════ */
/* Registry helpers                                                */
/* ════════════════════════════════════════════════════════════════ */

static HRESULT set_reg_key(HKEY hRoot, const char *subkey, const char *name, const char *value) {
    HKEY hKey;
    LONG rc = RegCreateKeyExA(hRoot, subkey, 0, NULL, 0, KEY_SET_VALUE, NULL, &hKey, NULL);
    if (rc != ERROR_SUCCESS) return SELFREG_E_CLASS;
    if (value)
        RegSetValueExA(hKey, name, 0, REG_SZ, (const BYTE *)value, (DWORD)(strlen(value) + 1));
    RegCloseKey(hKey);
    return S_OK;
}

static void delete_reg_tree(HKEY hRoot, const char *subkey) {
    /* RegDeleteTreeA may not be available in older MinGW — use SHDeleteKeyA or
       manually enumerate.  For simplicity, just delete known leaf keys first. */
    char buf[256];
    snprintf(buf, sizeof(buf), "%s\\InprocServer32", subkey);
    RegDeleteKeyA(hRoot, buf);
    snprintf(buf, sizeof(buf), "%s\\ProgID", subkey);
    RegDeleteKeyA(hRoot, buf);
    snprintf(buf, sizeof(buf), "%s\\VersionIndependentProgID", subkey);
    RegDeleteKeyA(hRoot, buf);
    snprintf(buf, sizeof(buf), "%s\\TypeLib", subkey);
    RegDeleteKeyA(hRoot, buf);
    snprintf(buf, sizeof(buf), "%s\\Control", subkey);
    RegDeleteKeyA(hRoot, buf);
    snprintf(buf, sizeof(buf), "%s\\MiscStatus\\1", subkey);
    RegDeleteKeyA(hRoot, buf);
    snprintf(buf, sizeof(buf), "%s\\MiscStatus", subkey);
    RegDeleteKeyA(hRoot, buf);
    RegDeleteKeyA(hRoot, subkey);
}

static void build_typelib_path(char *dst, size_t dst_cap) {
    char modulePath[MAX_PATH];
    const char *slash;
    size_t prefix_len;

    if (!dst || dst_cap == 0) return;
    dst[0] = '\0';
    GetModuleFileNameA(g_hModule, modulePath, MAX_PATH);
    slash = strrchr(modulePath, '\\');
    if (!slash) slash = strrchr(modulePath, '/');
    prefix_len = slash ? (size_t)(slash - modulePath + 1) : 0;
    if (prefix_len >= dst_cap) prefix_len = dst_cap - 1;
    memcpy(dst, modulePath, prefix_len);
    dst[prefix_len] = '\0';
    strncat(dst, "VolvoxGrid.tlb", dst_cap - strlen(dst) - 1);
}

static HRESULT register_adjacent_typelib(void) {
    char tlbPathA[MAX_PATH];
    WCHAR tlbPathW[MAX_PATH];
    ITypeLib *typeLib = NULL;
    HRESULT hr;

    build_typelib_path(tlbPathA, sizeof(tlbPathA));
    MultiByteToWideChar(CP_ACP, 0, tlbPathA, -1, tlbPathW, MAX_PATH);
    hr = LoadTypeLibEx(tlbPathW, REGKIND_REGISTER, &typeLib);
    if (SUCCEEDED(hr) && typeLib) {
        ITypeLib_Release(typeLib);
    }
    return hr;
}

static void unregister_adjacent_typelib(void) {
#if defined(_WIN64)
    SYSKIND syskind = SYS_WIN64;
#else
    SYSKIND syskind = SYS_WIN32;
#endif
    char tlbPathA[MAX_PATH];
    WCHAR tlbPathW[MAX_PATH];
    ITypeLib *typeLib = NULL;
    TLIBATTR *typeAttr = NULL;

    build_typelib_path(tlbPathA, sizeof(tlbPathA));
    MultiByteToWideChar(CP_ACP, 0, tlbPathA, -1, tlbPathW, MAX_PATH);
    if (SUCCEEDED(LoadTypeLibEx(tlbPathW, REGKIND_NONE, &typeLib)) && typeLib) {
        if (SUCCEEDED(ITypeLib_GetLibAttr(typeLib, &typeAttr)) && typeAttr) {
            UnRegisterTypeLib(
                &typeAttr->guid,
                typeAttr->wMajorVerNum,
                typeAttr->wMinorVerNum,
                LOCALE_NEUTRAL,
                syskind);
            ITypeLib_ReleaseTLibAttr(typeLib, typeAttr);
        }
        ITypeLib_Release(typeLib);
        return;
    }
    UnRegisterTypeLib(&LIBID_VolvoxGridLib, 1, 0, LOCALE_NEUTRAL, syskind);
}

/* ════════════════════════════════════════════════════════════════ */
/* DLL Exports                                                     */
/* ════════════════════════════════════════════════════════════════ */

BOOL WINAPI DllMain(HINSTANCE hinstDLL, DWORD fdwReason, LPVOID lpvReserved) {
    (void)lpvReserved;
    switch (fdwReason) {
    case DLL_PROCESS_ATTACH:
        g_hModule = hinstDLL;
        DisableThreadLibraryCalls(hinstDLL);
        vfg_init_object_registry();
        volvox_grid_init();
        break;
    case DLL_PROCESS_DETACH:
        volvox_grid_shutdown();
        vfg_shutdown_object_registry();
        break;
    }
    return TRUE;
}

STDAPI DllGetClassObject(REFCLSID rclsid, REFIID riid, LPVOID *ppv) {
    if (!IsEqualCLSID(rclsid, &CLSID_VolvoxGrid)) {
        *ppv = NULL;
        return CLASS_E_CLASSNOTAVAILABLE;
    }
    VolvoxGridClassFactory *cf = HeapAlloc(GetProcessHeap(), HEAP_ZERO_MEMORY, sizeof(*cf));
    if (!cf) return E_OUTOFMEMORY;
    cf->lpVtbl = &g_CFVtbl;
    cf->cRef = 1;
    HRESULT hr = IClassFactory_QueryInterface((IClassFactory *)cf, riid, ppv);
    IClassFactory_Release((IClassFactory *)cf);
    return hr;
}

STDAPI DllCanUnloadNow(void) {
    return (g_cLocks == 0) ? S_OK : S_FALSE;
}

STDAPI DllRegisterServer(void) {
    char modulePath[MAX_PATH];
    GetModuleFileNameA(g_hModule, modulePath, MAX_PATH);

    char key[256];
    HRESULT hr;

    /* HKCR\CLSID\{...} */
    snprintf(key, sizeof(key), "CLSID\\%s", CLSID_STR);
    hr = set_reg_key(HKEY_CLASSES_ROOT, key, NULL, "VolvoxGrid Control");
    if (FAILED(hr)) return hr;

    /* InprocServer32 */
    snprintf(key, sizeof(key), "CLSID\\%s\\InprocServer32", CLSID_STR);
    hr = set_reg_key(HKEY_CLASSES_ROOT, key, NULL, modulePath);
    if (FAILED(hr)) return hr;
    hr = set_reg_key(HKEY_CLASSES_ROOT, key, "ThreadingModel", "Apartment");
    if (FAILED(hr)) return hr;

    /* ProgID */
    snprintf(key, sizeof(key), "CLSID\\%s\\ProgID", CLSID_STR);
    hr = set_reg_key(HKEY_CLASSES_ROOT, key, NULL, "VolvoxGrid.VolvoxGridCtrl.1");
    if (FAILED(hr)) return hr;

    /* VersionIndependentProgID */
    snprintf(key, sizeof(key), "CLSID\\%s\\VersionIndependentProgID", CLSID_STR);
    hr = set_reg_key(HKEY_CLASSES_ROOT, key, NULL, "VolvoxGrid.VolvoxGridCtrl");
    if (FAILED(hr)) return hr;

    snprintf(key, sizeof(key), "CLSID\\%s\\TypeLib", CLSID_STR);
    hr = set_reg_key(HKEY_CLASSES_ROOT, key, NULL, LIBID_STR);
    if (FAILED(hr)) return hr;

    /* Control marker */
    snprintf(key, sizeof(key), "CLSID\\%s\\Control", CLSID_STR);
    hr = set_reg_key(HKEY_CLASSES_ROOT, key, NULL, "");
    if (FAILED(hr)) return hr;

    /* Misc status */
    snprintf(key, sizeof(key), "CLSID\\%s\\MiscStatus", CLSID_STR);
    hr = set_reg_key(HKEY_CLASSES_ROOT, key, NULL, "0");
    if (FAILED(hr)) return hr;
    snprintf(key, sizeof(key), "CLSID\\%s\\MiscStatus\\1", CLSID_STR);
    hr = set_reg_key(HKEY_CLASSES_ROOT, key, NULL, "131473");
    if (FAILED(hr)) return hr;

    /* ProgID → CLSID mapping */
    hr = set_reg_key(HKEY_CLASSES_ROOT, "VolvoxGrid.VolvoxGridCtrl.1", NULL, "VolvoxGrid Control");
    if (FAILED(hr)) return hr;
    hr = set_reg_key(HKEY_CLASSES_ROOT, "VolvoxGrid.VolvoxGridCtrl.1\\CLSID", NULL, CLSID_STR);
    if (FAILED(hr)) return hr;

    hr = set_reg_key(HKEY_CLASSES_ROOT, "VolvoxGrid.VolvoxGridCtrl", NULL, "VolvoxGrid Control");
    if (FAILED(hr)) return hr;
    hr = set_reg_key(HKEY_CLASSES_ROOT, "VolvoxGrid.VolvoxGridCtrl\\CLSID", NULL, CLSID_STR);
    if (FAILED(hr)) return hr;
    hr = set_reg_key(HKEY_CLASSES_ROOT, "VolvoxGrid.VolvoxGridCtrl\\CurVer", NULL,
                     "VolvoxGrid.VolvoxGridCtrl.1");
    if (FAILED(hr)) return hr;

    hr = register_adjacent_typelib();
    if (FAILED(hr)) return hr;
    return S_OK;
}

STDAPI DllUnregisterServer(void) {
    char key[256];

    snprintf(key, sizeof(key), "CLSID\\%s", CLSID_STR);
    delete_reg_tree(HKEY_CLASSES_ROOT, key);
    delete_reg_tree(HKEY_CLASSES_ROOT, "VolvoxGrid.VolvoxGridCtrl.1");
    delete_reg_tree(HKEY_CLASSES_ROOT, "VolvoxGrid.VolvoxGridCtrl");
    unregister_adjacent_typelib();

    return S_OK;
}
