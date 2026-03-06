/* windows_mingw_compat.c
 *
 * MinGW + Rust raw-dylib can emit imports for Win8+/Win10 APIs
 * (bcryptprimitives!ProcessPrng, WaitOnAddress/WakeByAddress*).
 * Provide local fallbacks so the plugin does not depend on those DLLs.
 */

#include <windows.h>
#include <string.h>

typedef BOOLEAN (WINAPI *RtlGenRandom_t)(PVOID, ULONG);

BOOL __stdcall ProcessPrng(PBYTE pbData, SIZE_T cbData) {
    static RtlGenRandom_t fn = NULL;
    if (!fn) {
        HMODULE h = GetModuleHandleA("advapi32.dll");
        if (!h) h = LoadLibraryA("advapi32.dll");
        if (h) fn = (RtlGenRandom_t)GetProcAddress(h, "SystemFunction036");
    }
    return fn ? fn(pbData, (ULONG)cbData) : FALSE;
}

BOOL __stdcall WaitOnAddress(volatile VOID *Address, PVOID CompareAddress,
                             SIZE_T AddressSize, DWORD dwMilliseconds) {
    DWORD elapsed = 0;
    while (memcmp((const void *)Address, CompareAddress, AddressSize) == 0) {
        if (dwMilliseconds != INFINITE && elapsed >= dwMilliseconds) {
            return FALSE;
        }
        Sleep(elapsed < 16 ? 0 : 1);
        elapsed++;
    }
    return TRUE;
}

void __stdcall WakeByAddressAll(PVOID Address) {
    (void)Address;
}

void __stdcall WakeByAddressSingle(PVOID Address) {
    (void)Address;
}

/* Called from Rust to force this object file into the final link. */
void __stdcall volvoxgrid_windows_mingw_compat_force_link(void) {}

/* raw-dylib callers may reference __imp_* directly (especially i686). */
#if defined(__i386__) || defined(_M_IX86)
__asm__(".section .rdata\n"
        ".globl __imp_ProcessPrng\n"
        "__imp_ProcessPrng:         .long _ProcessPrng@8\n"
        ".globl __imp_WaitOnAddress\n"
        "__imp_WaitOnAddress:       .long _WaitOnAddress@16\n"
        ".globl __imp_WakeByAddressAll\n"
        "__imp_WakeByAddressAll:    .long _WakeByAddressAll@4\n"
        ".globl __imp_WakeByAddressSingle\n"
        "__imp_WakeByAddressSingle: .long _WakeByAddressSingle@4\n");
#elif defined(__x86_64__) || defined(_M_X64)
__asm__(".section .rdata\n"
        ".globl __imp_ProcessPrng\n"
        "__imp_ProcessPrng:         .quad ProcessPrng\n"
        ".globl __imp_WaitOnAddress\n"
        "__imp_WaitOnAddress:       .quad WaitOnAddress\n"
        ".globl __imp_WakeByAddressAll\n"
        "__imp_WakeByAddressAll:    .quad WakeByAddressAll\n"
        ".globl __imp_WakeByAddressSingle\n"
        "__imp_WakeByAddressSingle: .quad WakeByAddressSingle\n");
#endif
