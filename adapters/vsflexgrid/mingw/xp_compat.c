/* xp_compat.c — Static stubs for Vista+/Win8+/Win10+ APIs
 *
 * Provides fallback implementations so the OCX loads on Windows XP (NT 5.1).
 * These override DLL imports that would otherwise fail on XP because the
 * functions don't exist in that OS version.
 *
 * Two mechanisms:
 *   1. KERNEL32 stdcall functions: direct _Name@N definitions (override import libs)
 *   2. raw-dylib functions: __imp_ pointer symbols (override Rust raw-dylib stubs)
 */

#include <windows.h>
#include <string.h>

/* These APIs are Vista+ and their public types are gated by _WIN32_WINNT. */
#if defined(_WIN32_WINNT) && (_WIN32_WINNT >= 0x0600)
#define VX_HAS_VISTA_API_TYPES 1
#else
#define VX_HAS_VISTA_API_TYPES 0
#endif

#if VX_HAS_VISTA_API_TYPES
typedef LPINIT_ONCE VX_LPINIT_ONCE;
typedef FILE_INFO_BY_HANDLE_CLASS VX_FILE_INFO_BY_HANDLE_CLASS;
typedef PZZWSTR VX_PZZWSTR;
typedef LPPROC_THREAD_ATTRIBUTE_LIST VX_LPPROC_THREAD_ATTRIBUTE_LIST;
#else
typedef PVOID VX_LPINIT_ONCE;
typedef int VX_FILE_INFO_BY_HANDLE_CLASS;
typedef WCHAR *VX_PZZWSTR;
typedef PVOID VX_LPPROC_THREAD_ATTRIBUTE_LIST;
#endif

/* ═══════════════════════════════════════════════════════════════════════════
 * INIT_ONCE constants (not defined on XP headers)
 * ═══════════════════════════════════════════════════════════════════════════ */
#ifndef INIT_ONCE_CHECK_ONLY
#define INIT_ONCE_CHECK_ONLY    0x00000001
#endif
#ifndef INIT_ONCE_ASYNC
#define INIT_ONCE_ASYNC         0x00000002
#endif
#ifndef INIT_ONCE_INIT_FAILED
#define INIT_ONCE_INIT_FAILED   0x00000004
#endif
#ifndef CREATE_WAITABLE_TIMER_MANUAL_RESET
#define CREATE_WAITABLE_TIMER_MANUAL_RESET  0x00000001
#endif
#ifndef CSTR_LESS_THAN
#define CSTR_LESS_THAN    1
#define CSTR_EQUAL        2
#define CSTR_GREATER_THAN 3
#endif

/* ═══════════════════════════════════════════════════════════════════════════
 * 1. ProcessPrng  (bcryptprimitives.dll — Win10+)
 *    Fallback: advapi32!SystemFunction036 (RtlGenRandom), available since Win2000
 * ═══════════════════════════════════════════════════════════════════════════ */
typedef BOOLEAN (WINAPI *RtlGenRandom_t)(PVOID, ULONG);

BOOL __stdcall impl_ProcessPrng(PBYTE pbData, SIZE_T cbData) {
    static RtlGenRandom_t fn = NULL;
    if (!fn) {
        HMODULE h = GetModuleHandleA("advapi32.dll");
        if (!h) h = LoadLibraryA("advapi32.dll");
        if (h) fn = (RtlGenRandom_t)GetProcAddress(h, "SystemFunction036");
    }
    return fn ? fn(pbData, (ULONG)cbData) : FALSE;
}

/* Export direct symbols so x86_64 links resolve without bcryptprimitives imports. */
BOOL __stdcall ProcessPrng(PBYTE pbData, SIZE_T cbData) {
    return impl_ProcessPrng(pbData, cbData);
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 2. WaitOnAddress / WakeByAddress*  (api-ms-win-core-synch — Win8+)
 *    Fallback: spin-wait with Sleep(0)/Sleep(1)
 * ═══════════════════════════════════════════════════════════════════════════ */
BOOL __stdcall impl_WaitOnAddress(volatile VOID *Address, PVOID CompareAddress,
                                  SIZE_T AddressSize, DWORD dwMilliseconds) {
    DWORD elapsed = 0;
    while (memcmp((const void *)Address, CompareAddress, AddressSize) == 0) {
        if (dwMilliseconds != INFINITE && elapsed >= dwMilliseconds)
            return FALSE;
        Sleep(elapsed < 16 ? 0 : 1);  /* yield first, then sleep */
        elapsed++;
    }
    return TRUE;
}

void __stdcall impl_WakeByAddressAll(PVOID Address)   { (void)Address; }
void __stdcall impl_WakeByAddressSingle(PVOID Address) { (void)Address; }

/* Export direct symbols so x86_64 links resolve without api-ms synch imports. */
BOOL __stdcall WaitOnAddress(volatile VOID *Address, PVOID CompareAddress,
                             SIZE_T AddressSize, DWORD dwMilliseconds) {
    return impl_WaitOnAddress(Address, CompareAddress, AddressSize, dwMilliseconds);
}

void __stdcall WakeByAddressAll(PVOID Address) {
    impl_WakeByAddressAll(Address);
}

void __stdcall WakeByAddressSingle(PVOID Address) {
    impl_WakeByAddressSingle(Address);
}

/* ═══════════════════════════════════════════════════════════════════════════
 * __imp_ pointers for raw-dylib imports (ProcessPrng, WaitOnAddress, etc.)
 *
 * Rust references these as __imp_FuncName (no stdcall decoration).
 * On i686, C symbols get a _ prefix, but __imp_ names must be exact,
 * so we use inline asm to define them.
 * ═══════════════════════════════════════════════════════════════════════════ */
#if defined(__i386__) || defined(_M_IX86)
  /* i686: stdcall names are _func@N, pointer is 4 bytes */
  __asm__(".section .rdata\n"
          ".globl __imp_ProcessPrng\n"
          "__imp_ProcessPrng:         .long _impl_ProcessPrng@8\n"
          ".globl __imp_WaitOnAddress\n"
          "__imp_WaitOnAddress:       .long _impl_WaitOnAddress@16\n"
          ".globl __imp_WakeByAddressAll\n"
          "__imp_WakeByAddressAll:    .long _impl_WakeByAddressAll@4\n"
          ".globl __imp_WakeByAddressSingle\n"
          "__imp_WakeByAddressSingle: .long _impl_WakeByAddressSingle@4\n");
#elif defined(__x86_64__) || defined(_M_X64)
  /* x86_64: no _ prefix, pointer is 8 bytes */
  __asm__(".section .rdata\n"
          ".globl __imp_ProcessPrng\n"
          "__imp_ProcessPrng:       .quad impl_ProcessPrng\n"
          ".globl __imp_WaitOnAddress\n"
          "__imp_WaitOnAddress:     .quad impl_WaitOnAddress\n"
          ".globl __imp_WakeByAddressAll\n"
          "__imp_WakeByAddressAll:  .quad impl_WakeByAddressAll\n"
          ".globl __imp_WakeByAddressSingle\n"
          "__imp_WakeByAddressSingle: .quad impl_WakeByAddressSingle\n");
#endif

/* ═══════════════════════════════════════════════════════════════════════════
 * 3. GetSystemTimePreciseAsFileTime  (KERNEL32 — Win8+)
 *    Fallback: GetSystemTimeAsFileTime (microsecond precision, available since NT 3.1)
 * ═══════════════════════════════════════════════════════════════════════════ */
void WINAPI GetSystemTimePreciseAsFileTime(LPFILETIME lpSystemTimeAsFileTime) {
    GetSystemTimeAsFileTime(lpSystemTimeAsFileTime);
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 4. CompareStringOrdinal  (KERNEL32 — Vista+)
 *    Fallback: manual ordinal comparison (handles case-insensitive ASCII)
 * ═══════════════════════════════════════════════════════════════════════════ */
int WINAPI CompareStringOrdinal(LPCWCH lpString1, int cchCount1,
                                LPCWCH lpString2, int cchCount2,
                                BOOL bIgnoreCase) {
    int len1 = (cchCount1 == -1) ? (int)wcslen(lpString1) : cchCount1;
    int len2 = (cchCount2 == -1) ? (int)wcslen(lpString2) : cchCount2;
    int minLen = len1 < len2 ? len1 : len2;

    for (int i = 0; i < minLen; i++) {
        WCHAR c1 = lpString1[i], c2 = lpString2[i];
        if (bIgnoreCase) {
            if (c1 >= L'A' && c1 <= L'Z') c1 += 32;
            if (c2 >= L'A' && c2 <= L'Z') c2 += 32;
        }
        if (c1 < c2) return CSTR_LESS_THAN;
        if (c1 > c2) return CSTR_GREATER_THAN;
    }
    if (len1 < len2) return CSTR_LESS_THAN;
    if (len1 > len2) return CSTR_GREATER_THAN;
    return CSTR_EQUAL;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 5. InitOnceBeginInitialize / InitOnceComplete  (KERNEL32 — Vista+)
 *    Fallback: InterlockedCompareExchange spin-lock
 *
 *    INIT_ONCE is a pointer-sized union. We treat it as a volatile LONG:
 *      0 = not started, 1 = in progress, 2 = complete
 * ═══════════════════════════════════════════════════════════════════════════ */
BOOL WINAPI InitOnceBeginInitialize(VX_LPINIT_ONCE lpInitOnce, DWORD dwFlags,
                                    PBOOL fPending, LPVOID *lpContext) {
    volatile LONG *state = (volatile LONG *)lpInitOnce;

    if (dwFlags & INIT_ONCE_CHECK_ONLY) {
        if (*state == 2) {
            *fPending = FALSE;
            if (lpContext) *lpContext = NULL;
            return TRUE;
        }
        SetLastError(ERROR_GEN_FAILURE);
        return FALSE;
    }

    for (;;) {
        LONG prev = InterlockedCompareExchange(state, 1, 0);
        if (prev == 0) {
            /* We are the initializer */
            *fPending = TRUE;
            if (lpContext) *lpContext = NULL;
            return TRUE;
        }
        if (prev == 2) {
            /* Already initialized */
            *fPending = FALSE;
            if (lpContext) *lpContext = NULL;
            return TRUE;
        }
        /* prev == 1: another thread initializing — spin */
        Sleep(0);
    }
}

BOOL WINAPI InitOnceComplete(VX_LPINIT_ONCE lpInitOnce, DWORD dwFlags, LPVOID lpContext) {
    volatile LONG *state = (volatile LONG *)lpInitOnce;
    (void)lpContext;

    if (dwFlags & INIT_ONCE_INIT_FAILED) {
        InterlockedExchange(state, 0);  /* reset */
    } else {
        InterlockedExchange(state, 2);  /* mark done */
    }
    return TRUE;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 6. CreateWaitableTimerExW  (KERNEL32 — Vista+)
 *    Fallback: CreateWaitableTimerW (available since Win2000)
 * ═══════════════════════════════════════════════════════════════════════════ */
HANDLE WINAPI CreateWaitableTimerExW(LPSECURITY_ATTRIBUTES lpTimerAttributes,
                                     LPCWSTR lpTimerName,
                                     DWORD dwFlags, DWORD dwDesiredAccess) {
    (void)dwDesiredAccess;
    BOOL bManualReset = (dwFlags & CREATE_WAITABLE_TIMER_MANUAL_RESET) ? TRUE : FALSE;
    return CreateWaitableTimerW(lpTimerAttributes, bManualReset, lpTimerName);
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 7. CreateSymbolicLinkW  (KERNEL32 — Vista+)
 *    Stub: not supported on XP, return failure
 * ═══════════════════════════════════════════════════════════════════════════ */
BOOLEAN WINAPI CreateSymbolicLinkW(LPCWSTR lpSymlinkFileName,
                                   LPCWSTR lpTargetFileName, DWORD dwFlags) {
    (void)lpSymlinkFileName; (void)lpTargetFileName; (void)dwFlags;
    SetLastError(ERROR_NOT_SUPPORTED);
    return FALSE;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 8. GetFinalPathNameByHandleW  (KERNEL32 — Vista+)
 *    Stub: return error (our OCX doesn't use std::fs::canonicalize)
 * ═══════════════════════════════════════════════════════════════════════════ */
DWORD WINAPI GetFinalPathNameByHandleW(HANDLE hFile, LPWSTR lpszFilePath,
                                       DWORD cchFilePath, DWORD dwFlags) {
    (void)hFile; (void)lpszFilePath; (void)cchFilePath; (void)dwFlags;
    SetLastError(ERROR_NOT_SUPPORTED);
    return 0;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 9. GetFileInformationByHandleEx  (KERNEL32 — Vista+)
 *    Stub: return error (our OCX doesn't do file I/O)
 * ═══════════════════════════════════════════════════════════════════════════ */
BOOL WINAPI GetFileInformationByHandleEx(HANDLE hFile, VX_FILE_INFO_BY_HANDLE_CLASS FileInformationClass,
                                         LPVOID lpFileInformation,
                                         DWORD dwBufferSize) {
    (void)hFile; (void)FileInformationClass;
    (void)lpFileInformation; (void)dwBufferSize;
    SetLastError(ERROR_NOT_SUPPORTED);
    return FALSE;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 10. SetFileInformationByHandle  (KERNEL32 — Vista+)
 *     Stub: return error (our OCX doesn't do file I/O)
 * ═══════════════════════════════════════════════════════════════════════════ */
BOOL WINAPI SetFileInformationByHandle(HANDLE hFile, VX_FILE_INFO_BY_HANDLE_CLASS FileInformationClass,
                                       LPVOID lpFileInformation,
                                       DWORD dwBufferSize) {
    (void)hFile; (void)FileInformationClass;
    (void)lpFileInformation; (void)dwBufferSize;
    SetLastError(ERROR_NOT_SUPPORTED);
    return FALSE;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 11. GetUserPreferredUILanguages  (KERNEL32 — Vista+)
 *     Fallback: return "en-US\0\0" (our OCX doesn't need locale info)
 * ═══════════════════════════════════════════════════════════════════════════ */
BOOL WINAPI GetUserPreferredUILanguages(DWORD dwFlags, PULONG pulNumLanguages,
                                        VX_PZZWSTR pwszLanguagesBuffer,
                                        PULONG pcchLanguagesBuffer) {
    (void)dwFlags;
    static const WCHAR lang[] = L"en-US\0";
    DWORD needed = sizeof(lang) / sizeof(WCHAR) + 1;  /* double-null */

    if (pulNumLanguages) *pulNumLanguages = 1;

    if (!pwszLanguagesBuffer) {
        if (pcchLanguagesBuffer) *pcchLanguagesBuffer = needed;
        return TRUE;
    }

    if (pcchLanguagesBuffer && *pcchLanguagesBuffer < needed) {
        *pcchLanguagesBuffer = needed;
        SetLastError(ERROR_INSUFFICIENT_BUFFER);
        return FALSE;
    }

    memcpy(pwszLanguagesBuffer, lang, sizeof(lang));
    pwszLanguagesBuffer[needed - 1] = L'\0';  /* double-null */
    if (pcchLanguagesBuffer) *pcchLanguagesBuffer = needed;
    return TRUE;
}

/* ═══════════════════════════════════════════════════════════════════════════
 * 12-14. ProcThreadAttributeList functions  (KERNEL32 — Vista+)
 *        Stub: not supported (our OCX doesn't spawn processes)
 * ═══════════════════════════════════════════════════════════════════════════ */
BOOL WINAPI InitializeProcThreadAttributeList(VX_LPPROC_THREAD_ATTRIBUTE_LIST lpAttributeList,
                                              DWORD dwAttributeCount,
                                              DWORD dwFlags, PSIZE_T lpSize) {
    (void)lpAttributeList; (void)dwAttributeCount; (void)dwFlags;
    if (lpSize) *lpSize = 0;
    SetLastError(ERROR_NOT_SUPPORTED);
    return FALSE;
}

void WINAPI DeleteProcThreadAttributeList(VX_LPPROC_THREAD_ATTRIBUTE_LIST lpAttributeList) {
    (void)lpAttributeList;
}

BOOL WINAPI UpdateProcThreadAttribute(VX_LPPROC_THREAD_ATTRIBUTE_LIST lpAttributeList, DWORD dwFlags,
                                      DWORD_PTR Attribute, PVOID lpValue,
                                      SIZE_T cbSize, PVOID lpPreviousValue,
                                      PSIZE_T lpReturnSize) {
    (void)lpAttributeList; (void)dwFlags; (void)Attribute;
    (void)lpValue; (void)cbSize; (void)lpPreviousValue; (void)lpReturnSize;
    SetLastError(ERROR_NOT_SUPPORTED);
    return FALSE;
}
