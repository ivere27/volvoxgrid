// volvoxgrid.hpp — header-only C++ wrapper around the VolvoxGrid native runtime.
//
// Usage:
//   #include "volvoxgrid.hpp"
//   volvoxgrid::Runtime rt("volvoxgrid.dll");   // or libvolvoxgrid.so / .dylib
//   rt.init();
//   std::vector<uint8_t> resp = rt.invoke("/volvoxgrid.v1.VolvoxGridService/Create", create_req_bytes);
//   auto stream = rt.open_stream("/volvoxgrid.v1.VolvoxGridService/RenderSession");
//   stream.send(payload);
//   auto [bytes, status] = stream.recv();
//
// Works with any Windows C++ host (ATL, WTL, MFC, raw Win32, Qt), and Linux/macOS too.
//
// Requires C++17. No exceptions are mandatory in the call path — every method has a
// noexcept overload returning a status enum if you'd rather avoid throw.

#ifndef VOLVOXGRID_HPP
#define VOLVOXGRID_HPP

#include <cstdint>
#include <cstring>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

#if defined(_WIN32)
#  define WIN32_LEAN_AND_MEAN
#  include <windows.h>
#else
#  include <dlfcn.h>
#endif

namespace volvoxgrid {

using Bytes = std::vector<uint8_t>;

struct RecvResult {
    Bytes data;
    int32_t status;        // 0 = ok, 1 = end-of-stream, <0 = error (data holds payload)
};

class Error : public std::runtime_error {
public:
    Error(std::string msg, int code = 0) : std::runtime_error(std::move(msg)), code_(code) {}
    int code() const noexcept { return code_; }
private:
    int code_;
};

// Platform-specific default file name for the runtime shared library. Useful
// when a host has no configured path and wants to fall back to whatever's on
// the loader's search path.
inline const char* default_library_name() noexcept {
#if defined(_WIN32)
    return "volvoxgrid.dll";
#elif defined(__APPLE__)
    return "libvolvoxgrid.dylib";
#else
    return "libvolvoxgrid.so";
#endif
}

// ─── Protobuf wire-format helpers ─────────────────────────────────────────
//
// Minimal encoder + reader for the protobuf wire format
// (https://protobuf.dev/programming-guides/encoding/). Use these when you're
// hand-encoding requests for `Runtime::invoke` and don't want to link
// libprotobuf or pull in the Layer 2 codegen. The Layer 2 generated client
// has its own encoder in `synurang_lite.hpp`; this namespace exists so the
// single-header Layer 1 stays self-contained.

namespace pb {

// --- writers ---

inline void write_varint(Bytes& out, uint64_t v) {
    while (v >= 0x80) { out.push_back(static_cast<uint8_t>((v & 0x7F) | 0x80)); v >>= 7; }
    out.push_back(static_cast<uint8_t>(v));
}

inline void write_tag(Bytes& out, uint32_t field, uint32_t wire) {
    write_varint(out, (static_cast<uint64_t>(field) << 3) | wire);
}

inline void write_int32(Bytes& out, uint32_t field, int32_t v) {
    write_tag(out, field, 0);
    // Sign-extend negatives to 10 bytes per the proto3 spec.
    write_varint(out, static_cast<uint64_t>(static_cast<int64_t>(v)));
}

inline void write_int64(Bytes& out, uint32_t field, int64_t v) {
    write_tag(out, field, 0);
    write_varint(out, static_cast<uint64_t>(v));
}

inline void write_float(Bytes& out, uint32_t field, float v) {
    write_tag(out, field, 5);
    uint32_t bits;
    std::memcpy(&bits, &v, 4);
    for (int i = 0; i < 4; ++i) out.push_back(static_cast<uint8_t>((bits >> (8 * i)) & 0xFF));
}

inline void write_bytes(Bytes& out, uint32_t field, const uint8_t* p, size_t n) {
    write_tag(out, field, 2);
    write_varint(out, static_cast<uint64_t>(n));
    out.insert(out.end(), p, p + n);
}

inline void write_string(Bytes& out, uint32_t field, const char* s) {
    write_bytes(out, field, reinterpret_cast<const uint8_t*>(s), std::strlen(s));
}

inline void write_string(Bytes& out, uint32_t field, const std::string& s) {
    write_bytes(out, field, reinterpret_cast<const uint8_t*>(s.data()), s.size());
}

inline void write_message(Bytes& out, uint32_t field, const Bytes& inner) {
    write_bytes(out, field, inner.data(), inner.size());
}

// --- reader ---
//
// Bounds-checked: malformed input truncates silently rather than running off
// the end of the buffer. Tuned for trusted FFI responses, not adversarial input.

class Reader {
public:
    Reader(const uint8_t* p, size_t n) : p_(p), end_(p + n) {}
    explicit Reader(const Bytes& b) : p_(b.data()), end_(b.data() + b.size()) {}

    bool eof() const noexcept { return p_ >= end_; }

    uint64_t varint() {
        uint64_t r = 0; unsigned s = 0;
        while (p_ < end_ && s < 64) {
            uint8_t b = *p_++;
            r |= static_cast<uint64_t>(b & 0x7F) << s;
            if (!(b & 0x80)) return r;
            s += 7;
        }
        return r;
    }

    bool tag(uint32_t& field, uint32_t& wire) {
        if (eof()) return false;
        uint64_t t = varint();
        wire  = static_cast<uint32_t>(t & 7);
        field = static_cast<uint32_t>(t >> 3);
        return true;
    }

    int32_t int32_v() { return static_cast<int32_t>(static_cast<int64_t>(varint())); }
    int64_t int64_v() { return static_cast<int64_t>(varint()); }

    float float_v() {
        uint32_t bits = 0;
        for (int i = 0; i < 4 && p_ < end_; ++i) {
            bits |= static_cast<uint32_t>(*p_++) << (8 * i);
        }
        float v; std::memcpy(&v, &bits, 4); return v;
    }

    Bytes length_delimited() {
        size_t n = static_cast<size_t>(varint());
        if (static_cast<size_t>(end_ - p_) < n) n = static_cast<size_t>(end_ - p_);
        Bytes v(p_, p_ + n);
        p_ += n;
        return v;
    }

    std::string string_v() {
        size_t n = static_cast<size_t>(varint());
        if (static_cast<size_t>(end_ - p_) < n) n = static_cast<size_t>(end_ - p_);
        std::string s(reinterpret_cast<const char*>(p_), n);
        p_ += n;
        return s;
    }

    void skip(uint32_t wire) {
        if (wire == 0)      { varint(); }
        else if (wire == 1) { p_ = (end_ - p_ >= 8) ? p_ + 8 : end_; }
        else if (wire == 2) {
            size_t n = static_cast<size_t>(varint());
            p_ = (static_cast<size_t>(end_ - p_) < n) ? end_ : p_ + n;
        }
        else if (wire == 5) { p_ = (end_ - p_ >= 4) ? p_ + 4 : end_; }
    }

private:
    const uint8_t* p_;
    const uint8_t* end_;
};

}  // namespace pb

namespace detail {

// Decode a CoreFfiError payload (proto: 1=code int32, 2=message string,
// 3=grpc_code int32). Matches what the Rust hosts parse from -resp_len.
struct DecodedFfiError {
    std::string message;
    int32_t code      = 0;
    int32_t grpc_code = 0;
};

inline bool read_varint(const uint8_t*& p, const uint8_t* end, uint64_t& v) {
    v = 0; uint32_t shift = 0;
    while (p < end && shift < 64) {
        uint8_t b = *p++;
        v |= static_cast<uint64_t>(b & 0x7f) << shift;
        if (!(b & 0x80)) return true;
        shift += 7;
    }
    return false;
}

inline DecodedFfiError decode_ffi_error(const uint8_t* data, size_t n) {
    DecodedFfiError out;
    const uint8_t* p = data;
    const uint8_t* end = data + n;
    while (p < end) {
        uint64_t tag;
        if (!read_varint(p, end, tag)) break;
        uint32_t field = static_cast<uint32_t>(tag >> 3);
        uint32_t wire  = static_cast<uint32_t>(tag & 0x07);
        if (field == 1 && wire == 0) {
            uint64_t v; if (!read_varint(p, end, v)) break;
            out.code = static_cast<int32_t>(v);
        } else if (field == 2 && wire == 2) {
            uint64_t len; if (!read_varint(p, end, len)) break;
            if (static_cast<size_t>(end - p) < len) break;
            out.message.assign(reinterpret_cast<const char*>(p), static_cast<size_t>(len));
            p += len;
        } else if (field == 3 && wire == 0) {
            uint64_t v; if (!read_varint(p, end, v)) break;
            out.grpc_code = static_cast<int32_t>(v);
        } else {
            // Skip unknown field.
            switch (wire) {
                case 0: { uint64_t v; if (!read_varint(p, end, v)) return out; break; }
                case 1: if (end - p < 8) return out; p += 8; break;
                case 2: { uint64_t len; if (!read_varint(p, end, len)) return out;
                          if (static_cast<size_t>(end - p) < len) return out; p += len; break; }
                case 5: if (end - p < 4) return out; p += 4; break;
                default: return out;
            }
        }
    }
    if (out.message.empty()) {
        out.message.assign(reinterpret_cast<const char*>(data), n);
    }
    return out;
}

#if defined(_WIN32)
using LibHandle = HMODULE;
inline LibHandle dlib_open(const char* path)  { return ::LoadLibraryA(path); }
inline void      dlib_close(LibHandle h)      { if (h) ::FreeLibrary(h); }
inline void*     dlib_sym(LibHandle h, const char* n) {
    return reinterpret_cast<void*>(::GetProcAddress(h, n));
}
inline std::string dlib_error() {
    DWORD e = ::GetLastError();
    return "LoadLibrary/GetProcAddress failed (code " + std::to_string(e) + ")";
}
#else
using LibHandle = void*;
inline LibHandle dlib_open(const char* path)  { return ::dlopen(path, RTLD_NOW | RTLD_LOCAL); }
inline void      dlib_close(LibHandle h)      { if (h) ::dlclose(h); }
inline void*     dlib_sym(LibHandle h, const char* n) { return ::dlsym(h, n); }
inline std::string dlib_error() {
    const char* m = ::dlerror();
    return m ? std::string(m) : std::string("dlopen/dlsym failed");
}
#endif

// FFI signatures (mirror dist/ios/volvoxgrid.h plus the unpublished probe exports).
using fn_Init           = void   (*)();
using fn_Invoke         = char*  (*)(const char*, const char*, int32_t, int32_t*);
using fn_Free           = void   (*)(void*);
using fn_StreamOpen     = uint64_t(*)(const char*);
using fn_StreamSend     = int32_t(*)(uint64_t, const char*, int32_t);
using fn_StreamRecv     = char*  (*)(uint64_t, int32_t*, int32_t*);
using fn_StreamCloseSnd = void   (*)(uint64_t);
using fn_StreamClose    = void   (*)(uint64_t);
using fn_HasText        = int32_t(*)();
using fn_HasGpu         = int32_t(*)();

} // namespace detail

class Stream;

class Runtime {
public:
    explicit Runtime(const char* library_path) {
        lib_ = detail::dlib_open(library_path);
        if (!lib_) throw Error("VolvoxGrid runtime: " + detail::dlib_error());
        bind_required(invoke_,         "Synurang_Invoke_VolvoxGridService");
        bind_required(free_,           "Synurang_Free");
        bind_required(stream_open_,    "Synurang_Stream_VolvoxGridService_Open");
        bind_required(stream_send_,    "Synurang_Stream_Send");
        bind_required(stream_recv_,    "Synurang_Stream_Recv");
        bind_required(stream_csnd_,    "Synurang_Stream_CloseSend");
        bind_required(stream_close_,   "Synurang_Stream_Close");
        bind_optional(init_,           "VolvoxGrid_Init");
        bind_optional(has_text_,       "volvox_grid_has_builtin_text_engine");
        bind_optional(has_gpu_,        "volvox_grid_has_gpu_renderer");
    }

    ~Runtime() { detail::dlib_close(lib_); }

    Runtime(const Runtime&)            = delete;
    Runtime& operator=(const Runtime&) = delete;
    Runtime(Runtime&& o) noexcept { steal(o); }
    Runtime& operator=(Runtime&& o) noexcept {
        if (this != &o) { detail::dlib_close(lib_); steal(o); }
        return *this;
    }

    void init() { if (init_) init_(); }

    bool has_builtin_text_engine() const { return has_text_ && has_text_() != 0; }
    bool has_gpu_renderer()        const { return has_gpu_  && has_gpu_()  != 0; }

    // Unary call. Returns response bytes (possibly empty). Throws on FFI error
    // with the decoded message and code from the runtime's CoreFfiError payload.
    Bytes invoke(const std::string& method, const Bytes& payload) {
        int32_t resp_len = 0;
        const char* data = payload.empty() ? nullptr
                                           : reinterpret_cast<const char*>(payload.data());
        char* resp = invoke_(method.c_str(), data,
                             static_cast<int32_t>(payload.size()), &resp_len);
        if (resp_len < 0) {
            Bytes err = consume(resp, -resp_len);
            detail::DecodedFfiError info = detail::decode_ffi_error(err.data(), err.size());
            throw Error(method + ": " + info.message, info.code);
        }
        if (!resp || resp_len == 0) {
            if (resp) free_(resp);
            return {};
        }
        return consume(resp, resp_len);
    }

    Stream open_stream(const std::string& method);

    // Escape hatches if you need to reach an export this header does not type.
    detail::LibHandle native_handle() const noexcept { return lib_; }

private:
    template <typename F>
    void bind_required(F& out, const char* name) {
        out = reinterpret_cast<F>(detail::dlib_sym(lib_, name));
        if (!out) {
            detail::dlib_close(lib_);
            lib_ = nullptr;
            throw Error(std::string("VolvoxGrid runtime missing export: ") + name);
        }
    }
    template <typename F>
    void bind_optional(F& out, const char* name) {
        out = reinterpret_cast<F>(detail::dlib_sym(lib_, name));
    }

    Bytes consume(char* ptr, int32_t len) {
        Bytes out(static_cast<size_t>(len));
        if (ptr && len > 0) std::memcpy(out.data(), ptr, static_cast<size_t>(len));
        if (ptr) free_(ptr);
        return out;
    }

    void steal(Runtime& o) {
        lib_           = o.lib_;            o.lib_           = nullptr;
        invoke_        = o.invoke_;         o.invoke_        = nullptr;
        free_          = o.free_;           o.free_          = nullptr;
        stream_open_   = o.stream_open_;    o.stream_open_   = nullptr;
        stream_send_   = o.stream_send_;    o.stream_send_   = nullptr;
        stream_recv_   = o.stream_recv_;    o.stream_recv_   = nullptr;
        stream_csnd_   = o.stream_csnd_;    o.stream_csnd_   = nullptr;
        stream_close_  = o.stream_close_;   o.stream_close_  = nullptr;
        init_          = o.init_;           o.init_          = nullptr;
        has_text_      = o.has_text_;       o.has_text_      = nullptr;
        has_gpu_       = o.has_gpu_;        o.has_gpu_       = nullptr;
    }

    detail::LibHandle      lib_          = nullptr;
    detail::fn_Invoke      invoke_       = nullptr;
    detail::fn_Free        free_         = nullptr;
    detail::fn_StreamOpen  stream_open_  = nullptr;
    detail::fn_StreamSend  stream_send_  = nullptr;
    detail::fn_StreamRecv  stream_recv_  = nullptr;
    detail::fn_StreamCloseSnd stream_csnd_  = nullptr;
    detail::fn_StreamClose stream_close_ = nullptr;
    detail::fn_Init        init_         = nullptr;
    detail::fn_HasText     has_text_     = nullptr;
    detail::fn_HasGpu      has_gpu_      = nullptr;

    friend class Stream;
};

class Stream {
public:
    Stream() = default;
    Stream(Runtime* rt, uint64_t handle) : rt_(rt), handle_(handle) {}
    ~Stream() { close(); }

    Stream(const Stream&)            = delete;
    Stream& operator=(const Stream&) = delete;
    Stream(Stream&& o) noexcept : rt_(o.rt_), handle_(o.handle_) {
        o.rt_ = nullptr; o.handle_ = 0;
    }
    Stream& operator=(Stream&& o) noexcept {
        if (this != &o) { close(); rt_ = o.rt_; handle_ = o.handle_;
                          o.rt_ = nullptr; o.handle_ = 0; }
        return *this;
    }

    bool valid() const noexcept { return rt_ && handle_ != 0; }

    void send(const Bytes& payload) {
        const char* data = payload.empty() ? nullptr
                                           : reinterpret_cast<const char*>(payload.data());
        int32_t rc = rt_->stream_send_(handle_, data, static_cast<int32_t>(payload.size()));
        if (rc != 0) throw Error("VolvoxGrid stream send failed", rc);
    }

    // Returns status 0 = data, 1 = end-of-stream (data empty). Throws on
    // transport error (status < 0) with the decoded CoreFfiError message+code.
    RecvResult recv() {
        int32_t resp_len = 0, status = 0;
        char* ptr = rt_->stream_recv_(handle_, &resp_len, &status);
        RecvResult r;
        r.status = status;
        if (ptr && resp_len > 0) {
            r.data.assign(reinterpret_cast<uint8_t*>(ptr),
                          reinterpret_cast<uint8_t*>(ptr) + resp_len);
        }
        if (ptr) rt_->free_(ptr);
        if (status < 0) {
            detail::DecodedFfiError info = detail::decode_ffi_error(r.data.data(), r.data.size());
            throw Error("stream recv failed: " + info.message, info.code);
        }
        return r;
    }

    void close_send() { if (valid()) rt_->stream_csnd_(handle_); }

    void close() {
        if (valid()) { rt_->stream_close_(handle_); handle_ = 0; rt_ = nullptr; }
    }

private:
    Runtime* rt_     = nullptr;
    uint64_t handle_ = 0;
};

inline Stream Runtime::open_stream(const std::string& method) {
    uint64_t h = stream_open_(method.c_str());
    if (h == 0) throw Error("VolvoxGrid stream open failed: " + method);
    return Stream(this, h);
}

} // namespace volvoxgrid

#endif // VOLVOXGRID_HPP
