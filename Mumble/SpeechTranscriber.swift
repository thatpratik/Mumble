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

/// Tags each recognition cycle so a callback from an abandoned previous
/// cycle can never be mistaken for the current one. Reused across rapid
/// Fn up/down taps, where a new cycle can start before the old cycle's
/// task has delivered its (now-irrelevant) final callback.
struct RecognitionCycleTracker {
    private(set) var generation = 0

    mutating func begin() -> Int {
        generation += 1
        return generation
    }

    func isCurrent(_ token: Int) -> Bool {
        token == generation
    }
}

final class SpeechTranscriber: SpeechTranscribing {
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var request: SFSpeechAudioBufferRecognitionRequest?
    private var task: SFSpeechRecognitionTask?
    private var latestTranscript = ""
    private var onFinal: ((String) -> Void)?
    private var didFinish = false
    private var cycleTracker = RecognitionCycleTracker()

    func start(onUpdate: @escaping (String) -> Void, onFinal: @escaping (String) -> Void) {
        // Abandon any still-running previous cycle before starting a new one.
        task?.cancel()
        let currentCycle = cycleTracker.begin()

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
            guard let self, self.cycleTracker.isCurrent(currentCycle) else {
                // Stale callback from an abandoned cycle - ignore it rather
                // than let it corrupt (or short-circuit) the current cycle.
                return
            }

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
