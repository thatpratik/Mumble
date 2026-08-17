//
//  DictationControllerTests.swift
//  MumbleTests
//
//  Not yet wired into a test target (no Xcode available in the environment
//  that added this file — see IMPLEMENTATION_PLAN.md). To run: Xcode ->
//  File -> New -> Target -> Unit Testing Bundle, name it MumbleTests, set
//  its Test Host to Mumble, and add this folder to the new target.
//
//  These exact cases were compiled and executed as a standalone swiftc
//  harness against the real DictationController/AudioCapture/
//  SpeechTranscriber sources before each commit that touches this file;
//  XCTest is just the permanent, idiomatic home for them once a test
//  target exists.
//

import XCTest
import AVFoundation
@testable import Mumble

final class FakeAudioCapture: AudioCapturing {
    var onBuffer: ((AVAudioPCMBuffer) -> Void)?
    var startCallCount = 0
    var stopCallCount = 0
    var startResult = true

    func start() -> Bool {
        startCallCount += 1
        return startResult
    }

    func stop() {
        stopCallCount += 1
    }
}

final class FakeSpeechTranscriber: SpeechTranscribing {
    var startCallCount = 0
    var appendCallCount = 0
    var stopCallCount = 0
    var capturedOnFinal: ((String) -> Void)?

    func start(onUpdate: @escaping (String) -> Void, onFinal: @escaping (String) -> Void) {
        startCallCount += 1
        capturedOnFinal = onFinal
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        appendCallCount += 1
    }

    func stop() {
        stopCallCount += 1
    }
}

final class DictationControllerTests: XCTestCase {
    func test_fnDown_startsListening_whenAudioCaptureSucceeds() {
        let fakeAudio = FakeAudioCapture()
        let fakeSpeech = FakeSpeechTranscriber()
        let controller = DictationController(audioCapture: fakeAudio, speechTranscriber: fakeSpeech)

        controller.handleFnDown()

        XCTAssertTrue(controller.isListening)
        XCTAssertEqual(fakeAudio.startCallCount, 1)
    }

    func test_fnDown_doesNotStartListening_whenAudioCaptureFails() {
        let fakeAudio = FakeAudioCapture()
        fakeAudio.startResult = false
        let controller = DictationController(audioCapture: fakeAudio, speechTranscriber: FakeSpeechTranscriber())

        controller.handleFnDown()

        XCTAssertFalse(controller.isListening, "isListening must stay false if the engine never actually started")
    }

    func test_fnDown_startsTheSpeechTranscriber() {
        let fakeSpeech = FakeSpeechTranscriber()
        let controller = DictationController(audioCapture: FakeAudioCapture(), speechTranscriber: fakeSpeech)

        controller.handleFnDown()

        XCTAssertEqual(fakeSpeech.startCallCount, 1)
    }

    func test_fnDown_whenAudioCaptureFails_cleansUpTheDanglingSpeechRequest() {
        let fakeAudio = FakeAudioCapture()
        fakeAudio.startResult = false
        let fakeSpeech = FakeSpeechTranscriber()
        let controller = DictationController(audioCapture: fakeAudio, speechTranscriber: fakeSpeech)

        controller.handleFnDown()

        XCTAssertEqual(fakeSpeech.startCallCount, 1, "the speech request starts before the audio-capture failure is known")
        XCTAssertEqual(fakeSpeech.stopCallCount, 1, "the now-abandoned request must be stopped rather than left dangling")
    }

    func test_buffersFromAudioCapture_areForwardedToTheTranscriber() {
        let fakeAudio = FakeAudioCapture()
        let fakeSpeech = FakeSpeechTranscriber()
        let controller = DictationController(audioCapture: fakeAudio, speechTranscriber: fakeSpeech)
        controller.handleFnDown()

        let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1)!
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 10)!
        fakeAudio.onBuffer?(buffer)
        fakeAudio.onBuffer?(buffer)

        XCTAssertEqual(fakeSpeech.appendCallCount, 2)
    }

    func test_onFinalCallback_updatesLastTranscript_evenAfterFnUpReturns() {
        let fakeSpeech = FakeSpeechTranscriber()
        let controller = DictationController(audioCapture: FakeAudioCapture(), speechTranscriber: fakeSpeech)
        controller.handleFnDown()
        controller.handleFnUp()

        fakeSpeech.capturedOnFinal?("hello, world.")

        XCTAssertEqual(controller.lastTranscript, "hello, world.", "the final transcript arrives asynchronously and must still be captured")
    }

    func test_fnUp_stopsAudioCaptureAndSpeechTranscriber_andClearsOnBuffer() {
        let fakeAudio = FakeAudioCapture()
        let fakeSpeech = FakeSpeechTranscriber()
        let controller = DictationController(audioCapture: fakeAudio, speechTranscriber: fakeSpeech)
        controller.handleFnDown()

        controller.handleFnUp()

        XCTAssertEqual(fakeAudio.stopCallCount, 1)
        XCTAssertEqual(fakeSpeech.stopCallCount, 1)
        XCTAssertNil(fakeAudio.onBuffer, "stray buffers must not leak into an already-finished request")
    }

    func test_fnUp_withoutPriorFnDown_isNoOp() {
        let fakeSpeech = FakeSpeechTranscriber()
        let controller = DictationController(audioCapture: FakeAudioCapture(), speechTranscriber: fakeSpeech)

        controller.handleFnUp()

        XCTAssertEqual(fakeSpeech.stopCallCount, 0)
        XCTAssertFalse(controller.isListening)
    }

    func test_rapidRepeatedFnDown_onlyStartsOnce() {
        let fakeAudio = FakeAudioCapture()
        let fakeSpeech = FakeSpeechTranscriber()
        let controller = DictationController(audioCapture: fakeAudio, speechTranscriber: fakeSpeech)

        controller.handleFnDown()
        controller.handleFnDown()
        controller.handleFnDown()

        XCTAssertEqual(fakeAudio.startCallCount, 1)
        XCTAssertEqual(fakeSpeech.startCallCount, 1)
    }

    func test_rapidRepeatedFnUp_onlyStopsOnce() {
        let fakeSpeech = FakeSpeechTranscriber()
        let controller = DictationController(audioCapture: FakeAudioCapture(), speechTranscriber: fakeSpeech)
        controller.handleFnDown()

        controller.handleFnUp()
        controller.handleFnUp()
        controller.handleFnUp()

        XCTAssertEqual(fakeSpeech.stopCallCount, 1)
    }
}
