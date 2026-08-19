//
//  TranscriptHistoryStoreTests.swift
//  MumbleTests
//

import XCTest
@testable import Mumble

final class TranscriptHistoryStoreTests: XCTestCase {
    private func makeTempFileURL() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent("mumble-history-test-\(UUID().uuidString).json")
    }

    func test_record_addsNewestEntryFirst() {
        let store = TranscriptHistoryStore(fileURL: makeTempFileURL())

        store.record("first")
        store.record("second")

        XCTAssertEqual(store.entries.map(\.text), ["second", "first"])
    }

    func test_record_ignoresEmptyText() {
        let store = TranscriptHistoryStore(fileURL: makeTempFileURL())

        store.record("")

        XCTAssertTrue(store.entries.isEmpty, "an empty utterance shouldn't clutter the persisted log")
    }

    func test_clear_removesAllEntries() {
        let store = TranscriptHistoryStore(fileURL: makeTempFileURL())
        store.record("something")

        store.clear()

        XCTAssertTrue(store.entries.isEmpty)
    }

    func test_entries_persistAcrossInstances() {
        let url = makeTempFileURL()
        defer { try? FileManager.default.removeItem(at: url) }

        let firstInstance = TranscriptHistoryStore(fileURL: url)
        firstInstance.record("persisted transcript")

        let secondInstance = TranscriptHistoryStore(fileURL: url)

        XCTAssertEqual(secondInstance.entries.map(\.text), ["persisted transcript"], "the whole point is surviving a relaunch, not just an in-memory session")
    }
}
