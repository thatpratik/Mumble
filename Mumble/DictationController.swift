//
//  DictationController.swift
//  Mumble
//

import Foundation

final class DictationController {
    private(set) var isListening = false
    private(set) var lastTranscript = ""

    private let audioCapture: AudioCapturing
    private let speechTranscriber: SpeechTranscribing

    init(
        audioCapture: AudioCapturing = AudioCapture(),
        speechTranscriber: SpeechTranscribing = SpeechTranscriber()
    ) {
        self.audioCapture = audioCapture
        self.speechTranscriber = speechTranscriber
    }

    func handleFnDown() {
        guard !isListening else { return }

        speechTranscriber.start(
            onUpdate: { transcript in
                print("Transcript (partial): \(transcript)")
            },
            onFinal: { [weak self] transcript in
                self?.lastTranscript = transcript
                print("Transcript (final): \(transcript)")
            }
        )

        audioCapture.onBuffer = { [weak self] buffer in
            self?.speechTranscriber.append(buffer)
        }

        guard audioCapture.start() else {
            print("DictationController: failed to start audio capture, aborting")
            audioCapture.onBuffer = nil
            speechTranscriber.stop()
            return
        }

        isListening = true
        print("DictationController: listening started")
    }

    func handleFnUp() {
        guard isListening else { return }
        isListening = false
        audioCapture.stop()
        audioCapture.onBuffer = nil
        speechTranscriber.stop()
        print("DictationController: listening stopped")
    }
}
