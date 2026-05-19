// VolvoxGridTerminalSession.swift
//
// Swift port of dotnet/src/common/VolvoxGridTerminal.cs. Wraps a
// bidirectional render stream switched into TUI mode so the engine
// writes ANSI bytes into a pinned host-side buffer instead of pixels
// into a swap chain.
//
// Lifecycle:
//   let session = try await client.openTerminalSession(gridId)
//   await session.setCapabilities(caps)
//   await session.setViewport(width: cols, height: rows, fullscreen: true)
//   let frame = try await session.render()
//   stdoutWrite(frame.bytes, frame.bytesWritten)
//   ...
//   _ = try await session.shutdown()
//   await session.close()
//
// On every `render()` the session lazily flushes any dirty capabilities
// or viewport state, then asks the engine to fill the pinned buffer.
// If the engine signals `requiredCapacity > buffer.count` we re-allocate
// at a larger size and retry the same frame.

import Foundation

/// Terminal renderer kind reported on each frame — the engine first
/// emits `sessionStart`, then steady-state `frame` updates, then
/// `sessionEnd` after `shutdown()`.
public enum VolvoxGridTerminalRenderKind: Sendable {
    case frame
    case sessionStart
    case sessionEnd

    fileprivate init(_ wire: FrameKind) {
        switch wire {
        case .sessionStart: self = .sessionStart
        case .sessionEnd:   self = .sessionEnd
        default:            self = .frame
        }
    }
}

/// What the host claims the terminal can render. Mirrors the
/// .NET `VolvoxGridTerminalCapabilities` class — same defaults, so a
/// stock initializer asks for full truecolor + mouse + paste + focus
/// events. Drop fields back to safer values for legacy terminals.
public struct VolvoxGridTerminalCapabilities: Sendable {
    public var colorLevel: TerminalColorLevel = .terminalColorLevelAuto
    public var sgrMouse: Bool = true
    public var focusEvents: Bool = true
    public var bracketedPaste: Bool = true

    public init(
        colorLevel: TerminalColorLevel = .terminalColorLevelAuto,
        sgrMouse: Bool = true,
        focusEvents: Bool = true,
        bracketedPaste: Bool = true
    ) {
        self.colorLevel = colorLevel
        self.sgrMouse = sgrMouse
        self.focusEvents = focusEvents
        self.bracketedPaste = bracketedPaste
    }

    fileprivate func toProto() -> TerminalCapabilities {
        var c = TerminalCapabilities()
        c.colorLevel = colorLevel
        c.sgrMouse = sgrMouse
        c.focusEvents = focusEvents
        c.bracketedPaste = bracketedPaste
        return c
    }
}

/// One TUI frame delivered by the engine. `bytes` is a *borrowed view*
/// of the session's pinned ANSI buffer — write it to stdout before the
/// next `render()` call, after which the buffer may be re-used.
///
/// `bytesWritten` is the authoritative length; `bytes.count` is the
/// capacity allocated for the buffer (always ≥ `bytesWritten`).
public struct VolvoxGridTerminalFrame: @unchecked Sendable {
    public let bytes: UnsafeBufferPointer<UInt8>
    public let bytesWritten: Int
    public let rendered: Bool
    public let kind: VolvoxGridTerminalRenderKind
    public let metrics: FrameMetrics?

    /// Convenience: copy the live ANSI prefix into a `Data` so the
    /// caller can hold it across the next `render()`. Most callers
    /// don't need this — they write the bytes immediately and the
    /// pinned buffer gets re-used on the next frame.
    public var data: Data {
        guard bytesWritten > 0, let base = bytes.baseAddress else { return Data() }
        return Data(bytes: base, count: bytesWritten)
    }
}

public enum VolvoxGridTerminalError: Error, CustomStringConvertible {
    case viewportNotSet
    case streamClosed
    case sessionClosed

    public var description: String {
        switch self {
        case .viewportNotSet: return "setViewport must be called before render()"
        case .streamClosed:   return "terminal render stream closed unexpectedly"
        case .sessionClosed:  return "terminal session is closed"
        }
    }
}

/// Bidi render stream specialized for the TUI renderer. Caller drives
/// it with `setCapabilities` / `setViewport` / `sendInput` / `render`;
/// the actor serializes everything onto its own task so concurrent
/// calls compose safely.
public actor VolvoxGridTerminalSession {

    private static let defaultBufferCapacity = 32 * 1024
    private static let shutdownBufferFloor   = 256

    private let gridId: Int64
    private let stream: BidiStream<RenderInput, RenderOutput>
    private var responses: AsyncThrowingStream<RenderOutput, Error>.AsyncIterator

    // Pinned ANSI buffer. Address-stable for the engine's lifetime;
    // we only re-allocate when the engine asks for more capacity.
    private var buffer: UnsafeMutablePointer<UInt8>?
    private var bufferCapacity: Int = 0

    // Pending capabilities / viewport. We don't send them until the
    // first render() so callers can configure freely without burning
    // FFI calls per setter.
    private var capabilities = VolvoxGridTerminalCapabilities()
    private var capabilitiesDirty = true
    private var originX: Int32 = 0
    private var originY: Int32 = 0
    private var width: Int32 = 0
    private var height: Int32 = 0
    private var fullscreen = false
    private var viewportDirty = false

    private var lastMetrics: FrameMetrics?
    private var closed = false

    /// Created internally by `VolvoxGridClient.openTerminalSession`.
    internal init(gridId: Int64, stream: BidiStream<RenderInput, RenderOutput>) {
        self.gridId = gridId
        self.stream = stream
        self.responses = stream.responses().makeAsyncIterator()
    }

    deinit {
        if let buf = buffer {
            buf.deallocate()
        }
    }

    // MARK: - Public surface

    public func currentMetrics() -> FrameMetrics? { lastMetrics }

    /// Replace the cached host capabilities. Flushed lazily on the
    /// next `render()` call.
    public func setCapabilities(_ caps: VolvoxGridTerminalCapabilities) {
        capabilities = caps
        capabilitiesDirty = true
    }

    /// Declare the terminal's cell-grid viewport. `width` × `height`
    /// are in *cells*. `fullscreen = true` is the conventional choice
    /// for full-screen apps; pass `false` when embedding inside a
    /// larger TUI host that owns part of the screen.
    public func setViewport(
        originX: Int32 = 0,
        originY: Int32 = 0,
        width: Int32,
        height: Int32,
        fullscreen: Bool = true
    ) {
        precondition(width > 0, "viewport width must be positive")
        precondition(height > 0, "viewport height must be positive")
        let ox = max(0, originX)
        let oy = max(0, originY)
        if self.originX == ox
            && self.originY == oy
            && self.width == width
            && self.height == height
            && self.fullscreen == fullscreen
            && !viewportDirty {
            return
        }
        self.originX = ox
        self.originY = oy
        self.width = width
        self.height = height
        self.fullscreen = fullscreen
        self.viewportDirty = true
    }

    /// Forward raw terminal input bytes (everything stdin handed you)
    /// to the engine. Pass the slice you actually read — never the
    /// whole backing buffer.
    public func sendInput(_ data: Data) async throws {
        try ensureOpen()
        guard !data.isEmpty else { return }
        var bytes = TerminalInputBytes()
        bytes.data = data
        var input = RenderInput()
        input.gridId = gridId
        input.input = .terminalInput(bytes)
        try await stream.send(input)
    }

    /// Ask the engine for the next frame. Lazily flushes any dirty
    /// capabilities or viewport state first, then drains responses
    /// from the bidi stream until the engine echoes back our buffer
    /// handle in a `FrameDone`. Re-allocates the buffer and retries
    /// if the engine reports `requiredCapacity > current`.
    public func render() async throws -> VolvoxGridTerminalFrame {
        try ensureOpen()
        guard width > 0, height > 0 else {
            throw VolvoxGridTerminalError.viewportNotSet
        }
        try await flushTerminalState()
        return try await requestFrame(minimumCapacity: Self.defaultBufferCapacity)
    }

    /// Send TERMINAL_COMMAND_EXIT and drain frames until we see a
    /// `sessionEnd` (or a frame with bytes to flush). The returned
    /// frame is the final ANSI flush; write it to stdout to leave the
    /// terminal in a clean state.
    public func shutdown() async throws -> VolvoxGridTerminalFrame {
        try ensureOpen()
        var cmd = TerminalCommand()
        cmd.kind = .terminalCommandExit
        var input = RenderInput()
        input.gridId = gridId
        input.input = .terminalCommand(cmd)
        try await stream.send(input)
        return try await requestFrame(minimumCapacity: Self.shutdownBufferFloor)
    }

    /// Close the underlying render stream and release the pinned
    /// buffer. Idempotent.
    public func close() async {
        if closed { return }
        closed = true
        await stream.close()
        if let buf = buffer {
            buf.deallocate()
            buffer = nil
            bufferCapacity = 0
        }
    }

    // MARK: - Private

    private func ensureOpen() throws {
        if closed { throw VolvoxGridTerminalError.sessionClosed }
    }

    private func flushTerminalState() async throws {
        if capabilitiesDirty {
            var input = RenderInput()
            input.gridId = gridId
            input.input = .terminalCapabilities(capabilities.toProto())
            try await stream.send(input)
            capabilitiesDirty = false
        }
        if viewportDirty {
            var viewport = TerminalViewport()
            viewport.originX = originX
            viewport.originY = originY
            viewport.width = width
            viewport.height = height
            viewport.fullscreen = fullscreen
            var input = RenderInput()
            input.gridId = gridId
            input.input = .terminalViewport(viewport)
            try await stream.send(input)
            viewportDirty = false
        }
    }

    private func requestFrame(minimumCapacity: Int) async throws -> VolvoxGridTerminalFrame {
        // Retry loop — the engine may demand a bigger buffer mid-frame.
        while true {
            ensureBuffer(capacity: minimumCapacity)
            guard let buf = buffer else {
                fatalError("VolvoxGridTerminalSession: buffer not allocated after ensureBuffer")
            }
            let handle = Int64(Int(bitPattern: UnsafeMutableRawPointer(buf)))

            var bufferReady = BufferReady()
            bufferReady.handle = handle
            bufferReady.capacity = Int32(bufferCapacity)
            bufferReady.width = width
            bufferReady.height = height

            var input = RenderInput()
            input.gridId = gridId
            input.input = .buffer(bufferReady)
            try await stream.send(input)

            while true {
                guard let output = try await nextResponse() else {
                    throw VolvoxGridTerminalError.streamClosed
                }
                guard case let .frameDone(frame) = output.event,
                      frame.handle == handle else {
                    // Frame for a stale buffer, or some other event
                    // (selection/cursor/editor*). The host-loop layer
                    // is what cares about those — at the session level
                    // we keep draining until the FrameDone for *our*
                    // current handle arrives.
                    continue
                }

                if frame.requiredCapacity > Int32(bufferCapacity) {
                    // Grow and retry the entire send/recv pair.
                    ensureBuffer(capacity: Int(frame.requiredCapacity))
                    break
                }

                lastMetrics = frame.metrics
                let view = UnsafeBufferPointer(start: buf, count: bufferCapacity)
                return VolvoxGridTerminalFrame(
                    bytes: view,
                    bytesWritten: max(0, Int(frame.bytesWritten)),
                    rendered: output.rendered,
                    kind: VolvoxGridTerminalRenderKind(frame.frameKind),
                    metrics: frame.metrics
                )
            }
        }
    }

    /// Pull one response off the bidi stream. Swift forbids `mutating`
    /// async calls on actor-isolated properties; the round-trip through
    /// a local var sidesteps that without leaking iteration order
    /// (the actor still serializes access to `responses`).
    private func nextResponse() async throws -> RenderOutput? {
        var iter = responses
        let output = try await iter.next()
        responses = iter
        return output
    }

    private func ensureBuffer(capacity: Int) {
        let target = max(Self.defaultBufferCapacity, capacity)
        if bufferCapacity >= target { return }
        if let old = buffer { old.deallocate() }
        let fresh = UnsafeMutablePointer<UInt8>.allocate(capacity: target)
        fresh.initialize(repeating: 0, count: target)
        buffer = fresh
        bufferCapacity = target
    }
}
