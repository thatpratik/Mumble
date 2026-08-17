//
//  AudioCapture.swift
//  Mumble
//

import AVFoundation

protocol AudioCapturing: AnyObject {
    var onBuffer: ((AVAudioPCMBuffer) -> Void)? { get set }
    @discardableResult
    func start() -> Bool
    func stop()
}

final class AudioCapture: AudioCapturing {
    var onBuffer: ((AVAudioPCMBuffer) -> Void)?

    private let audioEngine = AVAudioEngine()
    private(set) var isRunning = false

    @discardableResult
    func start() -> Bool {
        guard !isRunning else { return true }

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.onBuffer?(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRunning = true
            return true
        } catch {
            inputNode.removeTap(onBus: 0)
            print("AudioCapture: failed to start engine: \(error)")
            return false
        }
    }

    func stop() {
        guard isRunning else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRunning = false
        print("AudioCapture: engine stopped")
    }
}
