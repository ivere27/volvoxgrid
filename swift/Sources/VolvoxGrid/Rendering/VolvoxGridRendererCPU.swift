// VolvoxGridRendererCPU.swift
//
// Host-side CPU rendering loop for VolvoxGrid. Owns a single RGBA8 byte
// buffer, drives the bidirectional render session, and yields each
// FrameDone to consumers as a `CPUFrame` (Data-backed snapshot the view
// is free to keep around).
//
// Protocol summary (proto/volvoxgrid.proto:2707–2920):
//
//   host -> engine
//     RenderInput.viewport(ViewportState{width,height})  -- on resize
//     RenderInput.buffer(BufferReady{handle,stride,...}) -- "render here"
//
//   engine -> host
//     RenderOutput.frameDone(FrameDone{handle,dirty…,requiredCapacity})
//
// The engine writes into our buffer when we send a `BufferReady`; we
// receive `FrameDone` exactly once per buffer. Pacing lives inside the
// engine (frame-pacing mode honors host capabilities), so we just keep a
// single BufferReady outstanding at all times. After consuming a frame
// we hand the buffer back via another BufferReady, and the engine fires
// the next frame whenever its scheduler is ready.

import Foundation

/// One frame the engine produced, copied off the rendering buffer.
///
/// `pixels` is RGBA8 (R at offset+0, A at offset+3) of length
/// `stride * height`. The byte order matches what `CGImage` expects with
/// `bitmapInfo = .byteOrder32Big | premultipliedLast` (which is the
/// representation the engine writes — see TEXT_RENDERING.md).
public struct CPUFrame: Sendable {
    public let pixels: Data
    public let width: Int32
    public let height: Int32
    public let stride: Int32
    public let dirtyX: Int32
    public let dirtyY: Int32
    public let dirtyW: Int32
    public let dirtyH: Int32
    public let frameKind: FrameKind

    /// `true` when the engine actually wrote pixels into this frame.
    /// Clean frames still cost a wire round-trip; views can short-circuit
    /// the CGImage build when `hasContent == false`.
    public var hasContent: Bool { dirtyW > 0 && dirtyH > 0 }
}

public enum VolvoxGridEditorEvent: Sendable {
    case started(EditorSessionStarted)
    case updated(EditorSessionUpdated)
    case ended(EditorSessionEnded)
}

/// Single-buffer CPU renderer. The view drives `resize(...)`; the
/// renderer drives the buffer round-trips and emits frames.
///
/// Threading: this is an `actor` so all stream + buffer state is
/// serialised internally. The view should consume `frames` from a single
/// `Task` and forward the latest frame to its layer on `MainActor`.
public actor VolvoxGridRendererCPU {

    // MARK: - Stream / state

    private let client: VolvoxGridClient
    private var session: BidiStream<RenderInput, RenderOutput>?
    private var recvTask: Task<Void, Never>?
    private var gridId: Int64 = 0
    private var started: Bool = false
    private var pendingFrame: Bool = false

    // MARK: - Buffer

    private var bufferRaw: UnsafeMutableRawPointer?
    private var bufferCapacity: Int = 0    // bytes
    private var bufferWidth: Int32 = 0
    private var bufferHeight: Int32 = 0
    private var bufferStride: Int32 = 0    // == width * 4

    private var viewportWidth: Int32 = 0
    private var viewportHeight: Int32 = 0

    // MARK: - Frame fan-out

    /// Async sequence of frames produced by the engine. Consume from a
    /// single `Task` — `AsyncStream` is single-consumer by design.
    public nonisolated let frames: AsyncStream<CPUFrame>
    private nonisolated let continuation: AsyncStream<CPUFrame>.Continuation

    /// Editor lifecycle events coupled to the render stream. GUI hosts
    /// use this to mount and reposition host-native editor widgets.
    public nonisolated let editorEvents: AsyncStream<VolvoxGridEditorEvent>
    private nonisolated let editorContinuation: AsyncStream<VolvoxGridEditorEvent>.Continuation

    // MARK: - Construction

    public init(client: VolvoxGridClient) {
        self.client = client
        var c: AsyncStream<CPUFrame>.Continuation!
        let s = AsyncStream<CPUFrame>(bufferingPolicy: .bufferingNewest(1)) { c = $0 }
        self.frames = s
        self.continuation = c
        var ec: AsyncStream<VolvoxGridEditorEvent>.Continuation!
        let es = AsyncStream<VolvoxGridEditorEvent>(bufferingPolicy: .unbounded) { ec = $0 }
        self.editorEvents = es
        self.editorContinuation = ec
    }

    deinit {
        if let raw = bufferRaw {
            raw.deallocate()
        }
        continuation.finish()
        editorContinuation.finish()
    }

    // MARK: - Lifecycle

    /// Opens a render session against `gridId`, sends the initial
    /// viewport, and starts the recv loop. Idempotent: a second call
    /// throws `RendererAlreadyStartedError`.
    public func start(gridId: Int64, width: Int32, height: Int32) async throws {
        if started {
            throw RendererAlreadyStartedError()
        }
        self.gridId = gridId
        self.viewportWidth = width
        self.viewportHeight = height

        let session = try await client.openRenderSession()
        self.session = session

        try await sendViewport(width: width, height: height)
        started = true

        let stream = session
        let cont = continuation
        recvTask = Task { [weak self] in
            do {
                for try await output in stream.responses() {
                    await self?.handle(output)
                }
            } catch is CancellationError {
                // Normal teardown.
            } catch {
                // Recv-side errors aren't propagated through the
                // frame stream beyond closing it; the next user-
                // initiated call against the client will surface them.
            }
            cont.finish()
        }

        try await requestFrameLocked()
    }

    /// Resize the engine's viewport. Allocates a larger buffer if the
    /// new dimensions don't fit the current one. Safe to call before
    /// the next FrameDone arrives — we'll just ignore the stale frame.
    public func resize(width: Int32, height: Int32) async throws {
        guard width > 0, height > 0 else { return }
        if width == viewportWidth && height == viewportHeight { return }
        viewportWidth = width
        viewportHeight = height
        try await sendViewport(width: width, height: height)
        if !pendingFrame {
            try await requestFrameLocked()
        }
    }

    /// Tear down the session and free the buffer. Idempotent.
    public func close() async {
        recvTask?.cancel()
        recvTask = nil
        if let s = session {
            await s.close()
        }
        session = nil
        if let raw = bufferRaw {
            raw.deallocate()
            bufferRaw = nil
            bufferCapacity = 0
        }
        continuation.finish()
        editorContinuation.finish()
        started = false
    }

    // MARK: - Recv side

    private func handle(_ output: RenderOutput) async {
        switch output.event {
        case .frameDone(let frame):
            await handleFrameDone(frame)
        case .editorStarted(let started):
            editorContinuation.yield(.started(started))
        case .editorUpdated(let updated):
            editorContinuation.yield(.updated(updated))
        case .editorEnded(let ended):
            editorContinuation.yield(.ended(ended))
        default:
            // Selection / cursor / tooltip events remain on their
            // existing surfaces for now.
            break
        }
    }

    private func handleFrameDone(_ frame: FrameDone) async {
        // Clear before potentially re-arming via requestFrameLocked.
        pendingFrame = false

        guard let raw = bufferRaw else { return }
        let currentHandle = Int64(Int(bitPattern: raw))

        // Engine returns the BufferReady.handle echoed back. If we've
        // grown the buffer in the meantime, the handle won't match and
        // the frame data lives in freed memory — discard.
        guard frame.handle == currentHandle else {
            try? await requestFrameLocked()
            return
        }

        if frame.requiredCapacity > 0 {
            // Engine couldn't fit; grow + retry. Don't yield a frame.
            growBuffer(toBytes: Int(frame.requiredCapacity))
            try? await requestFrameLocked()
            return
        }

        // The dirty rect is in pixels. The engine wrote (at minimum)
        // those bytes — but conservatively copy the entire buffer:
        // CALayer.contents requires the full image, and the contents
        // outside the dirty rect must still be valid from the previous
        // frame (the engine carries them).
        let snapshotLen = bufferCapacity
        let pixels = Data(bytes: raw, count: snapshotLen)
        let cpu = CPUFrame(
            pixels: pixels,
            width: bufferWidth,
            height: bufferHeight,
            stride: bufferStride,
            dirtyX: frame.dirtyX,
            dirtyY: frame.dirtyY,
            dirtyW: frame.dirtyW,
            dirtyH: frame.dirtyH,
            frameKind: frame.frameKind
        )
        continuation.yield(cpu)

        // Hand the buffer back so the engine can render the next frame.
        try? await requestFrameLocked()
    }

    // MARK: - Input (Phase 4)
    //
    // The render session multiplexes input alongside buffer/viewport
    // messages (proto/volvoxgrid.proto:2724–2781). Views call these
    // helpers from their gesture / NSEvent / UIPress handlers; the
    // engine acts on them and the side effects come back as the next
    // FrameDone plus any `openEventStream` GridEvents.

    /// Forward a pointer (touch / mouse) event in viewport pixels.
    /// `modifier` is the Shift/Ctrl/Alt/Meta bitmask (0x01 / 0x02 / 0x04 / 0x08).
    /// `button` is the button bitmask (0x01 = primary, 0x02 = secondary).
    public func sendPointer(
        type: PointerEvent_Type,
        x: Float,
        y: Float,
        modifier: Int32 = 0,
        button: Int32 = 0,
        dblClick: Bool = false
    ) async throws {
        guard let session = session else { return }
        var p = PointerEvent()
        p.type = type
        p.x = x
        p.y = y
        p.modifier = modifier
        p.button = button
        p.dblClick = dblClick
        var input = RenderInput()
        input.gridId = gridId
        input.input = .pointer(p)
        try await session.send(input)
    }

    /// Forward a keyboard event. For `.keyDown` / `.keyUp`, set
    /// `keyCode` (JS-style: 13=Enter, 27=Esc, 8=Backspace, 9=Tab,
    /// 37/38/39/40=Arrows, 33/34=PgUp/PgDn, 36/35=Home/End, 46=Del,
    /// 113=F2, 65–90=A–Z). For `.keyPress` set `character`.
    public func sendKey(
        type: KeyEvent_Type,
        keyCode: Int32 = 0,
        modifier: Int32 = 0,
        character: String = ""
    ) async throws {
        guard let session = session else { return }
        var k = KeyEvent()
        k.type = type
        k.keyCode = keyCode
        k.modifier = modifier
        k.character = character
        var input = RenderInput()
        input.gridId = gridId
        input.input = .key(k)
        try await session.send(input)
    }

    /// Forward a scroll-wheel / two-finger-pan delta in viewport pixels.
    /// Positive `deltaY` scrolls content up (matches macOS / Java).
    public func sendScroll(deltaX: Float, deltaY: Float) async throws {
        guard let session = session else { return }
        var s = ScrollEvent()
        s.deltaX = deltaX
        s.deltaY = deltaY
        var input = RenderInput()
        input.gridId = gridId
        input.input = .scroll(s)
        try await session.send(input)
    }

    /// Forward a pinch-zoom phase. `scale` is the cumulative scale for
    /// the gesture; `focalX/Y` is in viewport pixels.
    public func sendZoom(
        phase: ZoomEvent_Phase,
        scale: Float,
        focalX: Float,
        focalY: Float
    ) async throws {
        guard let session = session else { return }
        var z = ZoomEvent()
        z.phase = phase
        z.scale = scale
        z.focalXPx = focalX
        z.focalYPx = focalY
        var input = RenderInput()
        input.gridId = gridId
        input.input = .zoom(z)
        try await session.send(input)
    }

    // MARK: - Send side

    private func sendViewport(width: Int32, height: Int32) async throws {
        guard let session = session else { return }
        var vp = ViewportState()
        vp.width = width
        vp.height = height
        var input = RenderInput()
        input.gridId = gridId
        input.input = .viewport(vp)
        try await session.send(input)
    }

    private func requestFrameLocked() async throws {
        guard let session = session else { return }
        guard viewportWidth > 0, viewportHeight > 0 else { return }
        ensureBuffer(width: viewportWidth, height: viewportHeight)
        guard let raw = bufferRaw else { return }

        var ready = BufferReady()
        ready.handle = Int64(Int(bitPattern: raw))
        ready.stride = bufferStride
        ready.width = bufferWidth
        ready.height = bufferHeight
        ready.capacity = Int32(clamping: bufferCapacity)

        var input = RenderInput()
        input.gridId = gridId
        input.input = .buffer(ready)
        try await session.send(input)
        pendingFrame = true
    }

    private func ensureBuffer(width: Int32, height: Int32) {
        let stride = width &* 4
        let needed = Int(stride) &* Int(height)
        guard needed > 0 else { return }
        if bufferRaw == nil || needed > bufferCapacity {
            growBuffer(toBytes: needed)
        }
        bufferWidth = width
        bufferHeight = height
        bufferStride = stride
    }

    private func growBuffer(toBytes minBytes: Int) {
        if let raw = bufferRaw {
            raw.deallocate()
        }
        // 16-byte alignment is friendly to SIMD reads in cosmic-text /
        // the engine without imposing more than a page-aligned alloc
        // would. Page alignment would waste megabytes for small grids.
        let raw = UnsafeMutableRawPointer.allocate(byteCount: minBytes, alignment: 16)
        raw.initializeMemory(as: UInt8.self, repeating: 0, count: minBytes)
        bufferRaw = raw
        bufferCapacity = minBytes
    }

}

/// Thrown when `start(...)` is called on an already-started renderer.
public struct RendererAlreadyStartedError: Error, Sendable {
    public init() {}
}
