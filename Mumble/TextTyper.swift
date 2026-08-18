//
//  TextTyper.swift
//  Mumble
//

import ApplicationServices

protocol TextTyping: AnyObject {
    func type(_ text: String)
}

/// Posts synthetic keystrokes carrying a Unicode string, so typed text lands
/// in whatever app currently has focus - not a specific app, and not via the
/// clipboard.
final class TextTyper: TextTyping {
    func type(_ text: String) {
        guard AXIsProcessTrusted() else {
            print("TextTyper: accessibility not trusted, skipping typeText")
            return
        }
        guard !text.isEmpty else { return }

        guard let source = CGEventSource(stateID: .hidSystemState) else {
            print("TextTyper: failed to create CGEventSource")
            return
        }

        for character in text {
            var utf16Chars = Array(String(character).utf16)

            guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: true),
                  let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: false) else {
                continue
            }

            keyDown.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: &utf16Chars)
            keyUp.keyboardSetUnicodeString(stringLength: utf16Chars.count, unicodeString: &utf16Chars)

            keyDown.post(tap: .cghidEventTap)
            keyUp.post(tap: .cghidEventTap)
        }
    }
}
