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
//  harness against the real DictationController/AudioCapture sources
//  before this commit; XCTest is just the permanent, idiomatic home for
//  them once a test target exists.
//

import XCTest
@testable import Mumble

final class FakeAudioCapture: AudioCapturing {
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

final class DictationControllerTests: XCTestCase {
    func test_fnDown_startsListening_whenAudioCaptureSucceeds() {
        let fake = FakeAudioCapture()
        let controller = DictationController(audioCapture: fake)

        controller.handleFnDown()

        XCTAssertTrue(controller.isListening)
        XCTAssertEqual(fake.startCallCount, 1)
    }

    func test_fnDown_doesNotStartListening_whenAudioCaptureFails() {
        let fake = FakeAudioCapture()
        fake.startResult = false
        let controller = DictationController(audioCapture: fake)

        controller.handleFnDown()

        XCTAssertFalse(controller.isListening, "isListening must stay false if the engine never actually started")
    }

    func test_fnUp_stopsListening() {
        let fake = FakeAudioCapture()
        let controller = DictationController(audioCapture: fake)
        controller.handleFnDown()

        controller.handleFnUp()

        XCTAssertFalse(controller.isListening)
        XCTAssertEqual(fake.stopCallCount, 1)
    }

    func test_rapidRepeatedFnDown_onlyStartsOnce() {
        let fake = FakeAudioCapture()
        let controller = DictationController(audioCapture: fake)

        controller.handleFnDown()
        controller.handleFnDown()
        controller.handleFnDown()

        XCTAssertEqual(fake.startCallCount, 1)
    }

    func test_fnUp_withoutPriorFnDown_isNoOp() {
        let fake = FakeAudioCapture()
        let controller = DictationController(audioCapture: fake)

        controller.handleFnUp()

        XCTAssertEqual(fake.stopCallCount, 0)
        XCTAssertFalse(controller.isListening)
    }

    func test_fnUp_afterFailedFnDown_doesNotCallStop() {
        let fake = FakeAudioCapture()
        fake.startResult = false
        let controller = DictationController(audioCapture: fake)
        controller.handleFnDown()

        controller.handleFnUp()

        XCTAssertEqual(fake.stopCallCount, 0, "stop() should never be called for an engine that never started")
    }

    func test_rapidRepeatedFnUp_onlyStopsOnce() {
        let fake = FakeAudioCapture()
        let controller = DictationController(audioCapture: fake)
        controller.handleFnDown()

        controller.handleFnUp()
        controller.handleFnUp()
        controller.handleFnUp()

        XCTAssertEqual(fake.stopCallCount, 1)
    }
}
