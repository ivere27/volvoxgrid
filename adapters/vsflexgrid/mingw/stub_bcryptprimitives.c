/* stub_bcryptprimitives.c — ProcessPrng stub for Wine compatibility.
 * Delegates to RtlGenRandom (SystemFunction036) from advapi32. */
#include <windows.h>

typedef BOOLEAN (WINAPI *RtlGenRandom_t)(PVOID, ULONG);

__declspec(dllexport) BOOL __stdcall ProcessPrng(PBYTE pbData, SIZE_T cbData) {
    HMODULE hAdv = LoadLibraryA("advapi32.dll");
    if (!hAdv) return FALSE;
    RtlGenRandom_t fn = (RtlGenRandom_t)GetProcAddress(hAdv, "SystemFunction036");
    if (!fn) return FALSE;
    return fn(pbData, (ULONG)cbData);
}

BOOL WINAPI DllMain(HINSTANCE h, DWORD r, LPVOID p) {
    (void)h; (void)r; (void)p;
    return TRUE;
}
