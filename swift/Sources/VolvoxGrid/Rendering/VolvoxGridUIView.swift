// VolvoxGridUIView.swift
//
// UIKit host for the VolvoxGrid CPU rendering loop. Drop one into your
// view hierarchy, hand it a started `VolvoxGridClient` + grid id, and
// it'll keep `layer.contents` synced with the engine output.
//
// Input wiring:
//   - Single touches  → PointerEvent DOWN/MOVE/UP (selection / cell click).
//   - Two-finger pan  → ScrollEvent (grid scroll).
//   - Pinch           → ZoomEvent.
//   - Hardware keys   → KeyEvent via pressesBegan / pressesEnded.
//   - UITextView      → host-native inline editor with UIKit IME.

#if canImport(UIKit)
import UIKit
import CoreGraphics

@MainActor
public final class VolvoxGridUIView: UIView, UITextViewDelegate {

    // MARK: - Public surface

    /// The client whose engine session feeds this view. Set once via
    /// `bind(client:gridId:)`; reset on `unbind()`.
    public private(set) weak var client: VolvoxGridClient?

    /// The engine grid id this view is rendering. `0` means unbound.
    public private(set) var gridId: Int64 = 0

    /// `true` once the renderer has produced at least one non-clean frame.
    public private(set) var hasReceivedFrame: Bool = false

    // MARK: - Private state

    private var renderer: VolvoxGridRendererCPU?
    private var consumerTask: Task<Void, Never>?
    private var editorTask: Task<Void, Never>?
    private var lastSentSize: CGSize = .zero
    private var activeTouch: UITouch?
    private var nativeTextView: VolvoxGridIOSNativeTextView?
    private var nativeEditorDisplayed = false
    private var suppressNativeTextChange = false
    private var nativeImeComposing = false
    private var pendingHostEditorStart = false
    private var activeEditorSessionId: Int64 = 0
    private var activeEditorStateVersion: UInt64 = 0
    private var activeEditorRow: Int32 = -1
    private var activeEditorCol: Int32 = -1
    private var activeEditorUiMode: EditUiMode = .enter

    // MARK: - Init

    public override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    public required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        // We're going to set layer.contents ourselves; turn off the
        // implicit redraw that UIView normally does on bounds change.
        contentMode = .scaleToFill
        clearsContextBeforeDrawing = false
        isOpaque = true
        // contentsScale follows the screen's nativeScale so engine
        // pixels map 1:1 to physical pixels.
        layer.contentsScale = UIScreen.main.nativeScale
        // CALayer.contents is a CGImage; we set magnificationFilter so
        // any temporary mismatch during a resize doesn't blur.
        layer.magnificationFilter = .nearest
        layer.minificationFilter = .linear

        isMultipleTouchEnabled = true
        let pinch = UIPinchGestureRecognizer(target: self, action: #selector(handlePinch(_:)))
        addGestureRecognizer(pinch)
        let twoFingerPan = UIPanGestureRecognizer(target: self, action: #selector(handleTwoFingerPan(_:)))
        twoFingerPan.minimumNumberOfTouches = 2
        twoFingerPan.maximumNumberOfTouches = 2
        addGestureRecognizer(twoFingerPan)

        let textView = VolvoxGridIOSNativeTextView(frame: .zero)
        textView.host = self
        textView.delegate = self
        textView.isEditable = true
        textView.isSelectable = true
        textView.isScrollEnabled = false
        textView.autocorrectionType = .no
        textView.autocapitalizationType = .none
        textView.spellCheckingType = .no
        textView.backgroundColor = .clear
        textView.textColor = .clear
        textView.tintColor = .clear
        textView.textContainerInset = UIEdgeInsets(top: 1, left: 3, bottom: 1, right: 3)
        textView.textContainer.lineFragmentPadding = 0
        addSubview(textView)
        nativeTextView = textView
        enterNativeEditorProxyMode(requestFocus: false)
    }

    public override var canBecomeFirstResponder: Bool { true }

    deinit {
        consumerTask?.cancel()
        editorTask?.cancel()
    }

    // MARK: - Binding

    /// Start a rendering session for `gridId`. Reuses this view's
    /// current size to size the engine viewport. If the view hasn't
    /// laid out yet (size == .zero) the renderer waits and resizes on
    /// first `layoutSubviews`.
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
                // Surface to the caller via the next bind() or by
                // logging; for v1 we just stop here.
                return
            }
            for await frame in renderer.frames {
                guard !Task.isCancelled else { break }
                await self?.consume(frame)
            }
        }
    }

    /// Tear down the current rendering session. The view stays in the
    /// hierarchy with its last frame still visible until reset.
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

    // MARK: - Layout

    public override func layoutSubviews() {
        super.layoutSubviews()
        guard renderer != nil else { return }
        if bounds.size == lastSentSize { return }
        lastSentSize = bounds.size
        let (width, height) = currentPixelSize()
        guard width > 0, height > 0 else { return }
        if let renderer = renderer {
            Task { try? await renderer.resize(width: width, height: height) }
        }
    }

    public override func didMoveToWindow() {
        super.didMoveToWindow()
        if let window = window {
            // Match the screen we just attached to.
            layer.contentsScale = window.screen.nativeScale
            // Trigger a re-layout so the renderer learns about
            // dimensions that may have changed since the previous
            // window (split view, external display, …).
            setNeedsLayout()
        }
    }

    // MARK: - Frame consumption

    @MainActor
    private func consume(_ frame: CPUFrame) {
        guard frame.hasContent else { return }
        guard let cgImage = makeCGImage(from: frame) else { return }
        layer.contents = cgImage
        hasReceivedFrame = true
    }

    private func makeCGImage(from frame: CPUFrame) -> CGImage? {
        let pixels = frame.pixels
        guard !pixels.isEmpty else { return nil }
        let width = Int(frame.width)
        let height = Int(frame.height)
        let stride = Int(frame.stride)
        let cfData = pixels as CFData
        guard let provider = CGDataProvider(data: cfData) else { return nil }
        let bitmapInfo: CGBitmapInfo = [
            .byteOrder32Big,
            CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue),
        ]
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: stride,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }

    // MARK: - Helpers

    private func currentPixelSize() -> (Int32, Int32) {
        let scale = layer.contentsScale
        let w = Int32(max(0, bounds.size.width * scale))
        let h = Int32(max(0, bounds.size.height * scale))
        return (w, h)
    }

    // MARK: - Touch → PointerEvent

    public override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Reject multi-touch sequences: gesture recognizers handle those.
        if event?.allTouches?.count ?? 1 > 1 {
            activeTouch = nil
            return
        }
        guard let touch = touches.first else { return }
        activeTouch = touch
        focusNativeTextInput()
        sendPointer(.down, at: touch, dblClick: touch.tapCount >= 2)
    }

    public override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        sendPointer(.move, at: touch)
    }

    public override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        sendPointer(.up, at: touch)
        activeTouch = nil
    }

    public override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        guard let touch = activeTouch, touches.contains(touch) else { return }
        sendPointer(.up, at: touch)
        activeTouch = nil
    }

    private func sendPointer(_ type: PointerEvent_Type, at touch: UITouch, dblClick: Bool = false) {
        let p = touch.location(in: self)
        let scale = Float(layer.contentsScale)
        let x = Float(p.x) * scale
        let y = Float(p.y) * scale
        // Touch carries no modifier flags on iOS 13 baseline; hardware-
        // keyboard modifiers arrive via UIKey on the next pressesBegan.
        guard let renderer = renderer else { return }
        Task {
            try? await renderer.sendPointer(
                type: type, x: x, y: y,
                modifier: 0, button: 0x01, dblClick: dblClick
            )
        }
    }

    // MARK: - Pinch → ZoomEvent

    @objc private func handlePinch(_ gr: UIPinchGestureRecognizer) {
        guard let renderer = renderer else { return }
        let p = gr.location(in: self)
        let scale = Float(layer.contentsScale)
        let fx = Float(p.x) * scale
        let fy = Float(p.y) * scale
        let s = Float(gr.scale)

        let phase: ZoomEvent_Phase
        switch gr.state {
        case .began:    phase = .zoomBegin
        case .changed:  phase = .zoomUpdate
        case .ended, .cancelled, .failed: phase = .zoomEnd
        default: return
        }
        Task {
            try? await renderer.sendZoom(phase: phase, scale: s, focalX: fx, focalY: fy)
        }
    }

    // MARK: - Two-finger pan → ScrollEvent

    @objc private func handleTwoFingerPan(_ gr: UIPanGestureRecognizer) {
        guard let renderer = renderer else { return }
        guard gr.state == .began || gr.state == .changed else { return }
        let t = gr.translation(in: self)
        gr.setTranslation(.zero, in: self)
        let scale = Float(layer.contentsScale)
        let dx = Float(t.x) * scale
        let dy = Float(t.y) * scale
        if dx == 0 && dy == 0 { return }
        Task {
            try? await renderer.sendScroll(deltaX: dx, deltaY: dy)
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
        bringSubviewToFront(textView)
        textView.backgroundColor = .systemBackground
        textView.textColor = .label
        textView.tintColor = .label
        textView.alpha = 1
        textView.layer.borderWidth = 1
        textView.layer.borderColor = UIColor.label.cgColor

        if !preserveCurrentText {
            let text = volvoxEditorText(session.value)
            let selection = session.selection
            let start = volvoxUTF16Offset(forCodePoint: selection?.start ?? 0, in: text)
            let end = volvoxUTF16Offset(
                forCodePoint: (selection?.start ?? 0) + (selection?.length ?? volvoxCodePointLength(text)),
                in: text
            )
            suppressNativeTextChange = true
            textView.text = text
            textView.selectedRange = NSRange(location: start, length: max(0, end - start))
            suppressNativeTextChange = false
        }

        pendingHostEditorStart = false
        textView.becomeFirstResponder()
        syncNativeEditorSelectionToEngine()
        if preserveCurrentText {
            applyNativeEditorText(textView.text ?? "")
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
            suppressNativeTextChange = true
            textView.text = volvoxEditorText(value)
            suppressNativeTextChange = false
        }
        if let selection = update.selection {
            let text = textView.text ?? ""
            let start = volvoxUTF16Offset(forCodePoint: selection.start, in: text)
            let end = volvoxUTF16Offset(forCodePoint: selection.start + selection.length, in: text)
            textView.selectedRange = NSRange(location: start, length: max(0, end - start))
        }
    }

    private func applyNativeEditorFrame(_ rect: Rect) {
        guard let textView = nativeTextView else { return }
        let scale = layer.contentsScale
        textView.frame = CGRect(
            x: CGFloat(rect.x) / scale,
            y: CGFloat(rect.y) / scale,
            width: max(1, CGFloat(rect.width) / scale),
            height: max(1, CGFloat(rect.height) / scale)
        ).insetBy(dx: -1, dy: -1)
    }

    private func hideNativeEditor(focusProxy: Bool) {
        nativeEditorDisplayed = false
        nativeImeComposing = false
        pendingHostEditorStart = false
        activeEditorSessionId = 0
        activeEditorStateVersion = 0
        activeEditorRow = -1
        activeEditorCol = -1
        activeEditorUiMode = .enter
        enterNativeEditorProxyMode(requestFocus: focusProxy)
    }

    private func enterNativeEditorProxyMode(requestFocus: Bool) {
        guard let textView = nativeTextView else { return }
        suppressNativeTextChange = true
        textView.text = ""
        textView.selectedRange = NSRange(location: 0, length: 0)
        suppressNativeTextChange = false
        textView.frame = CGRect(x: 0, y: 0, width: 1, height: 1)
        textView.backgroundColor = .clear
        textView.textColor = .clear
        textView.tintColor = .clear
        textView.alpha = 0.01
        textView.layer.borderWidth = 0
        textView.layer.borderColor = nil
        if requestFocus {
            focusNativeTextInput()
        }
    }

    private func focusNativeTextInput() {
        nativeTextView?.becomeFirstResponder()
    }

    public func textViewDidChange(_ textView: UITextView) {
        guard !suppressNativeTextChange else { return }
        if !nativeEditorDisplayed {
            guard !(textView.text ?? "").isEmpty else { return }
            beginHostEditorFromProxy()
            return
        }
        if let marked = markedText(in: textView) {
            sendNativePreedit(marked.text, cursor: marked.cursor, commit: false)
            return
        }
        if nativeImeComposing {
            nativeImeComposing = false
            sendNativePreedit("", cursor: 0, commit: true)
        }
        applyNativeEditorText(textView.text ?? "")
        syncNativeEditorSelectionToEngine()
    }

    public func textViewDidChangeSelection(_ textView: UITextView) {
        if let marked = markedText(in: textView), nativeEditorDisplayed {
            sendNativePreedit(marked.text, cursor: marked.cursor, commit: false)
            return
        }
        syncNativeEditorSelectionToEngine()
    }

    public func textView(
        _ textView: UITextView,
        shouldChangeTextIn range: NSRange,
        replacementText text: String
    ) -> Bool {
        guard nativeEditorDisplayed else { return true }
        if text == "\n" {
            commitNativeEditor(navigateKeyCode: 40, navigateModifier: 0)
            return false
        }
        if text == "\t" {
            commitNativeEditor(navigateKeyCode: 9, navigateModifier: 0)
            return false
        }
        return true
    }

    private func markedText(in textView: UITextView) -> (text: String, cursor: Int32)? {
        guard let markedRange = textView.markedTextRange,
              let text = textView.text(in: markedRange),
              !text.isEmpty else { return nil }
        let cursorPosition = textView.selectedTextRange?.start ?? markedRange.end
        let cursor = textView.offset(from: markedRange.start, to: cursorPosition)
        nativeImeComposing = true
        return (text, volvoxCodePointOffset(forUTF16Offset: max(0, cursor), in: text))
    }

    private func sendNativePreedit(_ text: String, cursor: Int32, commit: Bool) {
        guard nativeEditorDisplayed,
              let client = client,
              gridId != 0 else { return }
        let id = gridId
        let sessionId = activeEditorSessionId
        Task {
            try? await client.editSetPreedit(id, text: text, cursor: cursor, commit: commit, sessionId: sessionId)
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
        let seedText = textView.text ?? ""
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
        let text = textView.text ?? ""
        let range = textView.selectedRange
        let start = volvoxCodePointOffset(forUTF16Offset: range.location, in: text)
        let end = volvoxCodePointOffset(forUTF16Offset: range.location + range.length, in: text)
        let id = gridId
        let sessionId = activeEditorSessionId
        Task {
            try? await client.editSetSelection(id, start: start, length: max(0, end - start), sessionId: sessionId)
        }
    }

    @available(iOS 13.4, tvOS 13.4, *)
    fileprivate func handleNativeTextPress(_ press: UIPress, type: KeyEvent_Type) -> Bool {
        guard let key = press.key else { return false }
        let code = engineKeyCode(from: key)
        let modifier = engineModifier(key.modifierFlags)
        if nativeEditorDisplayed {
            guard type == .keyDown else { return code == 27 || code == 9 || code == 13 }
            switch code {
            case 27:
                cancelNativeEditor()
                return true
            case 9:
                commitNativeEditor(navigateKeyCode: 9, navigateModifier: modifier)
                return true
            case 13:
                commitNativeEditor(navigateKeyCode: key.modifierFlags.contains(.shift) ? 38 : 40, navigateModifier: 0)
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

        if type == .keyDown && (isTextInputKey(key) || pendingHostEditorStart) {
            return false
        }
        guard code != 0 else { return false }
        let renderer = renderer
        Task {
            try? await renderer?.sendKey(type: type, keyCode: code, modifier: modifier, character: "")
        }
        return true
    }

    @available(iOS 13.4, tvOS 13.4, *)
    private func isTextInputKey(_ key: UIKey) -> Bool {
        if key.modifierFlags.contains(.command) || key.modifierFlags.contains(.control) {
            return false
        }
        let characters = key.characters
        guard !characters.isEmpty else { return false }
        return characters.unicodeScalars.contains { scalar in
            scalar.value >= 0x20 && !(scalar.value >= 0xF700 && scalar.value <= 0xF8FF)
        }
    }

    private func commitNativeEditor(navigateKeyCode: Int32?, navigateModifier: Int32) {
        guard nativeEditorDisplayed,
              let client = client,
              gridId != 0,
              let textView = nativeTextView else { return }
        let id = gridId
        let sessionId = activeEditorSessionId
        let text = textView.text ?? ""
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

    // MARK: - Hardware keyboard → KeyEvent

    public override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            if forwardKey(press, type: .keyDown) { handled = true }
        }
        if !handled { super.pressesBegan(presses, with: event) }
    }

    public override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        var handled = false
        for press in presses {
            if forwardKey(press, type: .keyUp) { handled = true }
        }
        if !handled { super.pressesEnded(presses, with: event) }
    }

    public override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        for press in presses { _ = forwardKey(press, type: .keyUp) }
        super.pressesCancelled(presses, with: event)
    }

    @discardableResult
    private func forwardKey(_ press: UIPress, type: KeyEvent_Type) -> Bool {
        guard let renderer = renderer else { return false }
        // UIPress.key is iOS 13.4+; nothing useful below that.
        guard #available(iOS 13.4, tvOS 13.4, *), let key = press.key else {
            return false
        }
        let code = engineKeyCode(from: key)
        let modifier = engineModifier(key.modifierFlags)
        let character = (type == .keyDown) ? key.characters : ""
        Task {
            try? await renderer.sendKey(
                type: type, keyCode: code, modifier: modifier, character: character
            )
            if type == .keyDown && !character.isEmpty && isPrintable(character) {
                try? await renderer.sendKey(
                    type: .keyPress, keyCode: 0, modifier: modifier, character: character
                )
            }
        }
        return true
    }

    /// True only for ASCII printable input — `UIKey.characters` for
    /// arrows / function keys uses private-use scalars (0xF700+) that
    /// would otherwise look "printable" by raw value.
    private func isPrintable(_ s: String) -> Bool {
        guard let scalar = s.unicodeScalars.first else { return false }
        return scalar.value >= 0x20 && scalar.value < 0x7F
    }

    private func engineModifier(_ flags: UIKeyModifierFlags) -> Int32 {
        var m: Int32 = 0
        if flags.contains(.shift)     { m |= 0x01 }
        if flags.contains(.control)   { m |= 0x02 }
        if flags.contains(.alternate) { m |= 0x04 }
        if flags.contains(.command)   { m |= 0x08 }
        return m
    }

    /// UIKeyboardHIDUsage (USB HID) → JS-style key code expected by the
    /// engine (see proto/volvoxgrid.proto:2799). Letters / digits fall
    /// through; only the named special keys need a translation.
    @available(iOS 13.4, tvOS 13.4, *)
    private func engineKeyCode(from key: UIKey) -> Int32 {
        switch key.keyCode {
        case .keyboardReturnOrEnter:      return 13
        case .keyboardEscape:             return 27
        case .keyboardDeleteOrBackspace:  return 8
        case .keyboardTab:                return 9
        case .keyboardDeleteForward:      return 46
        case .keyboardLeftArrow:          return 37
        case .keyboardRightArrow:         return 39
        case .keyboardUpArrow:            return 38
        case .keyboardDownArrow:          return 40
        case .keyboardPageUp:             return 33
        case .keyboardPageDown:           return 34
        case .keyboardHome:               return 36
        case .keyboardEnd:                return 35
        case .keyboardF2:                 return 113
        default: break
        }
        // Letters: charactersIgnoringModifiers gives 'a'..'z' regardless of shift.
        let s = key.charactersIgnoringModifiers
        if let scalar = s.unicodeScalars.first {
            let v = scalar.value
            if v >= 0x61 && v <= 0x7A { return Int32(v - 0x20) }  // 'a'..'z' → 65..90
            if v >= 0x41 && v <= 0x5A { return Int32(v) }          // 'A'..'Z'
            if v >= 0x30 && v <= 0x39 { return Int32(v) }          // '0'..'9'
        }
        return 0
    }
}

@MainActor
private final class VolvoxGridIOSNativeTextView: UITextView {
    weak var host: VolvoxGridUIView?

    override func pressesBegan(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard #available(iOS 13.4, tvOS 13.4, *) else {
            super.pressesBegan(presses, with: event)
            return
        }
        let passthrough = Set(presses.filter { host?.handleNativeTextPress($0, type: .keyDown) != true })
        if !passthrough.isEmpty {
            super.pressesBegan(passthrough, with: event)
        }
    }

    override func pressesEnded(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard #available(iOS 13.4, tvOS 13.4, *) else {
            super.pressesEnded(presses, with: event)
            return
        }
        let passthrough = Set(presses.filter { host?.handleNativeTextPress($0, type: .keyUp) != true })
        if !passthrough.isEmpty {
            super.pressesEnded(passthrough, with: event)
        }
    }

    override func pressesCancelled(_ presses: Set<UIPress>, with event: UIPressesEvent?) {
        guard #available(iOS 13.4, tvOS 13.4, *) else {
            super.pressesCancelled(presses, with: event)
            return
        }
        let passthrough = Set(presses.filter { host?.handleNativeTextPress($0, type: .keyUp) != true })
        if !passthrough.isEmpty {
            super.pressesCancelled(passthrough, with: event)
        }
    }
}
#endif
