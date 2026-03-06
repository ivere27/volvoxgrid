#include <windows.h>
// Wine may miss bcryptprimitives.dll (ProcessPrng). Provide a tiny shim that
// fills the requested buffer with pseudo-random bytes, sufficient for process-
// local hash seeding in test/smoke environments.
__declspec(dllexport) int WINAPI ProcessPrng(PBYTE buffer, SIZE_T len) {
    if (buffer == NULL || len == 0) {
        return 1;
    }

    ULONGLONG state = 0x9E3779B97F4A7C15ULL ^ (ULONGLONG)(ULONG_PTR)buffer ^ (ULONGLONG)GetTickCount();
    for (SIZE_T i = 0; i < len; i++) {
        state ^= state << 7;
        state ^= state >> 9;
        state ^= state << 8;
        buffer[i] = (BYTE)(state & 0xFFu);
    }

    return 1;
}
