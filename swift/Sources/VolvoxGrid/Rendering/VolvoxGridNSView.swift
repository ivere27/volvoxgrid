// VolvoxGridNSView.swift
//
// AppKit host for the VolvoxGrid CPU rendering loop. Mirrors
// VolvoxGridUIView for macOS hosts that aren't using Mac Catalyst.
//
// Input wiring:
//   - Mouse left/right press, drag, release → PointerEvent DOWN/MOVE/UP.
//   - scrollWheel  → ScrollEvent.
//   - magnify      → ZoomEvent.
//   - keyDown/Up   → KeyEvent.
//   - NSTextView   → host-native inline editor with AppKit IME.

#if canImport(AppKit)
import AppKit
import CoreGraphics

@MainActor
public final class VolvoxGridNSView: NSView, NSTextViewDelegate {

    public private(set) weak var client: VolvoxGridClient?
    public private(set) var gridId: Int64 = 0
    public private(set) var hasReceivedFrame: Bool = false

    private var renderer: VolvoxGridRendererCPU?
    private var consumerTask: Task<Void, Never>?
    private var editorTask: Task<Void, Never>?
    private var lastSentSize: CGSize = .zero
    private var zoomCumulative: Float = 1.0

    private var nativeTextView: VolvoxGridMacNativeTextView?
    private var nativeEditorDisplayed = false
    private var suppressNativeTextChange = false
    private var suppressNativeCommit = false
    private var nativeImeComposing = false
    private var pendingHostEditorStart = false
    private var activeEditorSessionId: Int64 = 0
    private var activeEditorStateVersion: UInt64 = 0
    private var activeEditorRow: Int32 = -1
    private var activeEditorCol: Int32 = -1
    private var activeEditorUiMode: EditUiMode = .enter

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    public override var isFlipped: Bool { true }

    public override var wantsUpdateLayer: Bool { true }

    private func commonInit() {
        wantsLayer = true
        layerContentsRedrawPolicy = .onSetNeedsDisplay
        layer?.contentsGravity = .resize
        layer?.magnificationFilter = .nearest
        layer?.minificationFilter = .linear
        layer?.contentsScale = NSScreen.main?.backingScaleFactor ?? 1.0

        let textView = VolvoxGridMacNativeTextView(frame: .zero)
        textView.host = self
        textView.delegate = self
        textView.isEditable = true
        textView.isSelectable = true
        textView.isRichText = false
        textView.allowsUndo = true
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isContinuousSpellCheckingEnabled = false
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textContainerInset = NSSize(width: 3, height: 0)
        addSubview(textView)
        nativeTextView = textView
        enterNativeEditorProxyMode(requestFocus: false)
    }

    deinit {
        consumerTask?.cancel()
        editorTask?.cancel()
    }

    public func bind(client: VolvoxGridClient, gridId: Int64) {
        unbind()
        self.client = client
        self.gridId = gridId
        let renderer = VolvoxGridRendererCPU(client: client)
        self.renderer = renderer

        let (width, height) = currentPixelSize()
        lastSentSize = bounds.size

        editorTask = Task { [weak self] in
            for await event in renderer.editorEvents {
                guard !Task.isCancelled else { break }
                await self?.handleEditorEvent(event)
            }
        }

        consumerTask = Task { [weak self] in
            do {
                try await renderer.start(gridId: gridId, width: width, height: height)
            } catch {
                return
            }
            for await frame in renderer.frames {
                guard !Task.isCancelled else { break }
                await self?.consume(frame)
            }
        }
    }

    public func unbind() {
        consumerTask?.cancel()
        consumerTask = nil
        editorTask?.cancel()
        editorTask = nil
        let r = renderer
        renderer = nil
        if let r = r {
            Task { await r.close() }
        }
        hideNativeEditor(focusProxy: false)
        client = nil
        gridId = 0
        hasReceivedFrame = false
        lastSentSize = .zero
    }

    public override func layout() {
        super.layout()
        guard renderer != nil else { return }
        if bounds.size == lastSentSize { return }
        lastSentSize = bounds.size
        let (width, height) = currentPixelSize()
        guard width > 0, height > 0 else { return }
        if let renderer = renderer {
            Task { try? await renderer.resize(width: width, height: height) }
        }
    }

    public override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let window = window {
            layer?.contentsScale = window.backingScaleFactor
            needsLayout = true
            focusNativeTextInput()
        }
    }

    @MainActor
    private func consume(_ frame: CPUFrame) {
        guard frame.hasContent else { return }
        guard let cgImage = makeCGImage(from: frame) else { return }
        layer?.contents = cgImage
        hasReceivedFrame = true
    }

    private func makeCGImage(from frame: CPUFrame) -> CGImage? {
        let pixels = frame.pixels
        guard !pixels.isEmpty else { return nil }
        let cfData = pixels as CFData
        guard let provider = CGDataProvider(data: cfData) else { return nil }
        let bitmapInfo: CGBitmapInfo = [
            .byteOrder32Big,
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        ]
        return CGImage(
            width: Int(frame.width),
            height: Int(frame.height),
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: Int(frame.stride),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    private func currentPixelSize() -> (Int32, Int32) {
        let scale = layer?.contentsScale ?? 1.0
        let w = Int32(max(0, bounds.size.width * scale))
        let h = Int32(max(0, bounds.size.height * scale))
        return (w, h)
    }

    // MARK: - First responder

    public override var acceptsFirstResponder: Bool { true }

    public override func becomeFirstResponder() -> Bool { true }

    public override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    // MARK: - Mouse → PointerEvent

    public override func mouseDown(with event: NSEvent) {
        focusNativeTextInput()
        sendPointer(.down, event: event, button: 0x01,
                    dblClick: event.clickCount >= 2)
    }

    public override func mouseDragged(with event: NSEvent) {
        sendPointer(.move, event: event, button: 0x01)
    }

    public override func mouseUp(with event: NSEvent) {
        sendPointer(.up, event: event, button: 0x01)
    }

    public override func rightMouseDown(with event: NSEvent) {
        focusNativeTextInput()
        sendPointer(.down, event: event, button: 0x02,
                    dblClick: event.clickCount >= 2)
    }

    public override func rightMouseDragged(with event: NSEvent) {
        sendPointer(.move, event: event, button: 0x02)
    }

    public override func rightMouseUp(with event: NSEvent) {
        sendPointer(.up, event: event, button: 0x02)
    }

    private func sendPointer(
        _ type: PointerEvent_Type,
        event: NSEvent,
        button: Int32,
        dblClick: Bool = false
    ) {
        guard let renderer = renderer else { return }
        let p = convert(event.locationInWindow, from: nil)
        let scale = Float(layer?.contentsScale ?? 1.0)
        let x = Float(p.x) * scale
        let y = Float(p.y) * scale
        let modifier = engineModifier(event.modifierFlags)
        Task {
            try? await renderer.sendPointer(
                type: type, x: x, y: y,
                modifier: modifier, button: button, dblClick: dblClick
            )
        }
    }

    // MARK: - Scroll → ScrollEvent

    public override func scrollWheel(with event: NSEvent) {
        guard let renderer = renderer else { return }
        let scale = Float(layer?.contentsScale ?? 1.0)
        let dx = Float(event.scrollingDeltaX) * scale
        let dy = Float(event.scrollingDeltaY) * scale
        if dx == 0 && dy == 0 { return }
        Task {
            try? await renderer.sendScroll(deltaX: dx, deltaY: dy)
        }
    }

    // MARK: - Magnify → ZoomEvent

    public override func magnify(with event: NSEvent) {
        guard let renderer = renderer else { return }
        let p = convert(event.locationInWindow, from: nil)
        let scale = Float(layer?.contentsScale ?? 1.0)
        let fx = Float(p.x) * scale
        let fy = Float(p.y) * scale

        let phase: ZoomEvent_Phase
        switch event.phase {
        case .began:
            zoomCumulative = 1.0
            phase = .zoomBegin
        case .changed:
            phase = .zoomUpdate
        case .ended, .cancelled:
            phase = .zoomEnd
        default:
            return
        }
        zoomCumulative *= Float(1.0 + event.magnification)
        let s = zoomCumulative
        Task {
            try? await renderer.sendZoom(phase: phase, scale: s, focalX: fx, focalY: fy)
        }
    }

    // MARK: - Host-native editor / IME

    private func handleEditorEvent(_ event: VolvoxGridEditorEvent) {
        switch event {
        case .started(let started):
            guard let session = started.session else { return }
            showNativeEditor(session, preserveCurrentText: pendingHostEditorStart)
        case .updated(let updated):
            updateNativeEditor(updated)
        case .ended:
            hideNativeEditor(focusProxy: true)
        }
    }

    private func showNativeEditor(_ session: EditorSession, preserveCurrentText: Bool) {
        activeEditorSessionId = session.sessionId
        activeEditorStateVersion = session.stateVersion
        activeEditorRow = session.row
        activeEditorCol = session.col
        activeEditorUiMode = session.uiMode

        guard volvoxIsTextEditableSession(session), let rect = session.viewportRect else {
            nativeEditorDisplayed = false
            enterNativeEditorProxyMode(requestFocus: true)
            pendingHostEditorStart = false
            return
        }
        guard let textView = nativeTextView else { return }

        nativeEditorDisplayed = true
        applyNativeEditorFrame(rect)
        textView.drawsBackground = true
        textView.backgroundColor = .textBackgroundColor
        textView.textColor = .textColor
        textView.insertionPointColor = .textColor
        textView.alphaValue = 1

        if !preserveCurrentText {
            let text = volvoxEditorText(session.value)
            let selection = session.selection
            let start = volvoxUTF16Offset(forCodePoint: selection?.start ?? 0, in: text)
            let end = volvoxUTF16Offset(
                forCodePoint: (selection?.start ?? 0) + (selection?.length ?? volvoxCodePointLength(text)),
                in: text
            )
            suppressNativeTextChange = true
            textView.string = text
            textView.setSelectedRange(NSRange(location: start, length: max(0, end - start)))
            suppressNativeTextChange = false
        }

        pendingHostEditorStart = false
        window?.makeFirstResponder(textView)
        syncNativeEditorSelectionToEngine()
        if preserveCurrentText {
            applyNativeEditorText(textView.string)
        }
    }

    private func updateNativeEditor(_ update: EditorSessionUpdated) {
        if activeEditorSessionId == 0 || update.sessionId == activeEditorSessionId {
            activeEditorSessionId = update.sessionId
            activeEditorStateVersion = update.stateVersion
        }
        if let visible = update.visible, !visible {
            hideNativeEditor(focusProxy: true)
            return
        }
        guard nativeEditorDisplayed else { return }
        if let rect = update.viewportRect {
            applyNativeEditorFrame(rect)
        }
        guard let textView = nativeTextView else { return }
        if let value = update.value, !nativeImeComposing {
            let text = volvoxEditorText(value)
            suppressNativeTextChange = true
            textView.string = text
            suppressNativeTextChange = false
        }
        if let selection = update.selection {
            let text = textView.string
            let start = volvoxUTF16Offset(forCodePoint: selection.start, in: text)
            let end = volvoxUTF16Offset(forCodePoint: selection.start + selection.length, in: text)
            textView.setSelectedRange(NSRange(location: start, length: max(0, end - start)))
        }
    }

    private func applyNativeEditorFrame(_ rect: Rect) {
        guard let textView = nativeTextView else { return }
        let scale = CGFloat(layer?.contentsScale ?? 1.0)
        let frame = NSRect(
            x: CGFloat(rect.x) / scale,
            y: CGFloat(rect.y) / scale,
            width: max(1, CGFloat(rect.width) / scale),
            height: max(1, CGFloat(rect.height) / scale)
        )
        textView.frame = frame.insetBy(dx: -1, dy: -1)
        textView.needsDisplay = true
    }

    private func hideNativeEditor(focusProxy: Bool) {
        suppressNativeCommit = true
        nativeEditorDisplayed = false
        nativeImeComposing = false
        pendingHostEditorStart = false
        activeEditorSessionId = 0
        activeEditorStateVersion = 0
        activeEditorRow = -1
        activeEditorCol = -1
        activeEditorUiMode = .enter
        enterNativeEditorProxyMode(requestFocus: focusProxy)
        suppressNativeCommit = false
    }

    private func enterNativeEditorProxyMode(requestFocus: Bool) {
        guard let textView = nativeTextView else { return }
        suppressNativeTextChange = true
        textView.string = ""
        textView.setSelectedRange(NSRange(location: 0, length: 0))
        suppressNativeTextChange = false
        textView.frame = NSRect(x: 0, y: 0, width: 1, height: 1)
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .clear
        textView.insertionPointColor = .clear
        textView.alphaValue = 0.01
        if requestFocus {
            focusNativeTextInput()
        }
    }

    private func focusNativeTextInput() {
        guard let textView = nativeTextView, window != nil else { return }
        window?.makeFirstResponder(textView)
    }

    public func textDidChange(_ notification: Notification) {
        handleNativeTextDidChange()
    }

    public func textViewDidChangeSelection(_ notification: Notification) {
        syncNativeEditorSelectionToEngine()
    }

    public func textDidEndEditing(_ notification: Notification) {
        if nativeEditorDisplayed && !suppressNativeCommit {
            commitNativeEditor(navigateKeyCode: nil, navigateModifier: 0)
        }
    }

    fileprivate func handleNativeTextDidChange() {
        guard let textView = nativeTextView, !suppressNativeTextChange else { return }
        if !nativeEditorDisplayed {
            guard !textView.string.isEmpty else { return }
            beginHostEditorFromProxy()
            return
        }
        if nativeImeComposing { return }
        applyNativeEditorText(textView.string)
        syncNativeEditorSelectionToEngine()
    }

    fileprivate func handleNativeMarkedTextChanged(_ text: String, cursor: Int32) {
        nativeImeComposing = !text.isEmpty
        if !nativeEditorDisplayed {
            beginHostEditorFromProxy()
            return
        }
        let sessionId = activeEditorSessionId
        let id = gridId
        guard let client = client, id != 0 else { return }
        Task {
            try? await client.editSetPreedit(id, text: text, cursor: cursor, commit: false, sessionId: sessionId)
            try? await client.refresh(id)
        }
    }

    fileprivate func handleNativeMarkedTextCommitted() {
        let wasComposing = nativeImeComposing
        nativeImeComposing = false
        guard wasComposing, nativeEditorDisplayed, let textView = nativeTextView else { return }
        let sessionId = activeEditorSessionId
        let id = gridId
        guard let client = client, id != 0 else { return }
        let text = textView.string
        Task {
            try? await client.editSetPreedit(id, text: "", cursor: 0, commit: true, sessionId: sessionId)
            try? await client.editSetText(id, text: text, sessionId: sessionId)
            try? await client.refresh(id)
        }
    }

    private func beginHostEditorFromProxy() {
        guard !pendingHostEditorStart,
              let client = client,
              gridId != 0,
              let textView = nativeTextView else { return }
        pendingHostEditorStart = true
        let id = gridId
        let seedText = textView.string
        let caret = Int32(seedText.unicodeScalars.count)
        Task { [weak self] in
            do {
                let selection = try await client.getSelection(id)
                try await client.editStart(
                    id,
                    row: selection.activeRow,
                    col: selection.activeCol,
                    reason: .editStartImeComposition,
                    seedText: seedText,
                    caretPosition: caret
                )
                let state = try await client.getEditState(id)
                await MainActor.run {
                    guard let self = self else { return }
                    if let session = state.session {
                        self.showNativeEditor(session, preserveCurrentText: true)
                    } else {
                        self.pendingHostEditorStart = false
                        self.enterNativeEditorProxyMode(requestFocus: true)
                    }
                }
                try? await client.refresh(id)
            } catch {
                await MainActor.run {
                    self?.pendingHostEditorStart = false
                    self?.enterNativeEditorProxyMode(requestFocus: true)
                }
            }
        }
    }

    private func applyNativeEditorText(_ text: String) {
        guard nativeEditorDisplayed,
              let client = client,
              gridId != 0 else { return }
        let id = gridId
        let sessionId = activeEditorSessionId
        Task {
            try? await client.editSetText(id, text: text, sessionId: sessionId)
            try? await client.refresh(id)
        }
    }

    private func syncNativeEditorSelectionToEngine() {
        guard nativeEditorDisplayed,
              let textView = nativeTextView,
              let client = client,
              gridId != 0 else { return }
        let range = textView.selectedRange()
        let text = textView.string
        let start = volvoxCodePointOffset(forUTF16Offset: range.location, in: text)
        let end = volvoxCodePointOffset(forUTF16Offset: range.location + range.length, in: text)
        let id = gridId
        let sessionId = activeEditorSessionId
        Task {
            try? await client.editSetSelection(id, start: start, length: max(0, end - start), sessionId: sessionId)
        }
    }

    fileprivate func handleNativeTextViewKeyDown(_ event: NSEvent) -> Bool {
        let code = engineKeyCode(from: event)
        let modifier = engineModifier(event.modifierFlags)
        if nativeEditorDisplayed {
            switch code {
            case 27:
                cancelNativeEditor()
                return true
            case 9:
                commitNativeEditor(navigateKeyCode: 9, navigateModifier: modifier)
                return true
            case 13:
                if event.modifierFlags.contains(.option) { return false }
                commitNativeEditor(navigateKeyCode: event.modifierFlags.contains(.shift) ? 38 : 40, navigateModifier: 0)
                return true
            case 37, 38, 39, 40:
                if activeEditorUiMode == .enter {
                    commitNativeEditor(navigateKeyCode: code, navigateModifier: modifier)
                    return true
                }
                return false
            default:
                return false
            }
        }

        if isTextInputEvent(event) || pendingHostEditorStart {
            return false
        }
        guard code != 0 else { return false }
        let renderer = renderer
        Task {
            try? await renderer?.sendKey(type: .keyDown, keyCode: code, modifier: modifier, character: "")
        }
        return true
    }

    fileprivate func handleNativeTextViewKeyUp(_ event: NSEvent) -> Bool {
        guard !nativeEditorDisplayed, !pendingHostEditorStart else { return true }
        let code = engineKeyCode(from: event)
        guard code != 0 else { return false }
        let modifier = engineModifier(event.modifierFlags)
        let renderer = renderer
        Task {
            try? await renderer?.sendKey(type: .keyUp, keyCode: code, modifier: modifier, character: "")
        }
        return true
    }

    private func commitNativeEditor(navigateKeyCode: Int32?, navigateModifier: Int32) {
        guard nativeEditorDisplayed,
              let client = client,
              gridId != 0,
              let textView = nativeTextView else { return }
        let id = gridId
        let sessionId = activeEditorSessionId
        let text = textView.string
        let renderer = renderer
        Task { [weak self] in
            try? await client.editCommit(id, text: text, sessionId: sessionId)
            try? await client.refresh(id)
            await MainActor.run {
                self?.hideNativeEditor(focusProxy: true)
            }
            if let keyCode = navigateKeyCode {
                try? await renderer?.sendKey(type: .keyDown, keyCode: keyCode, modifier: navigateModifier, character: "")
                try? await renderer?.sendKey(type: .keyUp, keyCode: keyCode, modifier: navigateModifier, character: "")
            }
        }
    }

    private func cancelNativeEditor() {
        guard nativeEditorDisplayed,
              let client = client,
              gridId != 0 else { return }
        let id = gridId
        let sessionId = activeEditorSessionId
        Task { [weak self] in
            try? await client.editCancel(id, sessionId: sessionId)
            try? await client.refresh(id)
            await MainActor.run {
                self?.hideNativeEditor(focusProxy: true)
            }
        }
    }

    private func isTextInputEvent(_ event: NSEvent) -> Bool {
        if event.modifierFlags.contains(.command) || event.modifierFlags.contains(.control) {
            return false
        }
        guard let characters = event.characters, !characters.isEmpty else { return false }
        return characters.unicodeScalars.contains { scalar in
            scalar.value >= 0x20 && !(scalar.value >= 0xF700 && scalar.value <= 0xF8FF)
        }
    }

    // MARK: - Keyboard → KeyEvent

    public override func keyDown(with event: NSEvent) {
        forwardKey(event, type: .keyDown)
    }

    public override func keyUp(with event: NSEvent) {
        forwardKey(event, type: .keyUp)
    }

    private func forwardKey(_ event: NSEvent, type: KeyEvent_Type) {
        guard let renderer = renderer else { return }
        let code = engineKeyCode(from: event)
        let modifier = engineModifier(event.modifierFlags)
        let character = (type == .keyDown) ? (event.characters ?? "") : ""
        Task {
            try? await renderer.sendKey(
                type: type, keyCode: code, modifier: modifier, character: character
            )
            if type == .keyDown && isPrintable(character) {
                try? await renderer.sendKey(
                    type: .keyPress, keyCode: 0, modifier: modifier, character: character
                )
            }
        }
    }

    /// True only for ASCII printable input — `NSEvent.characters` for
    /// arrows / function keys uses private-use scalars (0xF700+) that
    /// would otherwise look "printable" by raw value.
    private func isPrintable(_ s: String) -> Bool {
        guard let scalar = s.unicodeScalars.first else { return false }
        return scalar.value >= 0x20 && scalar.value < 0x7F
    }

    private func engineModifier(_ flags: NSEvent.ModifierFlags) -> Int32 {
        var m: Int32 = 0
        if flags.contains(.shift)   { m |= 0x01 }
        if flags.contains(.control) { m |= 0x02 }
        if flags.contains(.option)  { m |= 0x04 }
        if flags.contains(.command) { m |= 0x08 }
        return m
    }

    /// NSEvent.keyCode is a Carbon kVK_* code; the engine wants the
    /// JS-style key code (proto/volvoxgrid.proto:2799). Letters / digits
    /// come from `charactersIgnoringModifiers`.
    private func engineKeyCode(from event: NSEvent) -> Int32 {
        switch Int(event.keyCode) {
        case 0x24: return 13   // kVK_Return
        case 0x4C: return 13   // kVK_ANSI_KeypadEnter
        case 0x35: return 27   // kVK_Escape
        case 0x33: return 8    // kVK_Delete (backspace)
        case 0x30: return 9    // kVK_Tab
        case 0x75: return 46   // kVK_ForwardDelete
        case 0x7B: return 37   // kVK_LeftArrow
        case 0x7C: return 39   // kVK_RightArrow
        case 0x7E: return 38   // kVK_UpArrow
        case 0x7D: return 40   // kVK_DownArrow
        case 0x74: return 33   // kVK_PageUp
        case 0x79: return 34   // kVK_PageDown
        case 0x73: return 36   // kVK_Home
        case 0x77: return 35   // kVK_End
        case 0x78: return 113  // kVK_F2
        default: break
        }
        if let s = event.charactersIgnoringModifiers,
           let scalar = s.unicodeScalars.first {
            let v = scalar.value
            if v >= 0x61 && v <= 0x7A { return Int32(v - 0x20) }
            if v >= 0x41 && v <= 0x5A { return Int32(v) }
            if v >= 0x30 && v <= 0x39 { return Int32(v) }
        }
        return 0
    }
}

@MainActor
private final class VolvoxGridMacNativeTextView: NSTextView {
    weak var host: VolvoxGridNSView?

    override func keyDown(with event: NSEvent) {
        if host?.handleNativeTextViewKeyDown(event) == true { return }
        super.keyDown(with: event)
    }

    override func keyUp(with event: NSEvent) {
        if host?.handleNativeTextViewKeyUp(event) == true { return }
        super.keyUp(with: event)
    }

    override func setMarkedText(_ string: Any, selectedRange: NSRange, replacementRange: NSRange) {
        super.setMarkedText(string, selectedRange: selectedRange, replacementRange: replacementRange)
        let text = Self.plainText(from: string)
        let cursor = volvoxCodePointOffset(forUTF16Offset: selectedRange.location, in: text)
        host?.handleNativeMarkedTextChanged(text, cursor: cursor)
    }

    override func unmarkText() {
        super.unmarkText()
        host?.handleNativeMarkedTextCommitted()
    }

    override func insertText(_ insertString: Any, replacementRange: NSRange) {
        super.insertText(insertString, replacementRange: replacementRange)
        host?.handleNativeMarkedTextCommitted()
    }

    private static func plainText(from value: Any) -> String {
        if let attributed = value as? NSAttributedString {
            return attributed.string
        }
        return String(describing: value)
    }
}
#endif
