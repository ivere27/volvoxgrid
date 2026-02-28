/* stub_synch.c — WaitOnAddress/WakeByAddress* stubs for Wine compatibility.
 * These are Win8+ APIs used by Rust std's parking_lot/thread primitives.
 * Stubs use simple spin+sleep as a fallback. */
#include <windows.h>

__declspec(dllexport) BOOL WINAPI WaitOnAddress(
    volatile VOID *Address, PVOID CompareAddress,
    SIZE_T AddressSize, DWORD dwMilliseconds)
{
    /* Simple spin-wait fallback */
    DWORD elapsed = 0;
    while (memcmp((const void *)Address, CompareAddress, AddressSize) == 0) {
        if (dwMilliseconds != INFINITE && elapsed >= dwMilliseconds)
            return FALSE;
        Sleep(1);
        elapsed++;
    }
    return TRUE;
}

__declspec(dllexport) void WINAPI WakeByAddressAll(PVOID Address) {
    (void)Address;
    /* No-op: spin-wait will notice the change */
}

__declspec(dllexport) void WINAPI WakeByAddressSingle(PVOID Address) {
    (void)Address;
    /* No-op: spin-wait will notice the change */
}

BOOL WINAPI DllMain(HINSTANCE h, DWORD r, LPVOID p) {
    (void)h; (void)r; (void)p;
    return TRUE;
}
