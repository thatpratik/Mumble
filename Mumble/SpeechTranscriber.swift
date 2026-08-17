//
//  SpeechTranscriber.swift
//  Mumble
//

import Speech

protocol SpeechTranscribing: AnyObject {
    func start(onUpdate: @escaping (String) -> Void, onFinal: @escaping (String) -> Void)
    func append(_ buffer: AVAudioPCMBuffer)
    func stop()
}

final class SpeechTranscriber: SpeechTranscribing {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var latestTranscript = ""
    private var onFinal: ((String) -> Void)?
    private var didFinish = false

    func start(onUpdate: @escaping (String) -> Void, onFinal: @escaping (String) -> Void) {
        guard let recognizer = recognizer, recognizer.isAvailable else {
            print("SpeechTranscriber: recognizer unavailable")
            onFinal("")
            return
        }

        let newRequest = SFSpeechAudioBufferRecognitionRequest()
        newRequest.shouldReportPartialResults = true
        if recognizer.supportsOnDeviceRecognition {
            newRequest.requiresOnDeviceRecognition = true
        }

        request = newRequest
        latestTranscript = ""
        didFinish = false
        self.onFinal = onFinal

        task = recognizer.recognitionTask(with: newRequest) { [weak self] result, error in
            guard let self else { return }

            if let result {
                self.latestTranscript = result.bestTranscription.formattedString
                onUpdate(self.latestTranscript)
                if result.isFinal {
                    self.finishOnce()
                }
            }

            if let error {
                // Covers both real failures and the normal "no speech detected"
                // case on a very short Fn tap - either way, don't crash.
                print("SpeechTranscriber: recognition ended: \(error.localizedDescription)")
                self.finishOnce()
            }
        }
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        request?.append(buffer)
    }

    func stop() {
        request?.endAudio()
    }

    private func finishOnce() {
        guard !didFinish else { return }
        didFinish = true
        let callback = onFinal
        onFinal = nil
        request = nil
        task = nil
        callback?(latestTranscript)
    }
}
