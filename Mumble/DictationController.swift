//
//  DictationController.swift
//  Mumble
//

import Foundation

final class DictationController {
    private(set) var isListening = false
    private let audioCapture: AudioCapturing

    init(audioCapture: AudioCapturing = AudioCapture()) {
        self.audioCapture = audioCapture
    }

    func handleFnDown() {
        guard !isListening else { return }
        guard audioCapture.start() else {
            print("DictationController: failed to start audio capture, aborting")
            return
        }
        isListening = true
        print("DictationController: listening started")
    }

    func handleFnUp() {
        guard isListening else { return }
        isListening = false
        audioCapture.stop()
        print("DictationController: listening stopped")
    }
}
