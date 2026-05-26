// Minimum Layer 1 example: load the VolvoxGrid native runtime, push a small
// table of strings into the engine, and drive the engine's built-in TUI
// renderer (RENDERER_TUI) over a bidi RenderSession stream. Arrow keys move
// the selection (the engine parses raw ANSI input bytes from stdin); 'q' or
// Ctrl+C quits.
//
// No protobuf codegen, no libprotobuf — just the single header `volvoxgrid.hpp`
// and its `volvoxgrid::pb::` wire-format helpers. This is the documentation of
// "what Layer 2 is hiding from you": it shows the actual protobuf bytes a host
// has to produce to drive the engine.
//
// Build (Linux):
//   g++ -std=c++11 -I../../include main.cpp -ldl -o vg_tui
//   ./vg_tui /path/to/libvolvoxgrid.so
//
// Build (Windows / MinGW):
//   x86_64-w64-mingw32-g++ -std=c++11 -I..\..\include main.cpp -o vg_tui.exe
//
// Build (MSVC):
//   cl /std:c++11 /EHsc /I..\..\include main.cpp

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <vector>

#if defined(_WIN32)
#  include <windows.h>
#  include <io.h>
#else
#  include <termios.h>
#  include <unistd.h>
#endif

#include "volvoxgrid.hpp"

namespace pb = volvoxgrid::pb;
using volvoxgrid::Bytes;

// ─── demo data ────────────────────────────────────────────────────────────
static const char* kHeaders[6] = {"name", "sales", "region", "active", "score", "updated"};
static const char* kData[12][6] = {
    {"Alpha",   "1200",  "EMEA", "true",  "4.7", "2026-04-12"},
    {"Beta",    "950",   "APAC", "false", "3.9", "2026-04-08"},
    {"Gamma",   "1875",  "NA",   "true",  "4.2", "2026-04-19"},
    {"Delta",   "640",   "EMEA", "true",  "3.1", "2026-03-30"},
    {"Epsilon", "2310",  "NA",   "false", "4.8", "2026-04-21"},
    {"Zeta",    "1085",  "APAC", "true",  "4.0", "2026-04-15"},
    {"Eta",     "1490",  "EMEA", "true",  "4.3", "2026-04-17"},
    {"Theta",   "780",   "LATAM","false", "2.8", "2026-04-02"},
    {"Iota",    "1620",  "NA",   "true",  "4.5", "2026-04-20"},
    {"Kappa",   "920",   "APAC", "true",  "3.7", "2026-04-11"},
    {"Lambda",  "2050",  "EMEA", "false", "4.6", "2026-04-18"},
    {"Mu",      "1340",  "NA",   "true",  "4.1", "2026-04-14"},
};
static const int kRows           = 12;
static const int kCols           = 6;
static const int kViewportCols   = 100;  // terminal cells, not pixels
static const int kViewportRows   = 16;
static const int kBufferCapacity = 32 * 1024;
static const int kRendererTui    = 5;    // RendererMode enum
static const int kColorTruecolor = 1;    // TerminalColorLevel enum
static const int kRowIndicatorNumbers = 1; // RowIndicatorSlotKind enum
static const int kAlignRightCenter    = 7; // Align enum

// ─── raw-mode terminal (POSIX termios / Win32 console) ───────────────────
// RAII wrapper that puts the terminal in raw mode + alt screen on construction
// and restores the original state on destruction.
class TermRaw {
public:
    TermRaw() {
#if defined(_WIN32)
        hin_  = GetStdHandle(STD_INPUT_HANDLE);
        hout_ = GetStdHandle(STD_OUTPUT_HANDLE);
        GetConsoleMode(hin_,  &in_old_);
        GetConsoleMode(hout_, &out_old_);
        SetConsoleMode(hin_,  ENABLE_VIRTUAL_TERMINAL_INPUT | ENABLE_EXTENDED_FLAGS);
        SetConsoleMode(hout_, out_old_ | ENABLE_VIRTUAL_TERMINAL_PROCESSING
                                       | ENABLE_PROCESSED_OUTPUT);
#else
        tcgetattr(STDIN_FILENO, &old_);
        termios raw = old_;
        raw.c_lflag &= ~(ICANON | ECHO);
        raw.c_cc[VMIN]  = 1;
        raw.c_cc[VTIME] = 0;
        tcsetattr(STDIN_FILENO, TCSANOW, &raw);
#endif
        std::fputs("\x1b[?1049h\x1b[?25l", stdout);  // alt screen, hide cursor
        std::fflush(stdout);
    }
    ~TermRaw() {
        std::fputs("\x1b[?25h\x1b[?1049l", stdout);  // show cursor, leave alt screen
        std::fflush(stdout);
#if defined(_WIN32)
        SetConsoleMode(hin_,  in_old_);
        SetConsoleMode(hout_, out_old_);
#else
        tcsetattr(STDIN_FILENO, TCSANOW, &old_);
#endif
    }
    int read_bytes(uint8_t* buf, int cap) {
#if defined(_WIN32)
        DWORD n = 0;
        if (!ReadFile(hin_, buf, DWORD(cap), &n, nullptr)) return 0;
        return int(n);
#else
        ssize_t n = ::read(STDIN_FILENO, buf, size_t(cap));
        return n > 0 ? int(n) : 0;
#endif
    }
private:
#if defined(_WIN32)
    HANDLE hin_, hout_;
    DWORD in_old_, out_old_;
#else
    termios old_;
#endif
};

int main(int argc, char** argv) {
    const char* path = (argc > 1) ? argv[1] : volvoxgrid::default_library_name();
    try {
        volvoxgrid::Runtime rt(path);
        rt.init();

        // 1. Create. Inline GridConfig flips the renderer to RENDERER_TUI,
        //    declares the data layout up-front, and turns on the leading row-
        //    number indicator band (column captions come from DefineColumns
        //    below — they render in the header band, not row 0).
        //      CreateRequest      { viewport_width=1, viewport_height=2, scale=3,
        //                           config=4 (GridConfig) }
        //      GridConfig         { layout=1, rendering=9, indicators=11 }
        //      LayoutConfig       { rows=1, cols=2 }
        //      RenderConfig       { renderer_mode=1 (RendererMode enum) }
        //      IndicatorsConfig   { row_start=1 (RowIndicatorConfig) }
        //      RowIndicatorConfig { visible=1, width=2, slots=11 (RowIndicatorSlot) }
        //      RowIndicatorSlot   { kind=1 (RowIndicatorSlotKind), visible=3 }
        Bytes layout;
        pb::write_int32(layout, 1, kRows);
        pb::write_int32(layout, 2, kCols);

        Bytes rendering;
        pb::write_int32(rendering, 1, kRendererTui);

        Bytes row_num_slot;
        pb::write_int32(row_num_slot, 1, kRowIndicatorNumbers);
        pb::write_int32(row_num_slot, 2, 4);    // width hint (terminal cells)
        pb::write_int32(row_num_slot, 3, 1);    // visible = true

        Bytes row_start;
        pb::write_int32(row_start, 1, 1);       // visible = true
        pb::write_int32(row_start, 2, 4);       // width hint
        pb::write_message(row_start, 11, row_num_slot);

        Bytes indicators;
        pb::write_message(indicators, 1, row_start);

        Bytes config;
        pb::write_message(config, 1, layout);
        pb::write_message(config, 9, rendering);
        pb::write_message(config, 11, indicators);

        Bytes create_req;
        pb::write_int32(create_req, 1, kViewportCols);
        pb::write_int32(create_req, 2, kViewportRows);
        pb::write_float(create_req, 3, 1.0f);
        pb::write_message(create_req, 4, config);
        auto create_resp = rt.invoke(
            "/volvoxgrid.v1.VolvoxGridService/Create", create_req);

        int64_t grid_id = 0;
        {
            pb::Reader r(create_resp);
            uint32_t f, w;
            while (r.tag(f, w)) {
                if (f == 1 && w == 0) grid_id = r.int64_v();
                else r.skip(w);
            }
        }

        // 2. DefineColumns — caption + width + align per column. Captions
        //    land in the engine's column-header band above row 0. The
        //    "sales" column is right-aligned via Align enum.
        //      DefineColumnsRequest { grid_id=1, repeated ColumnDef columns=2 }
        //      ColumnDef            { index=1, width=2, caption=5, align=6 }
        //      Align                { ALIGN_RIGHT_CENTER = 7 }
        Bytes define_req;
        pb::write_int64(define_req, 1, grid_id);
        for (int c = 0; c < kCols; ++c) {
            Bytes col;
            pb::write_int32(col, 1, c);
            pb::write_int32(col, 2, 16);
            pb::write_string(col, 5, kHeaders[c]);
            if (c == 1) pb::write_int32(col, 6, kAlignRightCenter);
            pb::write_message(define_req, 2, col);
        }
        rt.invoke("/volvoxgrid.v1.VolvoxGridService/DefineColumns", define_req);

        // 3. UpdateCells — push the 2x3 data.
        //    UpdateCellsRequest { grid_id=1, repeated CellUpdate cells=2 }
        //    CellUpdate         { row=1, col=2, value=3 (CellValue) }
        //    CellValue          { oneof { string text=1 } }
        Bytes update_req;
        pb::write_int64(update_req, 1, grid_id);
        for (int r = 0; r < kRows; ++r) {
            for (int c = 0; c < kCols; ++c) {
                Bytes cell_value;
                pb::write_string(cell_value, 1, kData[r][c]);
                Bytes cell_update;
                pb::write_int32(cell_update, 1, r);
                pb::write_int32(cell_update, 2, c);
                pb::write_message(cell_update, 3, cell_value);
                pb::write_message(update_req, 2, cell_update);
            }
        }
        rt.invoke("/volvoxgrid.v1.VolvoxGridService/UpdateCells", update_req);

        // 4. RenderSession bidi stream — interactive event loop.
        auto session = rt.open_stream(
            "/volvoxgrid.v1.VolvoxGridService/RenderSession");

        // 4a. TerminalCapabilities — request truecolor.
        //     TerminalCapabilities { color_level=1 }
        {
            Bytes caps;
            pb::write_int32(caps, 1, kColorTruecolor);
            Bytes msg;
            pb::write_int64(msg, 1, grid_id);
            pb::write_message(msg, 11, caps);
            session.send(msg);
        }

        // 4b. TerminalViewport.
        //     TerminalViewport { width=3, height=4 }
        {
            Bytes vp;
            pb::write_int32(vp, 3, kViewportCols);
            pb::write_int32(vp, 4, kViewportRows);
            Bytes msg;
            pb::write_int64(msg, 1, grid_id);
            pb::write_message(msg, 12, vp);
            session.send(msg);
        }

        // 5. Enter raw mode + alt screen. ANSI from the engine and keystrokes
        //    from the user flow through stdout/stdin directly.
        std::vector<uint8_t> buf(kBufferCapacity);
        int64_t handle = static_cast<int64_t>(reinterpret_cast<intptr_t>(buf.data()));
        TermRaw raw;

        // 6. Event loop: render → read key → forward to engine → repeat.
        //    Ordering is render-then-read-then-forward, so the frame we just
        //    sent BufferReady for already reflects any input forwarded on the
        //    previous iteration.
        bool quit = false;
        while (true) {
            // 6a. Request a frame. Engine writes ANSI bytes into our buffer
            //     at `handle` and replies with FrameDone.bytes_written.
            //       RenderInput.buffer = 5 (BufferReady)
            //       BufferReady { handle=1, width=3, height=4, capacity=5 }
            {
                Bytes br;
                pb::write_int64(br, 1, handle);
                pb::write_int32(br, 3, kViewportCols);
                pb::write_int32(br, 4, kViewportRows);
                pb::write_int32(br, 5, kBufferCapacity);
                Bytes msg;
                pb::write_int64(msg, 1, grid_id);
                pb::write_message(msg, 5, br);
                session.send(msg);
            }

            // 6b. Recv until FrameDone with matching handle.
            //       RenderOutput.event = frame_done = 2
            //       FrameDone { handle=1, bytes_written=7 }
            int32_t bytes_written = 0;
            bool got_frame = false;
            while (!got_frame) {
                auto out = session.recv();
                if (out.status != 0) { quit = true; break; }
                pb::Reader r(out.data);
                uint32_t f, w;
                while (r.tag(f, w)) {
                    if (f == 2 && w == 2) {
                        auto fd_bytes = r.length_delimited();
                        pb::Reader fd(fd_bytes);
                        int64_t fd_handle = 0;
                        int32_t fd_written = 0;
                        uint32_t ff, fw;
                        while (fd.tag(ff, fw)) {
                            if      (ff == 1 && fw == 0) fd_handle  = fd.int64_v();
                            else if (ff == 7 && fw == 0) fd_written = fd.int32_v();
                            else                          fd.skip(fw);
                        }
                        if (fd_handle == handle) {
                            bytes_written = fd_written;
                            got_frame = true;
                        }
                    } else {
                        r.skip(w);
                    }
                }
            }
            if (quit) break;

            if (bytes_written > 0) {
                std::fwrite(buf.data(), 1, size_t(bytes_written), stdout);
            }
            // Help line below the engine's viewport.
            std::fprintf(stdout, "\x1b[%d;1H\x1b[0m\x1b[2KArrows: move  q: quit",
                         kViewportRows + 1);
            std::fflush(stdout);

            if (quit) break;

            // 6c. Read a keypress. Arrow keys arrive as 3-byte CSI sequences;
            //     a 16-byte buffer comfortably holds any single chord the
            //     terminal delivers in one read().
            uint8_t key[16];
            int n = raw.read_bytes(key, sizeof key);
            if (n <= 0) continue;

            // 6d. Scan for the quit byte. Forward everything before it; if
            //     the buffer was pure 'q' / Ctrl+C, nothing to forward.
            int forward_n = n;
            for (int i = 0; i < n; ++i) {
                if (key[i] == 'q' || key[i] == 0x03) {  // 0x03 = Ctrl+C
                    forward_n = i;
                    quit = true;
                    break;
                }
            }

            if (forward_n > 0) {
                // 6e. Forward bytes to the engine. The engine's terminal_tui
                //     parser turns the ANSI sequence into the matching key
                //     event and updates selection / scroll state.
                //       RenderInput.terminal_input = 10 (TerminalInputBytes)
                //       TerminalInputBytes { bytes data = 1 }
                Bytes ti;
                pb::write_bytes(ti, 1, key, size_t(forward_n));
                Bytes msg;
                pb::write_int64(msg, 1, grid_id);
                pb::write_message(msg, 10, ti);
                session.send(msg);
            } else if (quit) {
                break;
            }
        }

        session.close_send();
        return 0;

    } catch (const volvoxgrid::Error& e) {
        std::fprintf(stderr, "VolvoxGrid error: %s (code=%d)\n", e.what(), e.code());
        return 1;
    }
}
