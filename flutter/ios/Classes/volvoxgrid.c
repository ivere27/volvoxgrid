#include <stddef.h>

// Flutter iOS links VolvoxGrid as a static XCFramework. Dart resolves the
// Synurang entry points with DynamicLibrary.process(), so keep the exported
// Rust symbols alive even though no Objective-C/Swift code calls them directly.
extern void Synurang_Invoke_VolvoxGridService(void);
extern void Synurang_Free(void);
extern void Synurang_Stream_VolvoxGridService_Open(void);
extern void Synurang_Stream_Send(void);
extern void Synurang_Stream_Recv(void);
extern void Synurang_Stream_CloseSend(void);
extern void Synurang_Stream_Close(void);

typedef void (*VolvoxGridSymbolRef)(void);

__attribute__((used))
static const VolvoxGridSymbolRef volvoxgrid_force_link_symbols[] = {
    Synurang_Invoke_VolvoxGridService,
    Synurang_Free,
    Synurang_Stream_VolvoxGridService_Open,
    Synurang_Stream_Send,
    Synurang_Stream_Recv,
    Synurang_Stream_CloseSend,
    Synurang_Stream_Close,
};

void volvoxgrid_flutter_force_link_symbols(void) {
    const size_t count = sizeof(volvoxgrid_force_link_symbols) /
                         sizeof(volvoxgrid_force_link_symbols[0]);
    for (size_t i = 0; i < count; ++i) {
        if (volvoxgrid_force_link_symbols[i] == 0) {
            return;
        }
    }
}
