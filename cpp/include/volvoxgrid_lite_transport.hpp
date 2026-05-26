// Bridge: volvoxgrid::Runtime → synurang::lite::Transport.
//
// Drop-in adapter so any C++ host that has loaded the VolvoxGrid runtime
// through `volvoxgrid::Runtime` can drive the generated lite client
// (`*_lite.hpp` produced by `protoc-gen-synurang-ffi --lang=cpp,mode=lite`)
// without writing transport boilerplate.
//
// Header-only, pure C++11. No new symbols leak — everything lives in
// `volvoxgrid::lite_transport`.
//
// Usage:
//   volvoxgrid::Runtime rt(library_path);
//   rt.init();
//   volvoxgrid::lite_transport::RuntimeTransport transport(&rt);
//   volvoxgrid::v1::VolvoxGridServiceLite client(&transport);
//   auto resp = client.Create(req);

#ifndef VOLVOXGRID_LITE_TRANSPORT_HPP
#define VOLVOXGRID_LITE_TRANSPORT_HPP

#include <cstdint>
#include <memory>
#include <string>
#include <utility>
#include <vector>

#include "synurang_lite.hpp"
#include "volvoxgrid.hpp"

namespace volvoxgrid {
namespace lite_transport {

class RuntimeStream : public ::synurang::lite::Stream {
public:
    explicit RuntimeStream(::volvoxgrid::Stream stream) : stream_(std::move(stream)) {}

    void send(const std::vector<uint8_t>& payload) override { stream_.send(payload); }
    void close_send() override { stream_.close_send(); }
    void close() override { stream_.close(); }

    // Returns false at end-of-stream (status != 0). Throws synurang::lite::FfiError
    // — translated from volvoxgrid::Error — on transport failure.
    bool recv(std::vector<uint8_t>& out) override {
        ::volvoxgrid::RecvResult r = stream_.recv();
        if (r.status != 0) return false;
        out = std::move(r.data);
        return true;
    }

private:
    ::volvoxgrid::Stream stream_;
};

class RuntimeTransport : public ::synurang::lite::Transport {
public:
    explicit RuntimeTransport(::volvoxgrid::Runtime* runtime) : runtime_(runtime) {}

    std::vector<uint8_t> invoke(const std::string& method,
                                const std::vector<uint8_t>& data) override {
        return runtime_->invoke(method, data);
    }

    std::unique_ptr<::synurang::lite::Stream> open_stream(const std::string& method) override {
        return std::unique_ptr<::synurang::lite::Stream>(
            new RuntimeStream(runtime_->open_stream(method)));
    }

private:
    ::volvoxgrid::Runtime* runtime_;
};

}  // namespace lite_transport
}  // namespace volvoxgrid

#endif  // VOLVOXGRID_LITE_TRANSPORT_HPP
