//
//  DictationController.swift
//  Mumble
//

import Combine
import Foundation

final class DictationController: ObservableObject {
    @Published private(set) var isListening = false
    private(set) var lastTranscript = ""

    private let audioCapture: AudioCapturing
    private let speechTranscriber: SpeechTranscribing
    private let textTyper: TextTyping
    private let permissionsChecker: PermissionsChecking

    init(
        audioCapture: AudioCapturing = AudioCapture(),
        speechTranscriber: SpeechTranscribing = SpeechTranscriber(),
        textTyper: TextTyping = TextTyper(),
        permissionsChecker: PermissionsChecking = PermissionsChecker()
    ) {
        self.audioCapture = audioCapture
        self.speechTranscriber = speechTranscriber
        self.textTyper = textTyper
        self.permissionsChecker = permissionsChecker
    }

    func handleFnDown() {
        guard !isListening else { return }
        guard permissionsChecker.canRecord else {
            print("DictationController: missing microphone or speech-recognition permission, skipping")
            return
        }

        speechTranscriber.start(
            onUpdate: { transcript in
                print("Transcript (partial): \(transcript)")
            },
            onFinal: { [weak self] transcript in
                self?.lastTranscript = transcript
                print("Transcript (final): \(transcript)")
                self?.textTyper.type(transcript)
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
