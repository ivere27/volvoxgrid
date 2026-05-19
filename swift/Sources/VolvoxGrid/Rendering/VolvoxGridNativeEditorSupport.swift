// VolvoxGridNativeEditorSupport.swift
//
// Small shared helpers for the AppKit/UIKit host-native editor overlays.

import Foundation

@MainActor
internal func volvoxEditorText(_ value: EditorValue?) -> String {
    guard let value = value else { return "" }
    if let text = value.editText { return text }
    if let text = value.displayText { return text }
    guard let cell = value.value else { return "" }
    switch cell.value {
    case .none:
        return ""
    case .text(let text):
        return text
    case .number(let number):
        return String(number)
    case .flag(let flag):
        return flag ? "true" : "false"
    case .raw:
        return ""
    case .timestamp(let timestamp):
        return String(timestamp)
    }
}

@MainActor
internal func volvoxIsTextEditableSession(_ session: EditorSession) -> Bool {
    guard let editor = session.editor else { return true }
    switch editor.kind {
    case .editorText, .editorMultilineText, .editorNumber, .editorCombo:
        return editor.owner == .hostNative && editor.presentation != .editorCanvas
    default:
        return false
    }
}

@MainActor
internal func volvoxCodePointLength(_ text: String?) -> Int32 {
    Int32((text ?? "").unicodeScalars.count)
}

@MainActor
internal func volvoxUTF16Offset(forCodePoint codePoint: Int32, in text: String) -> Int {
    let bounded = max(0, min(Int(codePoint), text.unicodeScalars.count))
    let scalarIndex = text.unicodeScalars.index(text.unicodeScalars.startIndex, offsetBy: bounded)
    return scalarIndex.samePosition(in: text.utf16)?.utf16Offset(in: text) ?? text.utf16.count
}

@MainActor
internal func volvoxCodePointOffset(forUTF16Offset offset: Int, in text: String) -> Int32 {
    var bounded = max(0, min(offset, text.utf16.count))
    while bounded > 0 {
        let utf16Index = text.utf16.index(text.utf16.startIndex, offsetBy: bounded)
        if let scalarIndex = utf16Index.samePosition(in: text.unicodeScalars) {
            return Int32(text.unicodeScalars.distance(from: text.unicodeScalars.startIndex, to: scalarIndex))
        }
        bounded -= 1
    }
    return 0
}
