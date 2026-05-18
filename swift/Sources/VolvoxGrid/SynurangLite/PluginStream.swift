import Foundation

/// A handle to a streaming RPC opened via `PluginHost.openStream`.
///
/// `PluginStream` is an `actor` so concurrent `send` / `recv` calls from
/// different tasks are serialised. The underlying C ABI is single-threaded
/// per stream handle, so this matches the plugin's expectations.
///
/// Closing semantics:
///   - `close()` is idempotent.
///   - The host may call `closeFromHost()` to cascade-close on its own teardown.
///   - After close, all methods throw `PluginClosedError`.
public final actor PluginStream {

    private weak var host: PluginHost?
    private let handle: UInt64
    private let funcs: StreamFuncs
    private let free: SynurangFreeFn
    private var closed: Bool = false

    internal init(
        host: PluginHost,
        handle: UInt64,
        funcs: StreamFuncs,
        free: @escaping SynurangFreeFn
    ) {
        self.host = host
        self.handle = handle
        self.funcs = funcs
        self.free = free
    }

    /// Sends a payload to the stream.
    public func send(_ data: Data) async throws {
        if closed { throw PluginClosedError() }
        if let host = host, await host.isClosed() { throw PluginClosedError() }

        let dataLen = Int32(data.count)
        var dataPtr: UnsafeMutablePointer<CChar>? = nil
        if data.count > 0 {
            let p = UnsafeMutablePointer<CChar>.allocate(capacity: data.count)
            data.withUnsafeBytes { raw in
                if let base = raw.bindMemory(to: CChar.self).baseAddress {
                    p.initialize(from: base, count: data.count)
                }
            }
            dataPtr = p
        }
        defer { dataPtr?.deallocate() }

        let result = funcs.send(handle, dataPtr, dataLen)
        if result != 0 {
            throw FfiError(message: "Stream send failed with code \(result)")
        }
    }

    /// Receives the next response payload. Returns `nil` on EOF.
    /// Throws `FfiError` on stream error.
    ///
    /// `Synurang_Stream_Recv` blocks on a condvar inside the plugin until
    /// data is available. Doing that synchronously here would hold the
    /// actor's executor, so a concurrent `send()` (e.g. driving a
    /// bidirectional render loop) could never make progress. We
    /// dispatch the blocking call to a background queue and `await`
    /// the result — the actor is released at the suspension point, so
    /// send/recv can interleave the way the plugin's threaded ABI
    /// expects.
    public func recv() async throws -> Data? {
        if closed { throw PluginClosedError() }
        if let host = host, await host.isClosed() { throw PluginClosedError() }

        let handle = self.handle
        let funcs = self.funcs
        let free = self.free

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<Data?, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                var respLen: Int32 = 0
                var status: Int32 = 0
                let resultPtr = funcs.recv(handle, &respLen, &status)

                if status == 1 {
                    if let p = resultPtr { free(p) }
                    cont.resume(returning: nil)
                    return
                }

                if status < 0 {
                    if let p = resultPtr {
                        defer { free(p) }
                        if respLen > 0 {
                            var bytes = Data()
                            p.withMemoryRebound(to: UInt8.self, capacity: Int(respLen)) { typed in
                                bytes = Data(bytes: typed, count: Int(respLen))
                            }
                            cont.resume(throwing: FfiError.fromPayload(bytes))
                            return
                        }
                    }
                    cont.resume(throwing: FfiError(message: "Stream recv failed with status \(status)"))
                    return
                }

                if status != 0 {
                    if let p = resultPtr { free(p) }
                    cont.resume(throwing: FfiError(message: "Stream recv failed with status \(status)"))
                    return
                }

                guard let p = resultPtr else {
                    if respLen == 0 {
                        cont.resume(returning: Data())
                    } else {
                        cont.resume(throwing: FfiError(message: "Plugin returned null for stream recv"))
                    }
                    return
                }
                defer { free(p) }

                var payload = Data()
                if respLen > 0 {
                    let n = Int(respLen)
                    p.withMemoryRebound(to: UInt8.self, capacity: n) { typed in
                        payload = Data(bytes: typed, count: n)
                    }
                }
                cont.resume(returning: payload)
            }
        }
    }

    /// Closes the send side. The stream can still receive after this.
    public func closeSend() async throws {
        if closed { throw PluginClosedError() }
        if let host = host, await host.isClosed() { throw PluginClosedError() }
        funcs.closeSend(handle)
    }

    /// Closes the stream fully. Idempotent.
    public func close() async {
        if closed { return }
        closed = true
        funcs.close(handle)
        if let host = host {
            await host.unregisterStream(handle)
        }
    }

    /// Called from `PluginHost.close()`. Same behaviour as `close()` but
    /// the host has already removed us from its tracking map.
    internal func closeFromHost() async {
        if closed { return }
        closed = true
        funcs.close(handle)
    }
}
