//
//  DictationController.swift
//  Mumble
//

import Foundation

final class DictationController {
    private(set) var isListening = false

    func handleFnDown() {
        guard !isListening else { return }
        isListening = true
        print("DictationController: listening started")
    }

    func handleFnUp() {
        guard isListening else { return }
        isListening = false
        print("DictationController: listening stopped")
    }
}
