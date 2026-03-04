/* compat_shims.c — shims for functions missing from MinGW import libs */

#include <winsock2.h>
#include <windows.h>

/* MinGW's libws2_32.a doesn't export GetHostNameW (added in Win8 SDK).
   Rust std uses it for sys::net::hostname on Windows.  Provide a shim
   that delegates to gethostname + MultiByteToWideChar. */
int WSAAPI GetHostNameW(PWSTR pNodeBuffer, int namelen) {
    char buf[256];
    int rc = gethostname(buf, sizeof(buf));
    if (rc != 0) return rc;
    int wlen = MultiByteToWideChar(CP_UTF8, 0, buf, -1, pNodeBuffer, namelen);
    return (wlen > 0) ? 0 : SOCKET_ERROR;
}
